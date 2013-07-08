# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any downloader' do
  # this takes 5 sec. by call for sleep
  it 'should count retry times as retrievable or not', :slow => true do
    expect {
      Array.new(3).map do
        Thread.new do
          @downloader.send(:retrievable?).should be(true)
        end
      end.map(&:join)
    }.to change {
      @downloader.instance_variable_get(:@retry_times)
    }.from(3).to(0)
  end
end

describe Oddb2xml::BagXmlDownloader do
  include ServerMockHelper
  before(:each) do
    setup_bag_xml_server_mock
    @downloader = Oddb2xml::BagXmlDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:xml) { @downloader.download }
    it 'should parse zip to string' do
      xml.should be_a String
      xml.length.should_not == 0
    end
    it 'should return valid xml' do
      xml.should =~ /xml\sversion="1.0"/
      xml.should =~ /Preparations/
      xml.should =~ /DescriptionDe/
    end
    it 'should clean up current directory' do
      xml.should_not raise_error(Timeout::Error)
      File.exist?('XMLPublications.zip').should be(false)
    end
  end
end

describe Oddb2xml::SwissIndexDownloader do
  include ServerMockHelper
  before(:each) do
    setup_swiss_index_server_mock
  end
  context 'Pharma with DE' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new({}, :pharma, 'DE')
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with DE' do
      let(:xml) { @downloader.download }
      it 'should parse response hash to xml' do
        xml.should be_a String
        xml.length.should_not == 0
        xml.should =~ /xml\sversion="1.0"/
      end
      it 'should return valid xml' do
        xml.should =~ /PHAR/
        xml.should =~ /ITEM/
      end
    end
  end
  context 'NonPharma with FR' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new({}, :nonpharma, 'FR')
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with FR' do
      let(:xml) { @downloader.download }
      it 'should parse response hash to xml' do
        xml.should be_a String
        xml.length.should_not == 0
        xml.should =~ /xml\sversion="1.0"/
      end
      it 'should return valid xml' do
        xml.should =~ /NONPHAR/
        xml.should =~ /ITEM/
      end
    end
  end
end

describe Oddb2xml::SwissmedicDownloader do
  include ServerMockHelper
  context 'orphan' do
    before(:each) do
      setup_swissmedic_server_mock
      @downloader = Oddb2xml::SwissmedicDownloader.new(:orphan)
    end
    it_behaves_like 'any downloader'
    context 'download_by for orphan xls' do
      let(:bin) { @downloader.download }
      it 'should return valid Binary-String' do
        bin.should be_a String
        bin.bytes.should_not nil
      end
      it 'should clean up current directory' do
        bin.should_not raise_error(Timeout::Error)
        File.exist?('oddb_orphan.xls').should be(false)
      end
    end
  end
  context 'fridge' do
    before(:each) do
      setup_swissmedic_server_mock
      @downloader = Oddb2xml::SwissmedicDownloader.new(:fridge)
    end
    context 'download_by for fridge xls' do
      let(:bin) { @downloader.download }
      it 'should return valid Binary-String' do
        bin.should be_a String
        bin.bytes.should_not nil
      end
      it 'should clean up current directory' do
        bin.should_not raise_error(Timeout::Error)
        File.exist?('oddb_fridge.xls').should be(false)
      end
    end
  end
  context 'package' do
    before(:each) do
      setup_swissmedic_server_mock
      @downloader = Oddb2xml::SwissmedicDownloader.new(:package)
    end
    context 'download_by for package xls' do
      let(:bin) { @downloader.download }
      it 'should return valid Binary-String' do
        bin.should be_a String
        bin.bytes.should_not nil
      end
      it 'should clean up current directory' do
        bin.should_not raise_error(Timeout::Error)
        File.exist?('oddb_package.xls').should be(false)
      end
    end
  end
end

