# encoding: utf-8

require 'net/ntlm/version' # needed to avoid error: uninitialized constant Net::NTLM::VERSION
require 'rubyntlm'
require 'mechanize'
require 'zip'
require 'savon'
require 'open-uri'

SkipMigelDownloader = true  # https://github.com/zdavatz/oddb2xml_files/raw/master/NON-Pharma.xls

module Oddb2xml
  module DownloadMethod
    private
    def download_as(file, option='w+')
      tempFile  = File.join(WorkDir,   File.basename(file))
      @file2save = File.join(Downloads, File.basename(file))
      report_download(@url, @file2save)
      data = nil
      if Oddb2xml.skip_download(file)
        io = File.open(file, option)
        data = io.read
      else
        begin
          io = File.open(file, option)
          data = open(@url).read
          io.write(data)
        rescue => error
          puts "error #{error} while fetching #{@url}"
        ensure
          io.close if io and !io.closed? # win
          Oddb2xml.download_finished(tempFile)
        end
      end
      return data
    end
  end
  class Downloader
    attr_reader :type, :agent, :url; :file2save
    def initialize(options={}, url=nil)
      @options     = options
      @url         = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      Oddb2xml.log "Downloader from #{@url} for #{self.class}"
      init
    end
    def report_download(url, file)
      Oddb2xml.log sprintf("%-20s: download_as %-24s from %s",
                           self.class.to_s.split('::').last,
                           File.basename(file),
                           url)
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
      @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
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
          @file2save = dest
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
              dest = "#{Downloads}/#{File.basename(entry.name)}"
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
  end unless SkipMigelDownloader
  class EphaDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'https://download.epha.ch/cleaned/matrix.csv'
      file = 'epha_interactions.csv'
      content = download_as(file, 'w+')
      FileUtils.rm_f(file, :verbose => false)
      content
    end
  end
  class LppvDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/LPPV.txt'
      download_as('oddb2xml_files_lppv.txt', 'w+')
    end
  end
  class ZurroseDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= 'http://pillbox.oddb.org/TRANSFER.ZIP'
      zipfile = File.join(WorkDir, 'transfer.zip')
      download_as(zipfile)
      dest = File.join(Downloads, 'transfer.dat')
      cmd = "unzip -o '#{zipfile}' -d '#{Downloads}'"
      system(cmd)
      if @options[:artikelstamm]
        cmd = "iconv -f ISO8859-1 -t utf-8 -o #{dest.sub('.dat','.utf8')} #{dest}"
        Oddb2xml.log(cmd)
        system(cmd)
      end
      # read file and convert it to utf-8
      File.open(dest, 'r:iso-8859-1:utf-8').read
    ensure
      FileUtils.rm(zipfile) if File.exist?(dest) && File.exist?(zipfile)
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
      file = "medregbm_#{@type.to_s}.txt"
      download_as(file, 'w+:iso-8859-1:utf-8')
      report_download(@url, file)
      FileUtils.rm_f(file, :verbose => false) # we need it only in the download
      file
    end
  end
  class BagXmlDownloader < Downloader
    include DownloadMethod
    def init
      super
      @url ||= 'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip'
    end
    def download
      file = File.join(WorkDir, 'XMLPublications.zip')
      download_as(file)
      report_download(@url, file)
      if defined?(RSpec)
        src = File.join(Oddb2xml::SpecData, 'Preparations.xml')
        content =  File.read(src)
        FileUtils.cp(src, File.join(Downloads, File.basename(file)))
      else
        content = read_xml_from_zip(/Preparations.xml/, File.join(Downloads, File.basename(file)))
      end
      if @options[:artikelstamm]
        cmd = "xmllint --format --output Preparations.xml Preparations.xml"
        Oddb2xml.log(cmd)
        system(cmd)
      end
      FileUtils.rm_f(file, :verbose => false) unless defined?(RSpec)
      content
    end
  end
  class RefdataDownloader < Downloader
    def initialize(options={}, type=:pharma)
      @type = (type == :pharma ? 'Pharma' : 'NonPharma')
      url = "http://refdatabase.refdata.ch/Service/Article.asmx?WSDL"
      super(options, url)
    end
    def init
      config = {
        :log_level       => :info,
        :log             => false, # $stdout
        :raise_errors    => true,
        :wsdl            => @url
      }
      @client = Savon::Client.new(config)
    end
    def download
      begin
        filename =  "refdata_#{@type}.xml"
        @file2save = File.join(Downloads, "refdata_#{@type}.xml")
				soap = %(<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://refdatabase.refdata.ch/Article_in" xmlns:ns2="http://refdatabase.refdata.ch/">
  <SOAP-ENV:Body>
    <ns2:DownloadArticleInput>
      <ns1:ATYPE>#{@type.upcase}</ns1:ATYPE>
    </ns2:DownloadArticleInput>
  </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
</ns1:ATYPE></ns2:DownloadArticleInput></SOAP-ENV:Body>
)
        report_download(@url, @file2save)
        return IO.read(@file2save) if Oddb2xml.skip_download? and File.exists?(@file2save)
        FileUtils.rm_f(@file2save, :verbose => false)
        response = @client.call(:download, :xml => soap)
        if response.success?
          if xml = response.to_xml
            xml =  File.read(File.join(Oddb2xml::SpecData, File.basename(@file2save))) if defined?(RSpec)
            response = nil # win
            FileUtils.makedirs(Downloads)
            File.open(@file2save, 'w+') { |file| file.write xml }
            if @options[:artikelstamm]
              cmd = "xmllint --format --output #{@file2save} #{@file2save}"
              Oddb2xml.log(cmd)
              system(cmd)
            end
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
    include DownloadMethod
    def initialize(type=:orphan, options = {})
      @type = type
      @options = options
      case @type
      when :orphan
        @direct_url_link = "https://www.swissmedic.ch/dam/swissmedic/de/dokumente/listen/humanarzneimittel.orphan.xlsx.download.xlsx/humanarzneimittel.xlsx"
      when :package
        @direct_url_link = "https://www.swissmedic.ch/dam/swissmedic/de/dokumente/listen/excel-version_zugelasseneverpackungen.xlsx.download.xlsx/excel-version_zugelasseneverpackungen.xlsx"
      end
    end
    def download
      @file2save = File.join(Oddb2xml::WorkDir, "swissmedic_#{@type}.xlsx")
      report_download(@url, @file2save)
      if  @options[:calc] and @options[:skip_download] and File.exists?(@file2save) and (Time.now-File.ctime(@file2save)).to_i < 24*60*60
        Oddb2xml.log "SwissmedicDownloader #{__LINE__}: Skip downloading #{@file2save} #{File.size(@file2save)} bytes"
          return File.expand_path(@file2save)
      end
      begin
        FileUtils.rm(File.expand_path(@file2save), :verbose => !defined?(RSpec)) if File.exists?(File.expand_path(@file2save))
        @url = @direct_url_link
        download_as(@file2save, 'w+')
        if @options[:artikelstamm]
          cmd = "ssconvert '#{@file2save}' '#{File.join(Downloads, File.basename(@file2save).sub(/\.xls.*/, '.csv'))}' 2> /dev/null"
          Oddb2xml.log(cmd)
          system(cmd)
        end
        return File.expand_path(@file2save)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        Oddb2xml.download_finished(@file2save, false)
      end
      return File.expand_path(@file2save)
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
      report_download(@url, file)
      FileUtils.rm_f(file, :verbose => false) unless Oddb2xml.skip_download?
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
