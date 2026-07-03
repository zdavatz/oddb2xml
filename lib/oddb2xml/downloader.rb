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
        # The file has just been restored from the download cache. Open it
        # read-only: a write mode like "w+" would truncate the cached file to
        # zero bytes before the read, silently emptying it (e.g. it blanked
        # epha_interactions.csv on every --skip-download run). Preserve any
        # encoding suffix (e.g. "w+:iso-8859-1:utf-8" -> "r:iso-8859-1:utf-8").
        read_option = option.sub(/\A[wa]\+?/, "r")
        io = File.open(file, read_option)
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
      xml.force_encoding("UTF-8") if xml.encoding.name != "UTF-8"
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

  # Weleda "Kapitel 70" article list (GTIN, Abgabekategorie/SL flag,
  # Pharma-Gruppen-Code). See Oddb2xml::WeledaSL.
  class WeledaDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/weleda_arzneimittel.csv"
      download_as("weleda_arzneimittel.csv", "w+")
    end
  end

  # WALA "Kapitel 70" article list (GTIN, Abgabekategorie, Pharma-Gruppen-Code
  # and the inline BAG SL 70.01 package price). See Oddb2xml::WeledaSL.
  class WalaDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/wala_arzneimittel.csv"
      download_as("wala_arzneimittel.csv", "w+")
    end
  end

  # BAG SL Pharma-Gruppen-Code -> public price table, extracted from the BAG SL
  # definition PDF "Homoeopathica, Anthroposophica, Allergene". See WeledaSL.
  class BagSlGroupPricesDownloader < Downloader
    include DownloadMethod
    def download
      @url ||= "https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/bag_sl_group_prices.csv"
      download_as("bag_sl_group_prices.csv", "w+")
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
    include DownloadMethod
    def initialize(options = {}, type = :pharma)
      url = "https://files.refdata.ch/simis-public-prod/Articles/1.0/Refdata.Articles.zip"
      super(options, url)
    end

    def init
      # No SOAP client needed - we download a zip file directly
    end

    def download
      filename = "Refdata.Articles.zip"
      download_as(filename, "w+")
      content = read_xml_from_zip(/Refdata.Articles.xml/, File.join(DOWNLOADS, filename))
      content
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
      if @options[:calc] && @options[:skip_download] && File.exist?(@file2save) && ((Time.now - File.ctime(@file2save)).to_i < 24 * 60 * 60) && Oddb2xml.valid_zip?(@file2save)
        Oddb2xml.log "SwissmedicDownloader #{__LINE__}: Skip downloading #{@file2save} #{File.size(@file2save)} bytes"
        return File.expand_path(@file2save)
      end
      begin
        @url = @direct_url_link
        download_as(@file2save, "w+")
        # The Swissmedic file is an .xlsx (a ZIP). Downloads through scanning
        # proxies are sometimes truncated (valid header, missing EOCD), which
        # would later crash RubyXL with a cryptic rubyzip error. Verify the
        # archive is complete and just fetch it again if not. (issue #121)
        unless Oddb2xml.valid_zip?(@file2save)
          raise Oddb2xml::IncompleteDownloadError,
            "Swissmedic #{@type} xlsx is empty or truncated (#{File.size(@file2save)} bytes)"
        end
        if @options[:artikelstamm]
          # ssconvert is in the package gnumeric (Debian)
          cmd = "ssconvert '#{@file2save}' '#{File.join(DOWNLOADS, File.basename(@file2save).sub(/\.xls.*/, ".csv"))}' 2> /dev/null"
          Oddb2xml.log(cmd)
          system(cmd)
        end
        return File.expand_path(@file2save)
      rescue Timeout::Error, Errno::ETIMEDOUT, Oddb2xml::IncompleteDownloadError => error
        if retrievable?
          Oddb2xml.log("Retrying Swissmedic #{@type} download: #{error.message}")
          retry
        end
        raise
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
    BASE_URL = "https://id.gs1.ch/01/07612345000961"
    include DownloadMethod
    def initialize(type = :orphan, options = {})
      @url = BASE_URL
    end

    # A valid firstbase export is a non-empty CSV. When GS1 is unavailable it
    # answers with an HTML error page (the GetFirstbaseHealthcare endpoint has
    # been returning "403 - Forbidden: Access is denied") or open-uri raises.
    # The old "w+" download truncated firstbase.csv to zero bytes on any such
    # failure, silently dropping every NONPHARMA article. Reject non-CSV bodies
    # so the caller can keep the previous good firstbase.csv instead.
    def firstbase_csv?(text)
      return false if text.nil?
      head = text[0, 512].to_s.strip.downcase
      return false if head.empty?
      return false if head.start_with?("<!doctype", "<html", "<?xml")
      return false if head.include?("403 - forbidden") || head.include?("access is denied")
      true
    end

    def download
      @file2save = File.join(DOWNLOADS, "firstbase.csv")
      report_download(@url, @file2save)
      # Price-increment / Artikelstamm runs (--skip-download) reuse the cached
      # firstbase.csv. Do NOT skip merely because the file exists: the nightly
      # deploy seeds a last-good copy so a GS1 outage does not blank the feed,
      # and we still want a fresh download attempt on the first (downloading)
      # build so a recovered GS1 refreshes the data.
      if Oddb2xml.skip_download? && File.size?(@file2save)
        Oddb2xml.log "FirstbaseDownloader: --skip-download, reusing cached #{@file2save} (#{File.size(@file2save)} bytes)"
        return File.expand_path(@file2save)
      end
      begin
        data = Oddb2xml.uri_open(@url).read
        if firstbase_csv?(data)
          File.write(@file2save, data)
          Oddb2xml.log "FirstbaseDownloader: fetched fresh firstbase.csv (#{data.bytesize} bytes)"
        elsif File.size?(@file2save)
          Oddb2xml.log "FirstbaseDownloader: GS1 returned no CSV (#{data.to_s.bytesize} bytes); keeping existing #{@file2save} (#{File.size(@file2save)} bytes)"
        else
          Oddb2xml.log "FirstbaseDownloader: GS1 returned no CSV and there is no cached firstbase.csv to fall back to"
        end
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      rescue => error
        # 403 / blocked / unreachable: keep any existing firstbase.csv (e.g. the
        # last-good copy the deploy script seeds) rather than truncating it.
        if File.size?(@file2save)
          Oddb2xml.log "FirstbaseDownloader: download failed (#{error.class}: #{error}); keeping existing #{@file2save} (#{File.size(@file2save)} bytes)"
        else
          Oddb2xml.log "FirstbaseDownloader: download failed (#{error.class}: #{error}) and no cached firstbase.csv to fall back to"
        end
      ensure
        Oddb2xml.download_finished(@file2save, false)
      end
      File.expand_path(@file2save)
    end
  end
end
