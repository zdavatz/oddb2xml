# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/downloader"
ENV['TZ'] = 'UTC' # needed for last_change

describe Oddb2xml::BMUpdateExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  before(:all) {
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
    @downloader = Oddb2xml::BMUpdateDownloader.new
    xml = @downloader.download
    @items = Oddb2xml::BMUpdateExtractor.new(xml).to_hash
  }
  it "should have at least one item" do
    expect(@items.size).not_to eq 0
  end
end

describe Oddb2xml::LppvExtractor do
  before(:all) {
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
    @downloader = Oddb2xml::LppvDownloader.new
    @content = @downloader.download
    @lppvs = Oddb2xml::LppvExtractor.new(@content).to_hash
  }
  after(:all) { VCR.eject_cassette }
  it "should have at least one item" do
    expect(@lppvs.size).not_to eq 0
  end
end

describe Oddb2xml::MigelExtractor do
  before(:all) {
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
    @downloader = Oddb2xml::MigelDownloader.new
    xml = @downloader.download
    @items = Oddb2xml::MigelExtractor.new(xml).to_hash
  }
  after(:all) { VCR.eject_cassette }
  it "should have at some items" do
    expect(@items.size).not_to eq 0
    expect(@items.find{|k,v| 3248410 == v[:pharmacode] }).not_to be_nil
    expect(@items.find{|k,v| /Novopen/i.match(v[:desc_de]) }).not_to be_nil
    expect(@items.find{|k,v| 3036984 == v[:pharmacode] }).not_to be_nil
    expect(@items.find{|k,v| /Epimineral/i.match(v[:desc_de]) }).not_to be_nil
  end
end

describe Oddb2xml::RefdataExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all)  { VCR.eject_cassette }
  context 'should handle pharma articles' do
    subject do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :pharma)
      xml = @downloader.download
      @pharma_items = Oddb2xml::RefdataExtractor.new(xml, 'PHARMA').to_hash
    end

    it "should have correct info for pharmacode 1699947 correctly" do
      @pharma_items = subject.to_hash
      pharma_code_LEVETIRACETAM = 5819012
      item_found = @pharma_items.values.find{ |x| x[:pharmacode].eql?(pharma_code_LEVETIRACETAM)}
      expect(item_found).not_to be nil
      expected = { :refdata=>true,
        :_type=>:pharma,
        :ean=> Oddb2xml::LEVETIRACETAM_GTIN.to_i,
        :pharmacode=> pharma_code_LEVETIRACETAM,
        :last_change => "2015-06-04 00:00:00 +0000",
        :desc_de=>"LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk",
        :desc_fr=>"LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce",
        :atc_code=>"N03AX14",
        :company_name=>"Desitin Pharma GmbH",
        :company_ean=>"7601001320451"}
      expect(item_found).to eq(expected)
      expect(@pharma_items.size).to eq(15)
    end
	end
  context 'should handle nonpharma articles' do
    subject do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :nonpharma)
      xml = @downloader.download
      @non_pharma_items = Oddb2xml::RefdataExtractor.new(xml, :non_pharma).to_hash
    end

    it "should have correct info for nonpharma with pharmacode 0058502 correctly" do
      @non_pharma_items = subject.to_hash
      pharma_code_TUBEGAZE = 58519
      item_found = @non_pharma_items.values.find{ |x| x[:pharmacode].eql?(pharma_code_TUBEGAZE)}
      expect(item_found).not_to be nil
      expected = {:refdata=>true,
      :_type=>:nonpharma,
      :ean=>7611600441020,
      :pharmacode=>pharma_code_TUBEGAZE,
      :last_change => "2015-06-04 00:00:00 +0000",
      :desc_de=>"TUBEGAZE Verband weiss Nr 12 20m Finger gross",
      :desc_fr=>"TUBEGAZE pans tubul blanc Nr 12 20m doigts grands",
      :atc_code=>"",
      :company_name=>"IVF HARTMANN AG",
      :company_ean=>"7601001000896"}
      expect(item_found).to eq(expected)
      expect(@non_pharma_items.size).to eq(9)
    end
  end
