require "spec_helper"
require "#{Dir.pwd}/lib/oddb2xml/downloader"
ENV["TZ"] = "UTC" # needed for last_change
LAST_CHANGE = "2015-07-03 00:00:00 +0000"
LAST_CHANGE_2 = "2015-11-24 00:00:00 +0000"

def common_before
  @saved_dir = Dir.pwd
  FileUtils.makedirs(Oddb2xml::WORK_DIR)
  Dir.chdir(Oddb2xml::WORK_DIR)
  VCR.eject_cassette
  VCR.insert_cassette("oddb2xml")
end

def common_after
  VCR.eject_cassette
  Dir.chdir(@saved_dir) if @saved_dir && File.directory?(@saved_dir)
end

describe Oddb2xml::LppvExtractor do
  before(:all) {
    common_before
    @downloader = Oddb2xml::LppvDownloader.new
    @content = @downloader.download
    @lppvs = Oddb2xml::LppvExtractor.new(@content).to_hash
  }
  after(:all) { common_after }
  it "should have at least one item" do
    expect(@lppvs.size).not_to eq 0
  end
end

unless SKIP_MIGEL_DOWNLOADER
  describe Oddb2xml::MigelExtractor do
    before(:all) {
      common_before
      @downloader = Oddb2xml::MigelDownloader.new
      xml = @downloader.download
      @items = Oddb2xml::MigelExtractor.new(xml).to_hash
    }
    after(:all) { common_after }
    it "should have at some items" do
      expect(@items.size).not_to eq 0
      expect(@items.find { |k, v| v[:pharmacode] == 3248410 }).not_to be_nil
      expect(@items.find { |k, v| /Novopen/i.match(v[:desc_de]) }).not_to be_nil
      expect(@items.find { |k, v| v[:pharmacode] == 3036984 }).not_to be_nil
      # Epimineral without pharmacode nor GTIN should not appear
      expect(@items.find { |k, v| /Epimineral/i.match(v[:desc_de]) }).to be_nil
    end
  end
end

describe Oddb2xml::RefdataExtractor do
  before(:all) { common_before }
  after(:all) { common_after }

  context "should handle pharma articles" do
    subject do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :pharma)
      xml = @downloader.download
      @pharma_items = Oddb2xml::RefdataExtractor.new(xml, "PHARMA").to_hash
    end

    it "should have correct info for no8 62069008 correctly" do
      @pharma_items = subject.to_hash
      item_found = @pharma_items.values.find { |x| x[:ean13].eql?(Oddb2xml::LEVETIRACETAM_GTIN) }
      expect(item_found).not_to be nil
      expected = {data_origin: "refdata",
                  refdata: true,
                  _type: :pharma,
                  ean13: Oddb2xml::LEVETIRACETAM_GTIN.to_s,
                  no8: "62069008",
                  desc_de: "LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk",
                  desc_fr: "LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce",
                  atc_code: "N03AX14",
                  last_change: "2017-12-08 00:00:00 +0000",
                  company_name: "Desitin Pharma GmbH",
                  company_ean: "7601001320451"}
      expect(item_found).to eq(expected)
    end
  end
  context "should handle nonpharma articles" do
    subject do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :nonpharma)
      xml = @downloader.download
      @non_pharma_items = Oddb2xml::RefdataExtractor.new(xml, :non_pharma).to_hash
    end

    it "should have correct info for nonpharma with pharmacode 0058502 correctly" do
      @non_pharma_items = subject.to_hash
      item_found = @non_pharma_items.values.find { |x| x[:ean13].eql?("7611600441020") }
      expect(item_found).not_to be nil
      expected = {refdata: true,
                  _type: :nonpharma,
                  ean13: "7611600441020",
                  no8: nil,
                  last_change: LAST_CHANGE_2,
                  data_origin: "refdata",
                  desc_de: "TUBEGAZE Verband weiss Nr 12 20m Finger gross",
                  desc_fr: "TUBEGAZE pans tubul blanc Nr 12 20m doigts grands",
                  atc_code: "",
                  company_name: "IVF HARTMANN AG",
                  company_ean: "7601001000896"}
      expect(item_found).to eq(expected)
    end
  end
end

