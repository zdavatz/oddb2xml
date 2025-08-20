require "spec_helper"
require "rexml/document"

VCR.eject_cassette # we use insert/eject around each example

# not used but, as I still don't know how to generate
def filter_aips_xml(filename = "AipsDownload_ng.xml", ids_to_keep = [55558, 61848])
  puts "File #{filename} exists? #{File.exist?(filename)}"
  if $VERBOSE
    puts %(<?xml version="1.0" encoding="utf-8"?>
<medicalInformations>
  <medicalInformation type="fi" version="5" lang="de" safetyRelevant="false" informationUpdate="07.2008">
    <title>Zyvoxid®</title>
    <authHolder>Pfizer AG</authHolder>
    <atcCode>J01XX08</atcCode>
    <substances>Linezolid</substances>
    <authNrs>55558, 55559, 55560</authNrs>
)
  end
  @xml = IO.read(filename)
  ausgabe = File.open("tst.out", "w+")
  data = {}
  result = MedicalInformationsContent.parse(@xml.sub(STRIP_FOR_SAX_MACHINE, ""), lazy: true)
  result.medicalInformation.each do |pac|
    lang = pac.lang.to_s
    next unless /de|fr/.match?(lang)
    item = {}
    keep_it = false
    pac.authNrs.split(/[, ]+/).each { |id|
      if ids_to_keep.index(id.to_i)
        data[[lang, id.to_i]] = pac
        keep_it = true
        ausgabe.puts
        break
      end
    }
    html = Nokogiri::HTML.fragment(pac.content.force_encoding("UTF-8"))
    item[:paragraph] = html
    numbers = /(\d{5})[,\s]*(\d{5})?|(\d{5})[,\s]*(\d{5})?[,\s]*(\d{5})?/.match(html)
    if numbers
      [$1, $2, $3].compact.each { |id|
        if ids_to_keep.index(id.to_i)
          data[[lang, id.to_i]] = pac
          keep_it = true
          break
        end
      }
      puts "Must keep #{keep_it} #{pac.authNrs}"
    end
  end
  puts data.size
  puts data.keys
end