end

describe Oddb2xml::BagXmlExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  context 'should handle articles with and without pharmacode' do
    subject do
      dat = File.read(File.join(Oddb2xml::SpecData, 'Preparations.xml'))
      Oddb2xml::BagXmlExtractor.new(dat).to_hash
    end
    it "should handle pub_price for 1699947 correctly" do
      @items = subject.to_hash
      with_pharma = @items[Oddb2xml::THREE_TC_GTIN]
      expect(with_pharma).not_to be_nil
      expect(with_pharma[:name_de]).to eq '3TC'
      expect(with_pharma[:atc_code]).not_to be_nil
      expect(with_pharma[:pharmacodes]).to eq [1699947]
      expect(with_pharma[:packages].size).to eq(1)
      expect(with_pharma[:packages].first[0]).to eq(Oddb2xml::THREE_TC_GTIN)
      expect(with_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq('205.3')
      expect(@items.size).to eq(5)
    end
    it "should handle pub_price for 7680620690084 correctly" do
      @items = subject.to_hash
      no_pharma = @items[7680620690084]
      expect(no_pharma).not_to be_nil
      expect(no_pharma[:atc_code]).not_to be_nil
      expect(no_pharma[:pharmacodes]).not_to be_nil
      expect(no_pharma[:packages].size).to eq(1)
      expect(no_pharma[:packages].first[0]).to eq(7680620690084)
      expect(no_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq('27.8')
    end
  end
end

describe Oddb2xml::SwissmedicInfoExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::SwissmedicInfoDownloader.new
  end
  context 'builds fachfinfo' do
    it {
        xml = @downloader.download
        @infos = Oddb2xml::SwissmedicInfoExtractor.new(xml).to_hash
        expect(@infos.keys).to eq ['de', 'fr']
        expect(@infos['de'].size).to eq 5
        expect(@infos['fr'].size).to eq 2
        levetiracetam = nil
        @infos['de'].each{|info|
                    levetiracetam = info if /Levetiracetam/.match(info[:name])
                   }
        expect(levetiracetam[:owner]).to eq('Desitin Pharma GmbH')
        expect(levetiracetam[:paragraph].to_s).to match(/Packungen/)
        expect(levetiracetam[:paragraph].to_s).to match(/Zulassungsinhaberin/)
      }
  end
end

describe Oddb2xml::SwissmedicExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  context 'when transfer.dat is empty' do
    subject { Oddb2xml::SwissmedicInfoExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'can parse swissmedic_package.xlsx' do
    it {
        cleanup_directories_before_run
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_package.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :package).to_hash
        expect(@packs.size).to eq(17)
        serocytol = nil
        @packs.each{|pack|
                    serocytol = pack[1] if pack[1][:ean] == '7680620690084'
                   }
        expect(serocytol[:atc_code]).to eq('N03AX14')
        expect(serocytol[:swissmedic_category]).to eq('B')
        expect(serocytol[:package_size]).to eq('30')
        expect(serocytol[:einheit_swissmedic]).to eq('Tablette(n)')
        expect(serocytol[:substance_swissmedic]).to eq('levetiracetamum')
      }
  end
  context 'can parse swissmedic_fridge.xlsx' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_fridge.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :fridge).to_arry
        expect(@packs.size >= 17).to eq true
        expect(@packs[0]).to eq("58618")
        expect(@packs[1]).to eq("00696")
      }
  end
  context 'can parse swissmedic_orphans.xls' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_orphan.xlsx')
        expect(File.exists?(filename)).to eq(true), "File #{filename} must exists"
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :orphan).to_arry
        expect(@packs.size >= 78).to eq true
        expect(@packs.first).to eq("62132")
        expect(@packs[7]).to eq("00687")
      }
  end
end

