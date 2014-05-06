# encoding: utf-8

require 'mechanize'
require 'zip'
require 'savon'

module Oddb2xml
  module DownloadMethod
    private
    def download_as(file, option='r')
      tempFile  = File.join(WorkDir,   File.basename(file))
      file2save = File.join(Downloads, File.basename(file))
      Oddb2xml.log "download_as file #{file2save} via #{tempFile} from #{@url}"
      data = nil
      FileUtils.rm_f(tempFile)
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
          Oddb2xml.download_finished(tempFile)
        end
      end
      return data
    end
  end
  class Downloader
    attr_reader :type
    def initialize(options={}, url=nil)
      @options     = options
      @url         = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      Oddb2xml.log "Downloader from #{@url} for #{self.class}"
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
    def read_xml_from_zip(target, zipfile)
      Oddb2xml.log "read_xml_from_zip target is #{target} zip: #{zipfile} #{File.exists?(zipfile)}"
      if Oddb2xml.skip_download?
        entry = nil
        Dir.glob(File.join(Downloads, '*')).each { |name| if target.match(name) then entry = name; break end }
        if entry
          dest = "#{Downloads}/#{File.basename(entry)}"
          if File.exists?(dest)
            Oddb2xml.log "read_xml_from_zip return content of #{dest} #{File.size(dest)} bytes "
            return IO.read(dest)
          else
            Oddb2xml.log "read_xml_from_zip could not read #{dest}"
          end
        else
          Oddb2xml.log "read_xml_from_zip could not find #{target.to_s}"
        end
      end
      xml = ''
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|cygwin/i
        Zip::File.open(zipfile) do |zipFile|
          zipFile.each do |entry|
            if entry.name =~ target
              Oddb2xml.log "read_xml_from_zip reading #{__LINE__}: #{entry.name}"
              io = entry.get_input_stream
              until io.eof?
                bytes = io.read(1024)
                xml << bytes
                bytes = nil
              end
              io.close if io.respond_to?(:close)
              dest = "#{Downloads}/#{File.basename(target)}"
              File.open(dest, 'w+') { |f| f.write xml }
              Oddb2xml.log "read_xml_from_zip saved as #{dest}"
            end
          end
        end
      else
        Zip::File.foreach(zipfile) do |entry|
          if entry.name =~ target
            Oddb2xml.log "read_xml_from_zip #{__LINE__}: reading #{entry.name}"
            dest = "#{Downloads}/#{File.basename(entry.name)}"
            entry.get_input_stream { |io| xml = io.read }
            File.open(dest, 'w+') { |f| f.write xml }
            Oddb2xml.log "read_xml_from_zip saved as #{dest}"
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
      @url ||= 'https://download.epha.ch/cleaned/matrix.csv'
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
        content = io.read
        Oddb2xml.log("ZurroseDownloader #{__LINE__} download #{@url} @url returns #{content.bytes}")
        content   
      else
        Oddb2xml.log("ZurroseDownloader #{__LINE__} download #{@url} @url")
        download_as('zurrose_transfer.dat', 'r:iso-8859-1:utf-8')
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
      file = File.join(WorkDir, 'XMLPublications.zip')
      Oddb2xml.log "BagXmlDownloader #{__LINE__}: #{file}"
      unless Oddb2xml.skip_download(file)
        Oddb2xml.log "BagXmlDownloader #{__LINE__}: #{file}"                                       
        begin
          response = @agent.get(@url)
          response.save_as(file)
          response = nil # win
        rescue Timeout::Error, Errno::ETIMEDOUT
          retrievable? ? retry : raise
        ensure
          Oddb2xml.download_finished(file)
        end
      end
      content = read_xml_from_zip(/Preparations.xml/, File.join(Downloads, File.basename(file)))
      FileUtils.rm_f(file) unless defined?(Rspec)
      content
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
        filename =  "swissindex_#{@type}_#{@lang}.xml"
        file2save = File.join(Downloads, "swissindex_#{@type}_#{@lang}.xml")
        return IO.read(file2save) if Oddb2xml.skip_download? and File.exists?(file2save)
        FileUtils.rm_f(file2save)
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
            FileUtils.makedirs(Downloads)
            File.open(file2save, 'w+') { |file| file.write xml }
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
      xml
    end
  end
  class SwissmedicDownloader < Downloader
    def initialize(type=:orphan)
      @type = type
      case @type
      when :orphan
        action = "arzneimittel/00156/00221/00222/00223/00224/00227/00228/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke10_3']//a[@title='Humanarzneimittel']"
      when :fridge
        action = "arzneimittel/00156/00221/00222/00235/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke10_2']//a[@title='Excel-Version']"
      when :package
        action = "arzneimittel/00156/00221/00222/00230/index.html?lang=de"
        @xpath = "//div[@id='sprungmarke10_7']//a[@title='Excel-Version Zugelassene Verpackungen*']"
      end
      url = "http://www.swissmedic.ch/#{action}"
      super({}, url)
    end
    def download
      @type == file = "swissmedic_#{@type}.xlsx"
      begin
        page = @agent.get(@url)
        if link_node = page.search(@xpath).first
          link = Mechanize::Page::Link.new(link_node, @agent, page)
          response = link.click
          response.save_as(file)
          response = nil # win
        end
        return File.expand_path(file)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        Oddb2xml.download_finished(file, false)
      end # unless Oddb2xml.skip_download(file)
      return File.expand_path(file)
    end
  end
  class SwissmedicInfoDownloader < Downloader
    def init
      super
      @agent.ignore_bad_chunking = true
      @url ||= "http://download.swissmedicinfo.ch/Accept.aspx?ReturnUrl=%2f"
    end
    def download
      file = File.join(Downloads, "swissmedic_info.zip")
      FileUtils.rm_f(file) unless Oddb2xml.skip_download?
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
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      rescue NoMethodError
        # pass
      ensure
        Oddb2xml.download_finished(file)
      end unless File.exists?(file)
      read_xml_from_zip(/^AipsDownload_/iu, file)
    end
  end
end
