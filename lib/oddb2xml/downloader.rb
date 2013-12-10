# encoding: utf-8

require 'mechanize'
require 'zip/zip'
require 'savon'

module Oddb2xml
  module DownloadMethod
    private
    def download_as(file, option='r')
      data = nil
      if Oddb2xml.skip_download(file)
        io = File.open(file, option)
        data = io.read
      else
        begin
          response = @agent.get(@url)
          response.save_as(file)
          response = nil # win
          io = File.open(file, option)
          data = io.read
        rescue Timeout::Error, Errno::ETIMEDOUT
          retrievable? ? retry : raise
        ensure
          io.close if io and !io.closed? # win
          Oddb2xml.download_finished(file)
        end
      end
      return data
    end
  end
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
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|cygwin/i and
         ENV['SSL_CERT_FILE'].nil?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_file(File.expand_path('../../../tools/cacert.pem', __FILE__))
        @agent.cert_store = cert_store
      end
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
        Zip::ZipFile.open(zipfile) do |zipFile|
          zipFile.each do |entry|
            if entry.name =~ target
              io = entry.get_input_stream
              until io.eof?
                bytes = io.read(1024)
                xml << bytes
                bytes = nil
              end
              io.close if io.respond_to?(:close)
            end
          end
        end
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
  class MigelDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'https://github.com/zdavatz/oddb2xml_files/raw/master/NON-Pharma.xls'
      download_as('oddb2xml_files_nonpharma.xls', 'rb')
    end
  end
  class EphaDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'http://community.epha.ch/interactions_de_utf8.csv'
      download_as('epha_interactions.csv', 'r')
    end
  end
  class BMUpdateDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'https://raw.github.com/zdavatz/oddb2xml_files/master/BM_Update.txt'
      download_as('oddb2xml_files_bm_update.txt', 'r')
    end
  end
  class LppvDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'https://raw.github.com/zdavatz/oddb2xml_files/master/LPPV.txt'
      download_as('oddb2xml_files_lppv.txt', 'r')
    end
  end
  class ZurroseDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'http://zurrose.com/fileadmin/main/lib/download.php?file=/fileadmin/user_upload/downloads/ProduktUpdate/IGM11_mit_MwSt/Vollstamm/transfer.dat'
      unless @url =~ /^http/
        io = File.open(@url, 'r:iso-8859-1:utf-8')
        io.read
      else
        download_as('oddb2xml_zurrose_transfer.dat', 'r:iso-8859-1:utf-8')
      end
    end
  end
  class MedregbmDownloader < Downloader
    include DownloadMethod
    def initialize(type=:company)
      @type = type
      case @type
      when :company # betrieb
        action = 'CreateExcelListBetriebs'
      when :person  # medizinalperson
        action = 'CreateExcelListMedizinalPersons'
      else
        action = ''
      end
      url = "https://www.medregbm.admin.ch/Publikation/#{action}"
      super({}, url)
    end
    def download
      download_as("medregbm_#{@type.to_s}.txt", 'r:iso-8859-1:utf-8')
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
          unless Oddb2xml.skip_download(file)
            response = @agent.get(@url)
            response.save_as(file)
            response = nil # win
          end
        end
        read_xml_form_zip(/^Preparation/iu, file)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        Oddb2xml.download_finished(file)
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
        file2save = File.expand_path("../../../data/download/swissindex_#{@type}_#{@lang}.xml", __FILE__)
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
            File.open(file2save, 'w+') { |file| file.puts xml }
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
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      end
    end
  end
  class SwissmedicDownloader < Downloader
    def initialize(type=:orphan)
      @type = type
      case @type
      when :orphan
        action = "daten/00081/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke0_4']//a[@title='Humanarzneimittel']"
      when :fridge
        action = "daten/00080/00254/index.html?lang=de"
        @xpath = "//table[@class='swmTableFlex']//a[@title='B3.1.35-d.xls']"
      when :package
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
          unless Oddb2xml.skip_download(file)
            response = link.click
            response.save_as(file)
            response = nil # win
          end
        end
        io = File.open(file, 'rb')
        return io.read
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        io.close if io and !io.closed?
        Oddb2xml.download_finished(file)
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
        unless Oddb2xml.skip_download(file)
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
        end
        read_xml_form_zip(/^AipsDownload_/iu, file)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      rescue NoMethodError
        # pass
      ensure
        Oddb2xml.download_finished(file)
      end
    end
  end
end
