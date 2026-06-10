require "csv"
require "oddb2xml/downloader"

module Oddb2xml
  # Recovers the SL reimbursement flag and the public price for the Swiss
  # "Kapitel 70" complementary medicines (Homöopathika / Anthroposophika /
  # Phytotherapeutika) that are *not* present in the BAG FHIR NDJSON feed.
  #
  # These products were historically scraped from the BAG "varia" page
  # (chapter_70_hack). That page became a JavaScript SPA (issue #118) and the
  # FHIR feed only covers a part of the catalogue, so the magistral Weleda
  # products (GTIN prefix 7611916…) arrive via ZurRose with no SL flag and a
  # zeroed/absent public price (issue #117/#121).
  #
  # Two data files close the gap. They live in
  # github.com/zdavatz/oddb2xml_files (downloaded at runtime, so they can be
  # refreshed without a gem release) with a bundled copy under data/ as an
  # offline fallback:
  #
  #   * weleda_arzneimittel.csv   GTIN -> abgabekategorie (the "… / SL" flag)
  #                               and csl (= Pharma-Gruppen-Code).
  #   * bag_sl_group_prices.csv   Pharma-Gruppen-Code -> public price (CHF,
  #                               incl. MWST). Extracted from the BAG SL
  #                               definition PDF "Homoeopathica, Anthroposophica,
  #                               Allergene.pdf" — the authoritative price source.
  #
  # Join: GTIN -> csl -> price. The csl may carry a package multiplier in the
  # form "N x <code>" (e.g. "8x2070631"), meaning the package holds N units
  # priced at <code> each, so the public price is N * price[<code>].
  #
  # The FHIR feed always wins: this enrichment is only applied to GTINs that
  # are absent from the NDJSON (see Builder#build_artikelstamm).
  module WeledaSL
    DATA_DIR = File.expand_path(File.join(__dir__, "..", "..", "data"))

    module_function

    # Returns a Hash keyed by the 13-digit GTIN (String, zero-padded):
    #   "7611916162404" => { sl: true, price: "26.95", csl: "2069591", abgabe: "FM / SL" }
    # Only rows carrying a "/ SL" Abgabekategorie are included. Returns {} if the
    # data cannot be obtained (never raises — the rest of the build must proceed).
    def load(options = {})
      prices = parse_prices(source(BagSlGroupPricesDownloader, options, "bag_sl_group_prices.csv"))
      map = build_map(source(WeledaDownloader, options, "weleda_arzneimittel.csv"), prices)
      Oddb2xml.log "WeledaSL: #{map.size} SL products with prices loaded"
      map
    rescue => error
      Oddb2xml.log "WeledaSL: disabled (#{error.class}: #{error.message})"
      {}
    end

    # Download the file from oddb2xml_files; fall back to the bundled copy under
    # data/ when the download is unavailable (e.g. an allow-list proxy blocks
    # raw.githubusercontent.com).
    def source(downloader_class, options, basename)
      content = nil
      begin
        content = downloader_class.new(options).download
      rescue => error
        Oddb2xml.log "WeledaSL: download of #{basename} failed (#{error.class}: #{error.message})"
      end
      if content.nil? || content.to_s.strip.empty?
        bundled = File.join(DATA_DIR, basename)
        if File.exist?(bundled)
          Oddb2xml.log "WeledaSL: using bundled #{basename}"
          content = File.read(bundled)
        end
      end
      content
    end

    # Pharma-Gruppen-Code => unit price (String, "NN.NN").
    def parse_prices(csv_string)
      prices = {}
      return prices if csv_string.nil? || csv_string.strip.empty?
      CSV.parse(csv_string, headers: true) do |row|
        code = row["pharma_group_code"].to_s.strip
        price = row["price_chf_incl_vat"].to_s.strip
        prices[code] = price unless code.empty? || price.empty?
      end
      prices
    end

    def build_map(csv_string, prices)
      map = {}
      return map if csv_string.nil? || csv_string.strip.empty?
      CSV.parse(csv_string, headers: true) do |row|
        next unless (row["abgabekategorie"].to_s =~ /\bSL\b/)
        gtin = row["ean"].to_s.strip.rjust(13, "0")
        next unless gtin =~ /\A\d{13}\z/
        price = resolve_price(row["csl"], prices)
        map[gtin] = {
          sl: true,
          price: price,
          csl: row["csl"].to_s.strip,
          abgabe: row["abgabekategorie"].to_s.strip
        }
      end
      map
    end

    # csl is either "<code>" or "<N> x <code>" (the package multiplier). Returns
    # the public price as a "NN.NN" String, or nil when it cannot be resolved.
    def resolve_price(csl, prices)
      csl = csl.to_s.strip
      return nil if csl.empty?
      m = csl.match(/\A(?:(\d+)\s*[x×]\s*)?(\d{7})\z/i)
      return nil unless m
      multiplier = (m[1] || "1").to_i
      base = prices[m[2]]
      return nil unless base
      sprintf("%.2f", base.to_f * multiplier)
    end
  end
end
