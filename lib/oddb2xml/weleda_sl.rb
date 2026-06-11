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
  #   * wala_arzneimittel.csv     The same gap for WALA products (GTIN prefix
  #                               7640187…). Different layout (";"-separated,
  #                               BOM): a row is SL when it carries a CSL-Code
  #                               (Kapitel-70.01 group code) and the public
  #                               package price is given *inline* in the
  #                               "CSL 70.01." column — already multiplied for
  #                               the pack size (the multiplier lives only in the
  #                               galenic-form text, e.g. "Solutio ad inj.
  #                               10 x 1 ml"), so it is used verbatim rather than
  #                               re-joined against bag_sl_group_prices.csv.
  #
  # Weleda join: GTIN -> csl -> price. The csl may carry a package multiplier in
  # the form "N x <code>" (e.g. "8x2070631"), meaning the package holds N units
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
      weleda_size = map.size
      build_wala_map(source(WalaDownloader, options, "wala_arzneimittel.csv")).each do |gtin, entry|
        map[gtin] ||= entry # Weleda wins on the (unlikely) GTIN collision
      end
      Oddb2xml.log "WeledaSL: #{map.size} SL products with prices loaded " \
        "(Weleda #{weleda_size}, WALA #{map.size - weleda_size})"
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

    # WALA layout: ";"-separated, BOM, header columns carry trailing spaces.
    # A row is an SL product when it has a CSL-Code (Kapitel-70.01 group code);
    # the public package price is taken verbatim from the inline "CSL 70.01."
    # column (already multiplied for the pack size). Keyed by 13-digit GTIN.
    def build_wala_map(csv_string)
      map = {}
      return map if csv_string.nil? || csv_string.strip.empty?
      content = csv_string.sub("﻿", "")
      table = CSV.parse(content, headers: true, col_sep: ";")
      col = {}
      table.headers.compact.each { |h| col[h.to_s.strip] = h }
      table.each do |row|
        csl = row[col["CSL-Code*"]].to_s.strip
        next if csl.empty? # no group code => not an SL product
        gtin = row[col["EAN-Code"]].to_s.strip.rjust(13, "0")
        next unless gtin =~ /\A\d{13}\z/
        raw_price = row[col["CSL 70.01."]].to_s.strip
        next if raw_price.empty?
        map[gtin] = {
          sl: true,
          price: sprintf("%.2f", raw_price.tr(",", ".").to_f),
          csl: csl,
          abgabe: row[col["KAT"]].to_s.strip
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