XML_VERSION_1_0 = /xml\sversion=["']1.0["']/
PREP_XML = "Preparations.xml"

shared_examples_for "any downloader" do
  # nothing at the moment
end

def common_before
  @saved_dir = Dir.pwd
  cleanup_directories_before_run
  FileUtils.makedirs(Oddb2xml::WORK_DIR)
  Dir.chdir(Oddb2xml::WORK_DIR)
  WebMock.enable!
  {"https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/interactions_de_utf8.csv" => "epha_interactions.csv"}.each do |url, file|
    inhalt = File.read(File.join(Oddb2xml::SpecData, file))
    stub_request(:get, url).to_return(body: inhalt)
  end
end

def common_after
  Dir.chdir(@saved_dir) if @saved_dir && File.directory?(@saved_dir)
  VCR.eject_cassette
  vcr_file = File.expand_path(File.join(Oddb2xml::SpecData, "..", "fixtures", "vcr_cassettes", "oddb2xml.json"))
  puts "Pretty-printing #{vcr_file} exists? #{File.exist?(vcr_file)}" if $VERBOSE
  vcr_file_new = vcr_file.sub(".json", ".new")
  cmd = "cat #{vcr_file} | python -mjson.tool > #{vcr_file_new}"
  system(cmd)
  FileUtils.mv(vcr_file_new, vcr_file)
end

# Zips input_filenames (using the basename)
def zip_files(zipfile_name, input_filenames)
  FileUtils.rm_f(zipfile_name)
  Zip::File.open(zipfile_name, create: true) do |zipfile|
    input_filenames.each do |filename|
      puts "Add #{filename} #{File.size(filename)} bytes as #{File.basename(filename)} #{Dir.pwd}" if $VERBOSE
      zipfile.add(File.basename(filename), filename)
    end
  end
end

# Unzips into a specific directory
def unzip_files(zipfile_name, directory = Dir.pwd)
  saved_dir = Dir.pwd
  FileUtils.makedirs(directory)
  Dir.chdir(directory)
  Zip::File.open(zipfile_name) do |zip_file|
    # Handle entries one by one
    zip_file.each do |entry|
      # Extract to file/directory/symlink
      puts "downloader_spec.rb: Extracting #{entry.name} exists? #{File.exist?(entry.name)} into #{directory}"
      FileUtils.rm_f(entry.name, verbose: true) if File.exist?(entry.name)
      entry.extract(entry.name)
    end
  end
ensure
  Dir.chdir(saved_dir)
end

describe Oddb2xml::RefdataDownloader do
  include ServerMockHelper
  before(:all) do
    VCR.eject_cassette
    VCR.configure do |c|
      c.before_record(:Refdata_DE) do |i|
        if !/WSDL$/.match(i.request.uri) && /refdatabase.refdata.ch\/Service/.match(i.request.uri) && (i.response.body.size > 1024 * 1024)
          puts "#{Time.now}: #{__LINE__}: Parsing response.body (#{i.response.body.size / (1024 * 1024)} MB ) will take some time. URI was #{i.request.uri}"
          doc = REXML::Document.new(i.response.body)
          items = doc.root.children.first.elements.first
          nr_items = doc.root.children.first.elements.first.elements.size
          puts "#{Time.now}: #{__LINE__}: Removing most of the #{nr_items} items will take some time"
          nr_searched = 0
          items.elements.each { |x|
            nr_searched += 1
            puts "#{Time.now}: #{__LINE__}: nr_searched #{nr_searched}/#{nr_items}" if nr_searched % 1000 == 0
            items.delete x unless x.elements["GTIN"] && Oddb2xml::GTINS_DRUGS.index(x.elements["GTIN"].text)
          }
          i.response.body = doc.to_s
          puts "#{Time.now}: response.body is now #{i.response.body.size / (1024 * 1024)} MB  long"
          i.response.headers["Content-Length"] = i.response.body.size
        end
      end
    end
    VCR.insert_cassette("oddb2xml", tag: :Refdata_DE)
    common_before
  end
  after(:all) do
    common_after
  end
  context "Pharma" do
    before(:all) do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :pharma)
      @xml = @downloader.download
    end
    it_behaves_like "any downloader"
    context "when download_by is called" do
      it "should parse response hash to xml" do
        expect(@xml).to be_a String
        expect(@xml.length).not_to eq(0)
        expect(@xml).to match(XML_VERSION_1_0)
      end
      it "should return valid xml" do
        expect(@xml).to match(/PHAR/)
        expect(@xml).to match(/ITEM/)
      end
    end
  end

  context "NonPharma" do
    it_behaves_like "any downloader"
    before(:all) do
      @downloader = Oddb2xml::RefdataDownloader.new({}, :nonpharma)
      @xml = @downloader.download
    end
    context "when download_by is " do
      it "should parse response hash to xml" do
        expect(@xml).to be_a String
        expect(@xml.length).not_to eq(0)
        expect(@xml).to match(XML_VERSION_1_0)
      end
      it "should return valid xml" do
        expect(@xml).to match(/NONPHAR/)
        expect(@xml).to match(/ITEM/)
      end
    end
  end
end