describe Oddb2xml::EphaExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  context 'can parse epha_interactions.csv' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'epha_interactions.csv')
        string = IO.read(filename)
        @actions = Oddb2xml::EphaExtractor.new(string).to_arry
        expect(@actions.size).to eq(2) 
       }
  end
end

describe Oddb2xml::MedregbmExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  it "pending"
end

describe Oddb2xml::ZurroseExtractor do
  before(:all) { VCR.eject_cassette; VCR.insert_cassette('oddb2xml') }
  after(:all) { VCR.eject_cassette }
  context 'when transfer.dat is empty' do
    subject { Oddb2xml::ZurroseExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'when transfer.dat is nil' do
    subject { Oddb2xml::ZurroseExtractor.new(nil) }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'it should work also when \n is the line ending' do
    subject do
      dat = <<-DAT
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { subject.to_hash.size.should eq(1) }
  end
  context 'when expected line is given' do
    subject do
      dat = <<-DAT
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq(7680316440115) }
    it { expect(subject.to_hash.values.first[:price]).to eq("8.95") }
  end
  context 'when Estradiol Creme is given' do
    subject do
      dat = <<-DAT
1130921929OESTRADIOL Inj L�s 5 mg 10 Amp 1 ml               000940001630300B070820076802840708402\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq(7680284070840) }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("9.40") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("16.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq(921929) }
  end
  context 'when SELSUN Shampoo is given' do
    subject do
      dat = <<-DAT
1120020652SELSUN Shampoo Susp 120 ml                        001576002430300D100400076801723306812\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq(7680172330681) }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("15.76") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("24.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq(20652) }
    it 'should set the correct SALECD cmut code' do expect(subject.to_hash.values.first[:cmut]).to eq("2")  end
  end
  context 'when SOFRADEX is given' do
    subject do
      dat = <<-DAT
1130598003SOFRADEX Gtt Auric 8 ml                           000718001545300B120130076803169501572\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    #it { expect(subject.to_hash.keys.first).to eq("7680316950157") }
    it "should set the correct SALECD cmut code" do expect(subject.to_hash.values.first[:cmut]).to eq("3") end
    it "should set the correct SALECD description" do expect(subject.to_hash.values.first[:description]).to eq("SOFRADEX Gtt Auric 8 ml") end
  end
  context 'when Ethacridin is given' do
    subject do
      dat = <<-DAT
1128807890Ethacridin lactat 1\069 100ml                        0009290013701000000000000000000000002\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat, true)
    end
    it { expect(subject.to_hash.keys.first).to eq(8807890) }
    it "should set the correct SALECD cmut code" do expect(subject.to_hash.values.first[:cmut]).to eq("2") end
    it "should set the correct SALECD description" do expect(subject.to_hash.values.first[:description]).to match(/Ethacridin lactat 1.+ 100ml/) end
  end
  context 'when parsing examples' do
    subject do
      filename = File.expand_path(File.join(__FILE__, '..', 'data', 'zurrose_transfer.dat'))
      Oddb2xml::ZurroseExtractor.new(filename, true)
    end
    it "should set the correct Ethacridin description" do
        ethacridin = subject.to_hash.values.find{ |x| /Ethacridin/i.match(x[:description])}
        expect(ethacridin[:description]).to eq("Ethacridin lactat 1‰ 100ml")
    end
    specials = { 'SEMPER Cookie' => 'SEMPER Cookie-O’s glutenfrei 150 g',
                 'DermaSilk' => 'DermaSilk Set Body + Strumpfhöschen 24-36 Mon (98)',
                 'after sting Roll-on' => 'CER’8 after sting Roll-on 20 ml',
                 'Inkosport' => 'Inkosport Activ Pro 80 Himbeer - Joghurt Ds 750g',
                 'Ethacridin' => "Ethacridin lactat 1‰ 100ml",}.
    each{ | key, value |
            it "should set the correct #{key} description" do
                item = subject.to_hash.values.find{ |x| /#{key}/i.match(x[:description])}
                expect(item[:description]).to eq(value)
            end
          }

  end

end