describe Oddb2xml::BagXmlExtractor do
  before(:all) { common_before }
  after(:all) { common_after }
  context "should handle articles with and without pharmacode" do
    subject do
      dat = File.read(File.join(Oddb2xml::SpecData, "Preparations.xml"))
      Oddb2xml::BagXmlExtractor.new(dat).to_hash
    end
    it "should handle pub_price for 3TC correctly" do
      @items = subject.to_hash
      with_pharma = @items[Oddb2xml::THREE_TC_GTIN]
      expect(with_pharma).not_to be_nil
      expect(with_pharma[:name_de]).to eq "3TC"
      expect(with_pharma[:atc_code]).not_to be_nil
      expect(with_pharma[:packages].size).to eq(1)
      expect(with_pharma[:packages].first[0]).to eq(Oddb2xml::THREE_TC_GTIN)
      expect(with_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq("205.3")
    end
    it "should handle pub_price for #{Oddb2xml::LEVETIRACETAM_GTIN} correctly" do
      @items = subject.to_hash
      no_pharma = @items[Oddb2xml::LEVETIRACETAM_GTIN]
      expect(no_pharma).not_to be_nil
      expect(no_pharma[:atc_code]).not_to be_nil
      expect(no_pharma[:pharmacodes]).not_to be_nil
      expect(no_pharma[:packages].size).to eq(1)
      expect(no_pharma[:packages].first[0]).to eq(Oddb2xml::LEVETIRACETAM_GTIN)
      expect(no_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq("27.8")
    end
  end
end

describe Oddb2xml::SwissmedicInfoExtractor do
  before(:all) { common_before }
  after(:all) { common_after }
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::SwissmedicInfoDownloader.new
  end
  context "builds fachfinfo" do
    it {
      xml = @downloader.download
      @infos = Oddb2xml::SwissmedicInfoExtractor.new(xml).to_hash
      expect(@infos.keys).to eq ["de"]
      expect(@infos["de"].size).to eq 2
      levetiracetam = nil
      @infos["de"].each { |info|
        levetiracetam = info if /Levetiracetam/.match?(info[:name])
      }
      expect(levetiracetam[:owner]).to eq("Desitin Pharma GmbH")
      expect(levetiracetam[:paragraph].to_s).to match(/Packungen/)
      expect(levetiracetam[:paragraph].to_s).to match(/Zulassungsinhaberin/)
    }
  end
end

describe Oddb2xml::SwissmedicExtractor do
  before(:all) do
    common_before
    cleanup_directories_before_run
  end
  after(:all) { common_after }
  context "when transfer.dat is empty" do
    subject { Oddb2xml::SwissmedicInfoExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context "can parse swissmedic_package.xlsx" do
    before(:all) do
      @filename = File.join(Oddb2xml::SpecData, "swissmedic_package.xlsx")
      @packs = Oddb2xml::SwissmedicExtractor.new(@filename, :package).to_hash
    end

    def get_pack_by_ean13(ean13)
      @packs.find { |pack| pack[1][:ean13] == ean13.to_s }[1]
    end
    it "should have correct nr of packages" do
      expect(@packs.size).to eq(42)
    end

    it "should have serocytol" do
      serocytol = get_pack_by_ean13(7680620690084)
      expect(serocytol[:atc_code]).to eq("N03AX14")
      expect(serocytol[:swissmedic_category]).to eq("B")
      expect(serocytol[:package_size]).to eq("30")
      expect(serocytol[:einheit_swissmedic]).to eq("Tablette(n)")
      expect(serocytol[:substance_swissmedic]).to eq("levetiracetamum")
    end

    it "should have a correct insulin (gentechnik)" do
      humalog = get_pack_by_ean13(7680532900196)
      expect(humalog[:atc_code]).to eq("A10AB04")
      expect(humalog[:swissmedic_category]).to eq("B")
      expect(humalog[:package_size]).to eq("1 x 10 ml")
      expect(humalog[:einheit_swissmedic]).to eq("Flasche(n)")
      expect(humalog[:substance_swissmedic]).to eq("insulinum lisprum")
      expect(humalog[:gen_production]).to eq("X")
      expect(humalog[:insulin_category]).to eq("Insulinanalog: schnell wirkend")
      expect(humalog[:drug_index]).to eq("")
    end

    it "should have a correct drug information" do
      humalog = get_pack_by_ean13(7680555610041)
      expect(humalog[:atc_code]).to eq("N07BC06")
      expect(humalog[:swissmedic_category]).to eq("A")
      expect(humalog[:sequence_name]).to eq("Diaphin 10 g i.v., Injektionspräparat")
      expect(humalog[:gen_production]).to eq("")
      expect(humalog[:insulin_category]).to eq("")
      expect(humalog[:drug_index]).to eq("d")
    end
  end

  context "can parse swissmedic_orphans.xls" do
    it do
      @filename = File.join(Oddb2xml::SpecData, "swissmedic_orphan.xlsx")
      expect(File.exist?(@filename)).to eq(true), "File #{@filename} must exists"
      @packs = Oddb2xml::SwissmedicExtractor.new(@filename, :orphan).to_arry
      expect(@packs.size).to eq 96
      expect(@packs.first).to eq("62132")
      expect(@packs[7]).to eq("00687")
    end
  end
end

describe Oddb2xml::EphaExtractor do
  before(:all) { common_before }
  after(:all) { common_after }
  context "can parse epha_interactions.csv" do
    it {
      filename = File.join(Oddb2xml::SpecData, "epha_interactions.csv")
      string = IO.read(filename)
      @actions = Oddb2xml::EphaExtractor.new(string).to_arry
      expect(@actions.size).to eq(2)
    }
  end
end

describe Oddb2xml::MedregbmExtractor do
  # before(:all) { common_before }
  # after(:all) { common_after }
  it "pending"
end

describe Oddb2xml::ZurroseExtractor do
  before(:all) { common_before }
  after(:all) { common_after }
  context "when transfer.dat is empty" do
    subject { Oddb2xml::ZurroseExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context "when transfer.dat is nil" do
    subject { Oddb2xml::ZurroseExtractor.new(nil) }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'it should work also when \n is the line ending' do
    subject do
      dat = <<~DAT
        1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.size).to eq(1) }
  end
  context "when expected line is given" do
    subject do
      dat = <<~DAT
        1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq(Oddb2xml::FERRO_GRADUMET_GTIN) }
    it { expect(subject.to_hash.values.first[:price]).to eq("8.95") }
  end
  context "when Estradiol Creme is given" do
    subject do
      dat = <<~DAT
        1130921929OESTRADIOL Inj L�s 5 mg 10 Amp 1 ml               000940001630300B070820076802840708402\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680284070840") }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("9.40") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("16.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq("0921929") }
  end
  context "when SELSUN Shampoo is given" do
    subject do
      dat = <<~DAT
        1120020652SELSUN Shampoo Susp 120 ml                        001576002430300D100400076801723306812\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680172330681") }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("15.76") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("24.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq("0020652") }
    it "should set the correct SALECD cmut code" do
      expect(subject.to_hash.values.first[:cmut]).to eq("2")
    end
  end
  context "when SOFRADEX is given" do
    subject do
      dat = <<~DAT
        1130598003SOFRADEX Gtt Auric 8 ml                           000718001545300B120130076803169501572\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    # it { expect(subject.to_hash.keys.first).to eq("7680316950157") }
    it "should set the correct SALECD cmut code" do
      expect(subject.to_hash.values.first[:cmut]).to eq("3")
    end
    it "should set the correct SALECD description" do
      expect(subject.to_hash.values.first[:description]).to eq("SOFRADEX Gtt Auric 8 ml")
    end
  end
  context "when Ethacridin is given" do
    subject do
      dat = <<~DAT
        1128807890Ethacridin lactat 1\069 100ml                        0009290013701000000000000000000000002\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat, true)
    end
    it { expect(subject.to_hash.keys.first).to eq("9999998807890") }
    it "should set the correct SALECD cmut code" do
      expect(subject.to_hash.values.first[:cmut]).to eq("2")
    end
    it "should set the correct SALECD description" do
      expect(subject.to_hash.values.first[:description]).to match(/Ethacridin lactat 1.+ 100ml/)
    end
  end
  context "when parsing examples" do
    subject do
      filename = File.expand_path(File.join(__FILE__, "..", "data", "transfer.dat"))
      Oddb2xml::ZurroseExtractor.new(filename, true)
    end

    it "should extract EPIMINERAL" do
      ethacridin = subject.to_hash.values.find { |x| /EPIMINERAL/i.match(x[:description]) }
      expect(ethacridin[:description]).to eq("EPIMINERAL Paste 20 g")
    end

    {"SEMPER Cookie" => "SEMPER Cookie-O's Biskuit glutenfrei 150 g",
     "DermaSilk" => "DermaSilk Set Body + Strumpfhöschen 24-36 Mon (98)",
     "after sting Roll-on" => "CER'8 after sting Roll-on 20 ml",
     "Inkosport" => "Inkosport Activ Pro 80 Himbeer - Joghurt Ds 750g"}
      .each { |key, value|
      it "should set the correct #{key} description" do
        item = subject.to_hash.values.find { |x| /#{key}/i.match(x[:description]) }
        expect(item[:description]).to eq(value)
      end
    }
  end
end