def cleanPackungenXlsx(info)
  m = /dokumente\/liste/i.match(info.request.uri)
  puts "#{Time.now}:  #{__LINE__} SwissmedicDownloader #{info.request.uri} #{m[1]} (#{info.response.body.size / (1024 * 1024)} MB )."
  return unless m
  name = nil
  name = "packungen" if /zugelasseneverpackungen/.match?(info.request.uri)
  name = "orphan" if /zugelasseneverpackungen/.match?(info.request.uri)
  swissmedic_dir = File.join(Oddb2xml::WORK_DIR, "swissmedic")
  FileUtils.makedirs(swissmedic_dir)
  xlsx_name = File.join(swissmedic_dir, name + ".xlsx")
  if /Packungen/i.match?(xlsx_name)
    FileUtils.rm(xlsx_name, verbose: false) if File.exist?(xlsx_name)
    File.open(xlsx_name, "wb+") { |f| f.write(info.response.body) }
    FileUtils.cp(xlsx_name, File.join(Oddb2xml::SpecData, "swissmedic_package_downloaded.xlsx"), verbose: true, preserve: true)
    puts "#{Time.now}:  #{__LINE__}: Openening saved #{xlsx_name} (#{File.size(xlsx_name)} bytes) will take some time. URI was #{info.request.uri}"
    workbook = RubyXL::Parser.parse(xlsx_name)
    worksheet = workbook[0]
    drugs = []
    Oddb2xml::GTINS_DRUGS.each do |x|
      next unless x.to_s.size == 13
      drugs << [x.to_s[4..8].to_i, x.to_s[9..11].to_i]
    end
    idx = 6
    to_delete = []
    puts "#{Time.now}: Finding items to delete will take some time"
    while worksheet.sheet_data[idx]
      idx += 1
      next unless worksheet.sheet_data[idx - 1][Oddb2xml::COLUMNS_FEBRUARY_2019.keys.index(:iksnr)]
      to_delete << (idx - 1) unless drugs.find { |x|
                                      (x[0] == worksheet.sheet_data[idx - 1][Oddb2xml::COLUMNS_FEBRUARY_2019.keys.index(:iksnr)].value.to_i) &&
                                        (x[1] == worksheet.sheet_data[idx - 1][Oddb2xml::COLUMNS_FEBRUARY_2019.keys.index(:ikscd)].value.to_i)
                                    }
    end
    if to_delete.size > 0
      puts "#{Time.now}: Deleting #{to_delete.size} of the #{idx} items will take some time"
      to_delete.reverse_each { |row_id| worksheet.delete_row(row_id) }
      workbook.write(xlsx_name)
      FileUtils.cp(xlsx_name, File.join(Oddb2xml::SpecData, "swissmedic_package_shortened.xlsx"), verbose: true, preserve: true)
      info.response.body = IO.binread(xlsx_name)
      info.response.headers["Content-Length"] = info.response.body.size
      puts "#{Time.now}: response.body is now #{info.response.body.size / (1024 * 1024)} MB  long. #{xlsx_name} was #{File.size(xlsx_name)}"
    end
  end
end

describe Oddb2xml::SwissmedicDownloader do
  include ServerMockHelper
  before(:each) do
    mock_downloads
    VCR.configure do |c|
      c.before_record(:swissmedic) do |i|
        if i.response.headers["Content-Disposition"] && /www.swissmedic.ch/.match(i.request.uri) && (i.response.body.size > 1024 * 1024)
          cleanPackungenXlsx(i)
        end
      rescue => error
        puts error if $VERBOSE
        # require "pry"; binding.pry
      end
    end
  end
  # 2015-06-10 18:54:40 UTC: SwissmedicDownloader attachment; filename="Zugelassene_Packungen_310515.xlsx" (785630 bytes). URI was https://www.swissmedic.ch/arzneimittel/00156/00221/00222/00230/index.html?download=NHzLpZeg7t,lnp6I0NTU042l2Z6ln1acy4Zn4Z2qZpnO2Yuq2Z6gpJCDdHx7hGym162epYbg2c_JjKbNoKSn6A--&lang=de

  context "orphan" do
    before(:each) do
      VCR.configure do |c|
        c.before_record(:swissmedic) do |i|
          if i.response.headers["Content-Disposition"] && /www.swissmedic.ch/.match(i.request.uri) && (i.response.body.size > 1024 * 1024)
            cleanPackungenXlsx(i)
          end
        rescue => error
          puts error if $VERBOSE
          # require "pry"; binding.pry
        end
      end
      VCR.eject_cassette
      VCR.insert_cassette("oddb2xml", tag: :swissmedic, exclusive: false)
      FileUtils.rm_rf(Oddb2xml::DOWNLOADS, verbose: true)
      common_before
      @downloader = Oddb2xml::SwissmedicDownloader.new(:orphan)
    end
    after(:each) { common_after }
    it_behaves_like "any downloader"
    context "download_by for orphan xls" do
      let(:bin) {
        @downloader.download
      }
      it "should return valid Binary-String" do
        # unless [:orphan, :package].index(@downloader.type)
        expect(bin).to be_a String
        expect(bin.bytes).not_to be nil
        # end
      end
      it "should clean up current directory" do
        unless [:orphan, :package].index(@downloader.type)
          expect { bin }.not_to raise_error
          expect(File.exist?("oddb_orphan.xls")).to eq(false)
        end
        expect(File.dirname(bin)).to be == (Oddb2xml::DOWNLOADS)
        expect(File.exist?(bin)).to eq(true)
      end
      it "should save into the download directory" do
        expect(File.exist?(bin)).to eq(true)
        expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "swissmedic_orphan.xlsx"))).to eq(true)
      end
    end
  end
  context "package" do
    before(:each) do
      VCR.eject_cassette
      VCR.insert_cassette("oddb2xml", tag: :swissmedic, exclusive: false)
      common_before
      @downloader = Oddb2xml::SwissmedicDownloader.new(:package)
      @bin = @downloader.download
    end
    after(:each) { common_after }
    context "download_by for package xls" do
      it "should return valid Binary-String" do
        expect(@bin).to be_a String
        expect(@bin.bytes).not_to be nil
      end
      it "should save into the download directory" do
        expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "swissmedic_package.xlsx"))).to eq(true)
      end
    end
  end
