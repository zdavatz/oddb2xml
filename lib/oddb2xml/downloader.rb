require "net/ntlm/version" # needed to avoid error: uninitialized constant Net::NTLM::VERSION
require "rubyntlm"
require "mechanize"
require "zip"
require "savon"
require "open-uri"

SKIP_MIGEL_DOWNLOADER = true # https://github.com/zdavatz/oddb2xml_files/raw/master/NON-Pharma.xls

module Oddb2xml
  module DownloadMethod
    private

    def download_as(file, option = "w+")
      temp_file = File.join(WORK_DIR, File.basename(file))
      @file2save = File.join(DOWNLOADS, File.basename(file))
      report_download(@url, @file2save)
      data = nil
      FileUtils.makedirs(File.dirname(file), verbose: true)
      if Oddb2xml.skip_download(file)
        io = File.open(file, option)
        data = io.read
      else
        begin
          io = File.open(file, option)
          data = Oddb2xml.uri_open(@url).read
          io.sync = true
          io.write(data)
        rescue => error
          puts "error #{error} while fetching #{@url}"
        ensure
          io.close if io && !io.closed? # win
          Oddb2xml.download_finished(temp_file)
        end
      end
      data
    end
  end

  class Downloader
    attr_reader :type, :agent, :url, :file2save
    def initialize(options = {}, url = nil)
      @options = options
      @url = url
      @retry_times = 3
      HTTPI.log = false # disable httpi warning
      Oddb2xml.log "Downloader from #{@url} for #{self.class}"
      init
    end

    def report_download(url, file)
      Oddb2xml.log sprintf("%-20s: download_as %-24s from %s",
        self.class.to_s.split("::").last,
        File.basename(file),
        url)
    end

    def init
      @agent = Mechanize.new
      @agent.user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:16.0) Gecko/20100101 Firefox/16.0"
      @agent.redirect_ok = true
      @agent.redirection_limit = 5
      @agent.follow_meta_refresh = true
      if RUBY_PLATFORM =~ (/mswin|mingw|bccwin|cygwin/i) &&
          ENV["SSL_CERT_FILE"].nil?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_file(File.expand_path("../../../tools/cacert.pem", __FILE__))
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
      Oddb2xml.log "read_xml_from_zip target is #{target} zip: #{zipfile} #{File.exist?(zipfile)}"
      if Oddb2xml.skip_download?
        entry = nil
        Dir.glob(File.join(DOWNLOADS, "*")).each do |name|
          if target.match(name)
            entry = name
            break
          end
        end
        if entry
          dest = "#{DOWNLOADS}/#{File.basename(entry)}"
          @file2save = dest
          if File.exist?(dest)
            Oddb2xml.log "read_xml_from_zip return content of #{dest} #{File.size(dest)} bytes "
            return IO.read(dest)
          else
            Oddb2xml.log "read_xml_from_zip could not read #{dest}"
          end
        else
          Oddb2xml.log "read_xml_from_zip could not find #{target}"
        end
      end
      xml = ""
      if RUBY_PLATFORM.match?(/mswin|mingw|bccwin|cygwin/i)
        Zip::File.open(zipfile) do |a_zip_file|
          a_zip_file.each do |entry|
            if entry.name&.match?(target)
              Oddb2xml.log "read_xml_from_zip reading #{__LINE__}: #{entry.name}"
              io = entry.get_input_stream
              until io.eof?
                bytes = io.read(1024)
                xml << bytes
                bytes = nil
              end
              io.close if io.respond_to?(:close)
              dest = "#{DOWNLOADS}/#{File.basename(entry.name)}"
              File.open(dest, "w+") { |f| f.write xml }
              Oddb2xml.log "read_xml_from_zip saved as #{dest}"
            end
          end
        end
      else
        Zip::File.foreach(zipfile) do |entry|
          if entry.name&.match?(target)
            Oddb2xml.log "read_xml_from_zip #{__LINE__}: reading #{entry.name}"
            dest = "#{DOWNLOADS}/#{File.basename(entry.name)}"
            entry.get_input_stream { |io| xml = io.read }
            File.open(dest, "w+") { |f| f.write xml }
            Oddb2xml.log "read_xml_from_zip saved as #{dest}"
          end
        end
      end
      xml
    end
  end
  unless SKIP_MIGEL_DOWNLOADER
    class MigelDownloader < Downloader
      include DownloadMethod
      def download
        @url ||= "https://github.com/zdavatz/oddb2xml_files/raw/master/NON-Pharma.xls"
        download_as("oddb2xml_files_nonpharma.xls", "rb")
      end
    end
  end
  class EphaDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/interactions_de_utf8.csv"
      file = "epha_interactions.csv"
      content = download_as(file, "w+")
      FileUtils.rm_f(file, verbose: true)
      content
    end
  end

  class LppvDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/LPPV.txt"
      download_as("oddb2xml_files_lppv.txt", "w+")
    end
  end

  class ZurroseDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "http://pillbox.oddb.org/TRANSFER.ZIP"
      zipfile = File.join(WORK_DIR, "transfer.zip")
      download_as(zipfile)
      dest = File.join(DOWNLOADS, "transfer.dat")
      cmd = "unzip -o '#{zipfile}' -d '#{DOWNLOADS}'"
      system(cmd)
      if @options[:artikelstamm]
        cmd = "iconv -f ISO8859-1 -t utf-8 -o #{dest.sub(".dat", ".utf8")} #{dest}"
        Oddb2xml.log(cmd)
        system(cmd)
      end
      # read file and convert it to utf-8
      File.open(dest, "r:iso-8859-1:utf-8").read
    ensure
      FileUtils.rm(zipfile, verbose: true) if File.exist?(dest) && File.exist?(zipfile)
    end
  end

  class MedregbmDownloader < Downloader
    include DownloadMethod
    def initialize(type = :company)
      @type = type
      action = case @type
      when :company # betrieb
        "CreateExcelListBetriebs"
      when :person # medizinalperson
        "CreateExcelListMedizinalPersons"
      else
        ""
      end
      url = "https://www.medregbm.admin.ch/Publikation/#{action}"
      super({}, url)
    end

    def download
      file = "medregbm_#{@type}.txt"
      download_as(file, "w+:iso-8859-1:utf-8")
      report_download(@url, file)
      FileUtils.rm_f(file, verbose: true) # we need it only in the download
      file
    end
  end

  class BagXmlDownloader < Downloader
    include DownloadMethod
    def init
      super
      @url ||= "https://www.spezialitaetenliste.ch/File.axd?file=XMLPublications.zip"
    end

    def download
      file = File.join(WORK_DIR, "XMLPublications.zip")
      download_as(file)
      report_download(@url, file)
      if defined?(RSpec)
        src = File.join(Oddb2xml::SpecData, "Preparations.xml")
        content = File.read(src)
        FileUtils.cp(src, File.join(DOWNLOADS, File.basename(file)))
      else
        content = read_xml_from_zip(/Preparations.xml/, File.join(DOWNLOADS, File.basename(file)))
      end
      if @options[:artikelstamm]
        cmd = "xmllint --format --output Preparations.xml Preparations.xml"
        Oddb2xml.log(cmd)
        system(cmd)
      end
      FileUtils.rm_f(file, verbose: true) unless defined?(RSpec)
      content
    end
  end

  class RefdataDownloader < Downloader
    def initialize(options = {}, type = :pharma)
      @type = (type == :pharma ? "Pharma" : "NonPharma")
      url = "https://refdatabase.refdata.ch/Service/Article.asmx?WSDL"
      super(options, url)
    end

    def init
      config = {
        log_level: :info,
        log: false, # $stdout
        raise_errors: true,
        wsdl: @url
      }
      @client = Savon::Client.new(config)
    end

    def download
      begin
        @file2save = File.join(DOWNLOADS, "refdata_#{@type}.xml")
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
        return IO.read(@file2save) if Oddb2xml.skip_download? && File.exist?(@file2save)
        FileUtils.rm_f(@file2save, verbose: true)
        response = @client.call(:download, xml: soap)
        if response.success?
          if (xml = response.to_xml)
            xml = File.read(File.join(Oddb2xml::SpecData, File.basename(@file2save))) if defined?(RSpec)
            response = nil # win
            FileUtils.makedirs(DOWNLOADS)
            File.open(@file2save, "w+") { |file| file.write xml }
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
    BASE_URL = "https://www.swissmedic.ch"
    include DownloadMethod
    def initialize(type = :orphan, options = {})
      url = BASE_URL + "/swissmedic/de/home/services/listen_neu.html"
      doc = Nokogiri::HTML(Oddb2xml.uri_open(url))
      @type = type
      @options = options
      case @type
      when :orphan
        @direct_url_link = BASE_URL + doc.xpath("//a").find { |x| /Humanarzneimittel mit Status Orphan Drug/.match(x.children.text) }.attributes["href"].value
      when :package
        @direct_url_link = BASE_URL + doc.xpath("//a").find { |x| /Zugelassene Packungen/.match(x.children.text) }.attributes["href"].value
      end
    end

    def download
      @file2save = File.join(DOWNLOADS, "swissmedic_#{@type}.xlsx")
      report_download(@url, @file2save)
      if @options[:calc] && @options[:skip_download] && File.exist?(@file2save) && ((Time.now - File.ctime(@file2save)).to_i < 24 * 60 * 60)
        Oddb2xml.log "SwissmedicDownloader #{__LINE__}: Skip downloading #{@file2save} #{File.size(@file2save)} bytes"
        return File.expand_path(@file2save)
      end
      begin
        @url = @direct_url_link
        download_as(@file2save, "w+")
        if @options[:artikelstamm]
          # ssconvert is in the package gnumeric (Debian)
          cmd = "ssconvert '#{@file2save}' '#{File.join(DOWNLOADS, File.basename(@file2save).sub(/\.xls.*/, ".csv"))}' 2> /dev/null"
          Oddb2xml.log(cmd)
          system(cmd)
        end
        return File.expand_path(@file2save)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        Oddb2xml.download_finished(@file2save, false)
      end
      File.expand_path(@file2save)
    end
  end

  class SwissmedicInfoDownloader < Downloader
    def init
      super
      @agent.ignore_bad_chunking = true
      @url ||= "http://download.swissmedicinfo.ch/Accept.aspx?ReturnUrl=%2f"
    end

    def download
      file = File.join(DOWNLOADS, "swissmedic_info.zip")
      report_download(@url, file)
      FileUtils.rm_f(file, verbose: true) unless Oddb2xml.skip_download?
      unless File.exist?(file)
        begin
          response = nil
          if (home = @agent.get(@url))
            form = home.form_with(id: "Form1")
            bttn = form.button_with(name: "ctl00$MainContent$btnOK")
            if (page = form.submit(bttn))
              form = page.form_with(id: "Form1")
              bttn = form.button_with(name: "ctl00$MainContent$BtnYes")
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
        end
      end
      read_xml_from_zip(/^AipsDownload_/iu, file)
    end
  end

  class FirstbaseDownloader < Downloader
    BASE_URL = "http://pillbox.oddb.org"
    include DownloadMethod
    def initialize(type = :orphan, options = {})
      @url = BASE_URL + "/firstbase.xlsx"
    end

    def download
      @file2save = File.join(DOWNLOADS, "firstbase.xlsx")
      report_download(@url, @file2save)
      begin
        download_as(@file2save, "w+")
        return File.expand_path(@file2save)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      ensure
        Oddb2xml.download_finished(@file2save, false)
      end
      File.expand_path(@file2save)
    end
  end
end
