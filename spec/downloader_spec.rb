# encoding: utf-8

require 'spec_helper'
require 'webmock/rspec'

module SavonWebMock
  def define_mock
    # wsdl
    stub_wsdl_url = 'https://example.com/test?wsdl'
    stub_response = File.read(File.expand_path('../data/wsdl.xml', __FILE__))
    stub_request(:get, stub_wsdl_url).
      with(:headers => {
        'Accept' => '*/*',
        'User-Agent' => 'Ruby'}).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/xml; charset=utf-8'},
        :body    => stub_response)
    # soap
    stub_soap_url = 'https://example.com/test'
    stub_response = File.read(File.expand_path('../data/swissindex.xml', __FILE__))
    stub_request(:post, stub_soap_url).
      with(:headers => {
        'Accept'     => '*/*',
        'User-Agent' => 'Ruby'}).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/xml; chaprset=utf-8'},
        :body    => stub_response)
  end
end

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
  before(:all) do
    test_zip    = 'file://' + File.expand_path('../data/XMLPublications.zip', __FILE__)
    @downloader = Oddb2xml::BagXmlDownloader.new(test_zip)
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
  include SavonWebMock
  before(:each) do
    define_mock
    test_wsdl   = 'https://example.com/test?wsdl'
    @downloader = Oddb2xml::SwissIndexDownloader.new(test_wsdl)
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