end

describe Oddb2xml::EphaDownloader do
  include ServerMockHelper
  before(:each) do
    buildr_capture(:stdout) {
      @downloader = Oddb2xml::EphaDownloader.new
      common_before
      Oddb2xml.add_epha_changes_for_ATC(1, 3, force_run: true)
      @csv = @downloader.download
    }
    expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "epha_interactions.csv"))).to eq(true)
  end
  after(:all) do
    common_after
  end

  it_behaves_like "any downloader"

  context "when download is called" do
    let(:csv) { @csv }
    it "should read csv as String" do
      expect(csv).to be_a String
      expect(csv.bytes).not_to be nil
    end
    it "should clean up current directory" do
      expect(File.exist?("epha_interactions.csv")).to eq(false)
    end
    it "should save under download" do
      expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "epha_interactions.csv"))).to eq(true)
    end
  end
end

describe Oddb2xml::BagXmlDownloader do
  include ServerMockHelper
  before(:all) { VCR.eject_cassette }
  before(:all) {
    VCR.configure do |c|
      c.before_record(:bag_xml) do |i|
        if i.response.headers["Content-Disposition"] && /XMLPublications.zip/.match(i.request.uri)
          bag_dir = File.join(Oddb2xml::WORK_DIR, "bag")
          FileUtils.makedirs(Oddb2xml::WORK_DIR)
          tmp_zip = File.join(Oddb2xml::WORK_DIR, "XMLPublications.zip")
          File.open(tmp_zip, "wb+") { |f| f.write(i.response.body) }
          unzip_files(tmp_zip, bag_dir)
          bag_tmp = File.join(bag_dir, PREP_XML)
          puts "#{Time.now}: #{__LINE__}: Parsing #{File.size(bag_tmp)} (#{File.size(bag_tmp)} bytes) will take some time. URI was #{i.request.uri}"
          doc = REXML::Document.new(File.read(bag_tmp))
          items = doc.root.elements
          puts "#{Time.now}: Removing most of the #{items.size} items will take some time"
          items.each { |x| items.delete x unless Oddb2xml::GTINS_DRUGS.index(x.elements["Packs/Pack/GTIN"].text); }
          File.open(bag_tmp, "wb+") { |f| f.write(doc.to_s.gsub(/\n\s+\n/, "\n")) }
          puts "Saved #{bag_tmp} (#{File.size(tmp_zip)} bytes)"
          zip_files(tmp_zip, Dir.glob("#{bag_dir}/*"))
          puts "Saved #{tmp_zip} (#{File.size(tmp_zip)} bytes)"
          i.response.body = IO.binread(tmp_zip)
          i.response.headers["Content-Length"] = i.response.body.size
          puts "#{Time.now}: response.body is now #{i.response.body.size / (1024 * 1024)} MB  long. #{tmp_zip} was #{File.size(tmp_zip)}"
        end
      end
    end
    VCR.eject_cassette
    VCR.use_cassette("oddb2xml", tag: :bag_xml) do
      @downloader = Oddb2xml::BagXmlDownloader.new
    end
    common_before
  }
  after(:each) do
    common_after
  end

  it_behaves_like "any downloader"
  context "when download is called" do
    let(:xml) {
      VCR.eject_cassette
      VCR.use_cassette("oddb2xml", tag: :bag_xml) do
        @downloader.download
      end
    }
    it "should parse zip to string" do
      expect(xml).to be_a String
      expect(xml.length).not_to eq(0)
    end
    it "should return valid xml" do
      expect(xml).to match(XML_VERSION_1_0)
      expect(xml).to match(/Preparations/)
      expect(xml).to match(/DescriptionDe/)
    end
  end
