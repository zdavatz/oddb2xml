require "csv"
require "oddb2xml/downloader"

module Oddb2xml
  # Preferred German article names from the "Rogger Mediliste" — the
  # name-conflict list maintained by Frau Rogger (Vitabyte/Zur Rose, task
  # #OX-5985-1594). The source of truth is the shared Google Sheet
  # "Rogger Mediliste" (GTIN,Mediname); RoggerDownloader fetches its CSV
  # export directly, so sheet edits reach the feeds without any release step.
  # A bundled copy under data/ serves as offline fallback (refresh it at
  # release time when the sheet changed). A response that is not the expected
  # CSV (e.g. a Google sign-in page when the sheet is not link-shared) is
  # rejected and the fallback engages.
  #
  # Activated with -r/--rogger: for every GTIN on the list the German
  # description coming from Refdata is replaced by the list's Mediname. The
  # list is German-only, so FR/IT descriptions are left untouched. Applied as
  # the last step of Builder#apply_refdata_description_cleanups!, so it sees
  # (and wins over) the issue-#112 Refdata cleanups.
  module RoggerNames
    DATA_DIR = File.expand_path(File.join(__dir__, "..", "..", "data"))

    module_function

    # Returns a Hash keyed by the 13-digit GTIN (String):
    #   "7680672570037" => "RINVOQ Ret Tabl 30 mg 28 Stk"
    # Returns {} if the data cannot be obtained (never raises — the rest of
    # the build must proceed).
    def load(options = {})
      map = parse(source(options))
      Oddb2xml.log "RoggerNames: #{map.size} preferred names loaded"
      map
    rescue => error
      Oddb2xml.log "RoggerNames: disabled (#{error.class}: #{error.message})"
      {}
    end

    # Download the Google Sheet CSV export; fall back to the bundled copy
    # under data/ when the download is unavailable (offline, allow-list proxy)
    # or does not look like the expected CSV (sheet not link-shared, Google
    # error/sign-in page).
    def source(options)
      content = nil
      begin
        content = RoggerDownloader.new(options).download
      rescue => error
        Oddb2xml.log "RoggerNames: download of rogger_liste.csv failed (#{error.class}: #{error.message})"
      end
      unless rogger_csv?(content)
        bundled = File.join(DATA_DIR, "rogger_liste.csv")
        if File.exist?(bundled)
          Oddb2xml.log "RoggerNames: using bundled rogger_liste.csv"
          content = File.read(bundled, encoding: "UTF-8")
        end
      end
      content
    end

    # True when the content is the expected sheet export: a CSV whose header
    # row carries the GTIN and Mediname columns (rejects empty bodies and
    # HTML sign-in/error pages).
    def rogger_csv?(content)
      return false if content.nil?
      header = content.to_s.dup.force_encoding(Encoding::UTF_8)
        .sub(/\A\xEF\xBB\xBF/, "").lines.first.to_s
      /GTIN/i.match?(header) && /Mediname/i.match?(header)
    end

    def parse(csv_string)
      map = {}
      return map if csv_string.nil?
      # The list carries non-ASCII (e.g. "µg"); guard against a US-ASCII
      # default external encoding.
      csv_string = csv_string.dup.force_encoding(Encoding::UTF_8) unless csv_string.encoding == Encoding::UTF_8
      return map if csv_string.strip.empty?
      CSV.parse(csv_string, headers: true) do |row|
        gtin = row["GTIN"].to_s.strip.rjust(13, "0")
        name = row["Mediname"].to_s.strip
        next unless /\A\d{13}\z/.match?(gtin)
        next if name.empty?
        map[gtin] = name
      end
      map
    end
  end
end
