# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any downloader' do
  # this takes 5 sec. by call for sleep
  it 'should count retry times as retrievable or not' do
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
    it 'should cleanup current directory' do
      xml.should_not raise_error(Timeout::Error)
      File.exist?('XMLPublications.zip').should be(false)
    end
  end
end

describe Oddb2xml::SwissIndexDownloader do
  include ServerMockHelper
  before(:each) do
    setup_swiss_index_server_mock
    @downloader = Oddb2xml::SwissIndexDownloader.new()
  end
  it_behaves_like 'any downloader'
  context 'when download_by is called with DE' do
    let(:xml) { @downloader.download_by('DE') }
    it 'should parse hash to xml' do
      xml.should be_a String
      xml.length.should_not == 0
    end
    it 'should return valid xml' do
      xml.should =~ /xml\sversion="1.0"/
      xml.should =~ /ITEM/
      xml.should =~ /PHAR/
    end
  end
end