describe Oddb2xml::SwissmedicInfoDownloader do
  include ServerMockHelper
  before(:each) do
    setup_swissmedic_info_server_mock
    @downloader = Oddb2xml::SwissmedicInfoDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:xml) { @downloader.download }
    it 'should parse zip to String' do
      xml.should be_a String
      xml.length.should_not == 0
    end
    it 'should return valid xml' do
      xml.should =~ /xml\sversion="1.0"/
      xml.should =~ /medicalInformations/
      xml.should =~ /content/
    end
    it 'should clean up current directory' do
      xml.should_not raise_error(Timeout::Error)
      File.exist?('swissmedic_info.zip').should be(false)
    end
  end
end

describe Oddb2xml::EphaDownloader do
  include ServerMockHelper
  before(:each) do
    setup_epha_server_mock
    @downloader = Oddb2xml::EphaDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:csv) { @downloader.download }
    it 'should read csv as String' do
      csv.should be_a String
      csv.bytes.should_not nil
    end
    it 'should clean up current directory' do
      csv.should_not raise_error(Timeout::Error)
      File.exist?('epha_interactions.csv').should be(false)
    end
  end
end

describe Oddb2xml::BMUpdateDownloader do
  include ServerMockHelper
  before(:each) do
    setup_bm_update_server_mock
    @downloader = Oddb2xml::BMUpdateDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:txt) { @downloader.download }
    it 'should read txt as String' do
      txt.should be_a String
      txt.bytes.should_not nil
    end
    it 'should clean up current directory' do
      txt.should_not raise_error(Timeout::Error)
      File.exist?('oddb2xml_files_bm_update.txt').should be(false)
    end
  end
end

describe Oddb2xml::LppvDownloader do
  include ServerMockHelper
  before(:each) do
    setup_lppv_server_mock
    @downloader = Oddb2xml::LppvDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:txt) { @downloader.download }
    it 'should read txt as String' do
      txt.should be_a String
      txt.bytes.should_not nil
    end
    it 'should clean up current directory' do
      txt.should_not raise_error(Timeout::Error)
      File.exist?('oddb2xml_files_lppv.txt').should be(false)
    end
  end
end

describe Oddb2xml::MigelDownloader do
  include ServerMockHelper
  before(:each) do
    setup_migel_server_mock
    @downloader = Oddb2xml::MigelDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:bin) { @downloader.download }
    it 'should read xls as Binary-String' do
      bin.should be_a String
      bin.bytes.should_not nil
    end
    it 'should clean up current directory' do
      bin.should_not raise_error(Timeout::Error)
      File.exist?('oddb2xml_files_nonpharma.txt').should be(false)
    end
  end
end

describe Oddb2xml::MedregbmDownloader do
  include ServerMockHelper
  context 'betrieb' do
    before(:each) do
      setup_medregbm_server_mock
      @downloader = Oddb2xml::MedregbmDownloader.new(:company)
    end
    it_behaves_like 'any downloader'
    context 'download betrieb txt' do
      let(:txt) { @downloader.download }
      it 'should return valid String' do
        txt.should be_a String
        txt.bytes.should_not nil
      end
      it 'should clean up current directory' do
        txt.should_not raise_error(Timeout::Error)
        File.exist?('oddb_company.xls').should be(false)
      end
    end
  end
  context 'person' do
    before(:each) do
      setup_medregbm_server_mock
      @downloader = Oddb2xml::MedregbmDownloader.new(:person)
    end
    context 'download person txt' do
      let(:txt) { @downloader.download }
      it 'should return valid String' do
        txt.should be_a String
        txt.bytes.should_not nil
      end
      it 'should clean up current directory' do
        txt.should_not raise_error(Timeout::Error)
        File.exist?('oddb_person.xls').should be(false)
      end
    end
  end
end

describe Oddb2xml::ZurroseDownloader do
  include ServerMockHelper
  before(:each) do
    setup_zurrose_server_mock
    @downloader = Oddb2xml::ZurroseDownloader.new
  end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:dat) { @downloader.download }
    it 'should read dat as String' do
      dat.should be_a String
      dat.bytes.should_not nil
    end
    it 'should clean up current directory' do
      dat.should_not raise_error(Timeout::Error)
      File.exist?('oddb2xml_zurrose_transfer.dat').should be(false)
    end
  end
end
