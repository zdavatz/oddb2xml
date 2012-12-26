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
    @downloader = Oddb2xml::BagXmlDownloader.new()
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
  context 'Pharma' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new(:pharma)
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with DE' do
      let(:xml) { @downloader.download_by('DE') }
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
  context 'NonPharma' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new(:nonpharma)
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with DE' do
      let(:xml) { @downloader.download_by('DE') }
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

describe Oddb2xml::SwissmedicDownloader do
  include ServerMockHelper
  before(:each) do
    setup_swissmedic_server_mock
    @downloader = Oddb2xml::SwissmedicDownloader.new()
  end
  it_behaves_like 'any downloader'
  context 'download_by for orphans xls' do
    let(:io) { @downloader.download_by(:orphans) }
    it 'should return valid IO' do
      io.should be_a IO
      io.bytes.should_not nil
    end
    it 'should clean up current directory' do
      io.should_not raise_error(Timeout::Error)
      File.exist?('oddb_orphans.xls').should be(false)
    end
  end
  context 'download_by for fridges xls' do
    let(:io) { @downloader.download_by(:fridges) }
    it 'should return valid IO' do
      io.should be_a IO
      io.bytes.should_not nil
    end
    it 'should clean up current directory' do
      io.should_not raise_error(Timeout::Error)
      File.exist?('oddb_fridges.xls').should be(false)
    end
  end
end

end