end

describe Oddb2xml::LppvDownloader do
  include ServerMockHelper
  before(:all) { VCR.eject_cassette }
  before(:all) do
    VCR.insert_cassette("oddb2xml", tag: :lppv)
    common_before
    @downloader = Oddb2xml::LppvDownloader.new
    @text = @downloader.download
  end
  after(:each) { common_after }

  it_behaves_like "any downloader"
  context "when download is called" do
    let(:txt) { @downloader.download }
    it "should read txt as String" do
      expect(@text).to be_a String
      expect(@text.bytes).not_to be nil
    end
  end
end

unless SKIP_MIGEL_DOWNLOADER
  describe Oddb2xml::MigelDownloader do
    include ServerMockHelper
    before(:all) { VCR.eject_cassette }
    before(:each) do
      @downloader = Oddb2xml::MigelDownloader.new
      VCR.insert_cassette("oddb2xml", tag: :migel)
      common_before
      @downloader.download
    end
    after(:each) { common_after }

    it_behaves_like "any downloader"
    context "when download is called" do
      let(:bin) { @downloader.download }
      it "should read xls as Binary-String" do
        expect(bin).to be_a String
        expect(bin.bytes).not_to be nil
      end
      it "should clean up current directory" do
        expect { bin }.not_to raise_error
        expect(File.exist?("oddb2xml_files_nonpharma.txt")).to eq(false)
      end
    end
  end
end

describe Oddb2xml::ZurroseDownloader do
  include ServerMockHelper
  before(:all) { VCR.eject_cassette }
  before(:each) do
    VCR.configure do |c|
      c.before_record(:zurrose) do |i|
        if /pillbox/i.match?(i.request.uri)
          puts "#{Time.now}: #{__LINE__}: URI was #{i.request.uri}"
          tmp_zip = File.join(Oddb2xml::SpecData, "vcr", "transfer.zip")
          i.response.body = IO.binread(tmp_zip)
          i.response.headers["Content-Length"] = i.response.body.size
        end
      end
    end
    VCR.insert_cassette("oddb2xml", tag: :zurrose)
    @downloader = Oddb2xml::ZurroseDownloader.new
    common_before
    @downloader.download
  end
  after(:each) { common_after }

  it_behaves_like "any downloader"
  context "when download is called" do
    let(:dat) { @downloader.download }
    it "should read dat as String" do
      expect(dat).to be_a String
      expect(dat.bytes).not_to be nil
    end
    it "should clean up current directory" do
      expect { dat }.not_to raise_error
      expect(File.exist?("transfer.dat")).to eq(false)
      expect(File.exist?("oddb2xml_zurrose_transfer.dat")).to eq(false)
      expect(File.exist?("transfer.zip")).to eq(false)
    end
    it "should save into the download directory" do
      expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "transfer.zip"))).to eq(true)
      expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "transfer.dat"))).to eq(true)
    end
  end
end

