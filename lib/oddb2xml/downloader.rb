# encoding: utf-8

require 'mechanize'
require 'zip/zip'
require 'savon'

module Oddb2xml
  class Downloader
    def initialize(url=nil)
      @url         = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      init
    end
    def init
      # pass
    end
    protected
    def retrievable?
      if @retry_times > 0
        sleep 5
        @retry_times -= 1
        true
      else
        false
      end
    end
  end
  class BagXmlDownloader < Downloader
    def init
      @url ||= 'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip'
    end
    def download
      file = 'XMLPublications.zip'
      begin
        response = Mechanize.new.get(@url)
        response.save_as file
        xml = ''
        Zip::ZipFile.foreach(file) do |entry|
          if entry.name =~ /^Preparation/iu
            entry.get_input_stream{ |io| xml = io.read }
          end
        end
        return xml
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        if File.exists? file
          File.unlink file
        end
      end
    end
  end
  class SwissIndexDownloader < Downloader
    def initialize(type=:pharma)
      @type = (type == :pharma ? 'Pharma' : 'NonPharma')
      url = "https://index.ws.e-mediat.net/Swissindex/#{@type}/ws_#{@type}_V101.asmx?WSDL"
      super(url)
    end
    def init
      Savon.configure do |config|
        config.log_level    = :info
        config.log          = false # $stdout
        config.raise_errors = true
      end
    end
    def download_by(lang = 'DE')
      client = Savon::Client.new do |wsdl, http|
        http.auth.ssl.verify_mode = :none
        wsdl.document             = @url
      end
      begin
        type = @type
        response = client.request :download_all do
          soap.xml = <<XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <lang xmlns="http://swissindex.e-mediat.net/Swissindex#{type}_out_V101">#{lang}</lang>
</soap:Body>
</soap:Envelope>
XML
        end
        if response.success?
          if xml = response.to_xml
            return xml
          else
            # received broken data or internal error
            raise StandardError
          end
        else
          raise Timeout::Error
        end
      rescue Timeout::Error
        retrievable? ? retry : raise
      end
    end
  end
end
