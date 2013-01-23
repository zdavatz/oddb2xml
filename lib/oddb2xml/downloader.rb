# encoding: utf-8

require 'mechanize'
require 'zip/zip'
require 'savon'

module Oddb2xml
  class Downloader
    def initialize(options={}, url=nil)
      @options     = options
      @url         = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      init
    end
    def init
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:16.0) Gecko/20100101 Firefox/16.0'
      @agent.redirect_ok         = true
      @agent.redirection_limit   = 5
      @agent.follow_meta_refresh = true
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
    def read_xml_form_zip(target, zipfile)
      xml = ''
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|cygwin/i
        zip = ZipFile.open(zipfile) do |zipFile|
          zipFile.each do |entry|
            if entry.name =~ target
              io = entry.get_input_stream
              until io.eof?
                bytes = io.read(1024)
                xml << bytes
                bytes = nil
              end
              io.close
            end
          end
        end
        zip.close
      else
        Zip::ZipFile.foreach(zipfile) do |entry|
          if entry.name =~ target
            entry.get_input_stream { |io| xml = io.read }
          end
        end
      end
      xml
    end
  end
  class BagXmlDownloader < Downloader
    def init
      super
      @url ||= 'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip'
    end
    def download
      file = 'XMLPublications.zip'
      begin
        if @options[:debug]
          FileUtils.copy(File.expand_path("../../../spec/data/#{file}", __FILE__), '.')
        else
          response = @agent.get(@url)
          response.save_as(file)
          response = nil # win
        end
        return read_xml_form_zip(/^Preparation/iu, file)
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        if File.exists?(file)
          File.unlink(file)
        end
      end
    end
  end
  class SwissIndexDownloader < Downloader
    def initialize(options={}, type=:pharma, lang='DE')
      @type = (type == :pharma ? 'Pharma' : 'NonPharma')
      @lang = lang
      url = "https://index.ws.e-mediat.net/Swissindex/#{@type}/ws_#{@type}_V101.asmx?WSDL"
      super(options, url)
    end
    def init
      config = {
        :log_level       => :info,
        :log             => false, # $stdout
        :raise_errors    => true,
        :ssl_version     => :SSLv3,
        :wsdl            => @url
      }
      @client = Savon::Client.new(config)
    end
    def download
      begin
        if @options[:debug]
          return File.read(File.expand_path("../../../spec/data/swissindex_#{@type}_#{@lang}.xml", __FILE__))
        end
        soap = <<XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <lang xmlns="http://swissindex.e-mediat.net/Swissindex#{@type}_out_V101">#{@lang}</lang>
</soap:Body>
</soap:Envelope>
XML
        response = @client.call(:download_all, :xml => soap)
        if response.success?
          if xml = response.to_xml
            response = nil # win
            return xml
          else
            # received broken data or internal error
            raise StandardError
          end
        else
          raise Timeout::Error
        end
      rescue HTTPI::SSLError
        exit # catch me in Cli class
      rescue Timeout::Error
        retrievable? ? retry : raise
      end
    end
  end
  class SwissmedicDownloader < Downloader
    def initialize(type=:orphans)
      @type = type
      case @type
      when :orphans
        action = "daten/00081/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke0_4']//a[@title='Humanarzneimittel']"
      when :fridges
        action = "daten/00080/00254/index.html?lang=de"
        @xpath = "//table[@class='swmTableFlex']//a[@title='B3.1.35-d.xls']"
      when :packages
        action = "daten/00080/00251/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke0_7']//a[@title='Excel-Version Zugelassene Verpackungen*']"
      end
      url = "http://www.swissmedic.ch/#{action}"
      super({}, url)
    end
    def download
      file = "swissmedic_#{@type}.xls"
      begin
        page = @agent.get(@url)
        if link_node = page.search(@xpath).first
          link = Mechanize::Page::Link.new(link_node, @agent, page)
          response = link.click
          response.save_as(file)
          response = nil # win
        end
        io = File.open(file, 'rb')
        return io.read
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        io.close unless io.closed?
        if File.exists?(file)
          File.unlink(file)
        end
      end
    end
  end
  class SwissmedicInfoDownloader < Downloader
    def init
      super
      @agent.ignore_bad_chunking = true
      @url ||= "http://download.swissmedicinfo.ch/Accept.aspx?ReturnUrl=%2f"
    end
    def download
      file = "swissmedic_info.zip"
      begin
        response = nil
        if home = @agent.get(@url)
          form = home.form_with(:id => 'Form1')
          bttn = form.button_with(:name => 'ctl00$MainContent$btnOK')
          if page = form.submit(bttn)
            form = page.form_with(:id => 'Form1')
            bttn = form.button_with(:name => 'ctl00$MainContent$BtnYes')
            response = form.submit(bttn)
          end
        end
        if response
          response.save_as(file)
          response = nil # win
        end
        return read_xml_form_zip(/^AipsDownload_/iu, file)
      rescue Timeout::Error
        retrievable? ? retry : raise
      rescue NoMethodError
        # pass
      ensure
        # win
        deleted = false
        if File.exists?(file)
          until deleted
            begin
              File.unlink(file)
              deleted = true
            rescue Errno::EACCES # Permission Denied on Windows
            end
          end
        end
      end
    end
  end
  class EphaDownloader < Downloader
    def init
      super
      @url ||= 'http://community.epha.ch/interactions_de_utf8.csv'
    end
    def download
      file = "epha_interactions.csv"
      begin
        response = @agent.get(@url)
        response.save_as(file)
        response = nil # win
        io = File.open(file, 'r')
        return io.read
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        io.close unless io.closed? # win
        if File.exists?(file)
          File.unlink(file)
        end
      end
    end
  end
  class YweseeBMDownloader < Downloader
    def init
      super
      @url ||= 'http://www.ywesee.com/uploads/Main/BM_Update.txt'
    end
    def download
      file = 'ywesee_bm_update.txt'
      begin
        response = @agent.get(@url)
        response.save_as(file)
        response = nil # win
        io = File.open(file, 'r')
        return io.read
      rescue Timeout::Error
        retrievable? ? retry : raise
      ensure
        io.close unless io.closed? # win
        if File.exists?(file)
          File.unlink(file)
        end
      end
    end
  end
end