describe Oddb2xml::MedregbmDownloader do
  include ServerMockHelper
  before(:all) { VCR.eject_cassette }
  before(:each) do
    VCR.configure do |c|
      c.before_record(:medreg) do |i|
        if /medregbm.admin.ch/i.match?(i.request.uri)
          puts "#{Time.now}: #{__LINE__}: URI was #{i.request.uri} containing #{i.response.body.size / (1024 * 1024)} MB "
          begin
            medreg_dir = File.join(Oddb2xml::WORK_DIR, "medreg")
            FileUtils.makedirs(medreg_dir)
            xlsx_name = File.join(medreg_dir, /ListBetrieb/.match?(i.request.uri) ? "Betriebe.xlsx" : "Personen.xlsx")
            File.open(xlsx_name, "wb+") { |f| f.write(i.response.body) }
            puts "#{Time.now}: Openening saved #{xlsx_name} (#{File.size(xlsx_name)} bytes) will take some time. URI was #{i.request.uri}"
            workbook = RubyXL::Parser.parse(xlsx_name)
            worksheet = workbook[0]
            idx = 1
            to_delete = []
            while worksheet.sheet_data[idx]
              idx += 1
              next unless worksheet.sheet_data[idx - 1][0]
              to_delete << (idx - 1) unless Oddb2xml::GTINS_MEDREG.index(worksheet.sheet_data[idx - 1][0].value.to_i)
            end
            if to_delete.size > 0
              puts "#{Time.now}: Deleting #{to_delete.size} of the #{idx} items will take some time"
              to_delete.reverse_each { |row_id| worksheet.delete_row(row_id) }
              workbook.write(xlsx_name)
              i.response.body = IO.binread(xlsx_name)
              i.response.headers["Content-Length"] = i.response.body.size
              puts "#{Time.now}: response.body is now #{i.response.body.size / (1024 * 1024)} MB  long. #{xlsx_name} was #{File.size(xlsx_name)}"
            end
          rescue
            puts "Creating empty content, as I am unable to parse the XLSX file"
            i.response.body = ""
            i.response.headers["Content-Length"] = i.response.body.size
          end
        end
      end
    end
    common_before
  end
  after(:each) { common_after }

  context "betrieb" do
    before(:each) do
      VCR.eject_cassette
      VCR.insert_cassette("oddb2xml", tag: :medreg)
      @downloader = Oddb2xml::MedregbmDownloader.new(:company)
      @downloader.download
    end
    after(:each) { common_after }
    it_behaves_like "any downloader"
    context "download betrieb txt" do
      let(:txt) { @downloader.download }
      it "should return valid String" do
        expect(txt).to be_a String
        expect(txt.bytes).not_to be nil
      end
      it "should clean up current directory" do
        expect { txt }.not_to raise_error
        expect(File.exist?("oddb_company.xls")).to eq(false)
      end
    end
  end

  context "person" do
    before(:each) do
      VCR.eject_cassette
      VCR.insert_cassette("oddb2xml", tag: :medreg)
      @downloader = Oddb2xml::MedregbmDownloader.new(:person)
    end
    after(:each) { common_after }
    context "download person txt" do
      let(:txt) {
        # this downloads a xlsx file (2.5MB), where we should keep only the first few lines
        @downloader.download
      }
      it "should return valid String" do
        expect(txt).to be_a String
        expect(txt.bytes).not_to be nil
      end
      it "should clean up current directory" do
        expect { txt }.not_to raise_error
        expect(File.exist?("oddb_person.xls")).to eq(false)
      end
    end
  end
end

describe Oddb2xml::SwissmedicInfoDownloader do
  include ServerMockHelper
  before(:all) do
    VCR.configure do |c|
      c.before_record(:swissmedicInfo) do |i|
        puts "#{Time.now}: #{__LINE__}: URI was #{i.request.uri} returning #{i.response.body.size / (1024 * 1024)} MB"
        if i.response.headers["Content-Disposition"]
          m = /filename=([^\d]+)/.match(i.response.headers["Content-Disposition"][0])
          if m
            name = m[1].chomp("_")
            if /AipsDownload/i.match?(name)
              # we replace this by manually reduced xml file from spec/data
              # As we only use to create the fachinfo, we don't need many elements
              tmp_zip = File.join(Oddb2xml::SpecData, "AipsDownload.zip")
              i.response.body = IO.binread(tmp_zip)
              i.response.headers["Content-Length"] = i.response.body.size
              puts "#{Time.now}: #{__LINE__}: response.body is now #{i.response.body.size / (1024 * 1024)} MB long. #{tmp_zip} was #{File.size(tmp_zip)}"
            end
          end
        end
      end
    end
    VCR.eject_cassette
    VCR.insert_cassette("oddb2xml", tag: :swissmedicInfo)
    common_before
    @downloader = Oddb2xml::SwissmedicInfoDownloader.new
    @downloader.download
  end
  after(:all) { common_after }
  it_behaves_like "any downloader"
  context "when download is called" do
    let(:xml) { @downloader.download }
    it "should parse zip to String" do
      expect(xml).to be_a String
      expect(xml.length).not_to eq(0)
    end
    it "should return valid xml" do
      expect(xml).to match(XML_VERSION_1_0)
      expect(xml).to match(/medicalInformations/)
      expect(xml).to match(/content/)
    end
    it "should clean up current directory" do
      expect { xml }.not_to raise_error
      expect(File.exist?("swissmedic_info.zip")).to eq(false)
    end
    it "should save into the download directory" do
      expect(File.exist?(File.join(Oddb2xml::DOWNLOADS, "swissmedic_info.zip"))).to eq(true)
    end
  end
end
