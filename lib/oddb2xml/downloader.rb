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
      @config = {
        :log_level       => :info,
        :log             => false, # $stdout
        :raise_errors    => true,
        :ssl_verify_mode => :none,
        :wsdl            => @url
      }
    end
    def download_by(lang = 'DE')
      client = Savon::Client.new(@config)
      begin
        type = @type
        soap = <<XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <lang xmlns="http://swissindex.e-mediat.net/Swissindex#{type}_out_V101">#{lang}</lang>
</soap:Body>
</soap:Envelope>
XML
        response = client.call(:download_all, :xml => soap)
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
  class SwissmedicDownloader < Downloader
    HOST = 'http://www.swissmedic.ch'
    def init
    end
    def download_by(index=:orphans)
      case index
      when :orphans
        @url ||= "#{HOST}/daten/00081/index.html?lang=de"
        xpath =  "//div[@id='sprungmarke0_4']//a[@title='Humanarzneimittel']"
      when :fridges
        @url ||= "#{HOST}/daten/00080/00254/index.html?lang=de"
        xpath =  "//table[@class='swmTableFlex']//a[@title='B3.1.35-d.xls']"
      end
      file = "swissmedic_#{index}.xls"
      begin
        agent = Mechanize.new
        page = agent.get(@url)
        if link = page.search(xpath).first
          url = HOST + link['href']
          response = agent.get(url)
          response.save_as file
        end
        return File.open(file, 'rb')
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        if File.exists? file
          File.unlink file
        end
      end
    end
  end
end
