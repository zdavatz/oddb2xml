# frozen_string_literal: true

# fhir_support.rb
# Complete FHIR support module for oddb2xml
# This file provides all FHIR functionality in one place

require "json"
require "date"
require "ostruct"

module Oddb2xml
  # FHIR Downloader - Downloads NDJSON from FOPH/BAG
  class FhirDownloader < Downloader
    include DownloadMethod

    BASE_URL = "https://epl.bag.admin.ch"
    STATIC_FHIR_PATH = "/static/fhir"

    def initialize(options = {})
      @options = options
      @url = find_latest_fhir_url
      super(options, @url)
    end

    def download
      filename = File.basename(@url)
      file = File.join(WORK_DIR, filename)
      @file2save = File.join(DOWNLOADS, filename)

      report_download(@url, @file2save)

      # Check if we should skip download (file exists and is recent)
      if skip_download?
        Oddb2xml.log "FhirDownloader: Skip downloading #{@file2save} (#{format_size(File.size(@file2save))}, less than 24h old)"
        return File.expand_path(@file2save)
      end

      begin
        # Download the file
        download_as(file, "w+")

        # Validate NDJSON format
        if validate_ndjson(@file2save)
          line_count = count_ndjson_lines(@file2save)
          Oddb2xml.log "FhirDownloader: NDJSON validation successful (#{line_count} bundles, #{format_size(File.size(@file2save))})"
        else
          Oddb2xml.log "FhirDownloader: WARNING - NDJSON validation failed!"
        end

        File.expand_path(@file2save)
      rescue Timeout::Error, Errno::ETIMEDOUT
        retrievable? ? retry : raise
      rescue => error
        Oddb2xml.log "FhirDownloader: Error downloading FHIR file: #{error.message}"
        raise
      ensure
        Oddb2xml.download_finished(@file2save, false)
        FileUtils.rm_f(file, verbose: true) if File.exist?(file) && file != @file2save
      end
    end

    private

    def find_latest_fhir_url
      agent = Mechanize.new
      response = agent.get "https://epl.bag.admin.ch/api/sl/public/resources/current"
      resources = JSON.parse(response.body)
      "https://epl.bag.admin.ch/static/" + resources["fhir"]["fileUrl"]
    rescue => e
      Oddb2xml.log "FhirDownloader: Error finding latest URL: #{e.message}"
      nil
    end

    def skip_download?
        @options[:skip_download] || (File.exist?(@file2save) && file_age_hours(@file2save) < 24)
    end

    def file_age_hours(file)
      ((Time.now - File.ctime(file)).to_i / 3600.0).round(1)
    end

    def format_size(bytes)
      if bytes < 1024
        "#{bytes} bytes"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)} KB"
      else
        "#{(bytes / (1024.0 * 1024)).round(1)} MB"
      end
    end

    def validate_ndjson(file)
      # Validate NDJSON format by checking first few lines
      return false unless File.exist?(file)

      begin
        line_count = 0
        valid_count = 0
        error_lines = []

        File.open(file, "r:utf-8") do |f|
          # Check first 10 lines
          10.times do
            line = f.gets
            break if line.nil?

            line_count += 1
            next if line.strip.empty?

            begin
              data = JSON.parse(line)
              # Check if it's a FHIR Bundle
              if data["resourceType"] == "Bundle"
                valid_count += 1
              else
                error_lines << "Line #{line_count}: Not a Bundle (resourceType: #{data["resourceType"]})"
              end
            rescue JSON::ParserError => e
              error_lines << "Line #{line_count}: Invalid JSON - #{e.message}"
            end
          end
        end

        if error_lines.any?
          error_lines.each { |err| Oddb2xml.log "FhirDownloader: #{err}" }
        end

        # Valid if we found at least some valid bundles
        valid_count > 0
      rescue => e
        Oddb2xml.log "FhirDownloader: Validation error: #{e.message}"
        false
      end
    end

    def count_ndjson_lines(file)
      # Count non-empty lines in the NDJSON file
      count = 0
      File.open(file, "r") do |f|
        f.each_line do |line|
          count += 1 unless line.strip.empty?
        end
      end
      count
    rescue => e
      Oddb2xml.log "FhirDownloader: Error counting lines: #{e.message}"
      0
    end
  end

  # FHIR Parser - Parses NDJSON and creates compatible structure
  module FHIR
    # Bundle represents one line in the NDJSON file
    class Bundle
      attr_reader :medicinal_product, :packages, :authorizations, :ingredients

      def initialize(json_line)
        data = JSON.parse(json_line)
        @entries = data["entry"] || []
        parse_entries
      end

      private

      def parse_entries
        @medicinal_product = nil
        @packages = []
        @authorizations = []
        @ingredients = []

        @entries.each do |entry|
          resource = entry["resource"]
          case resource["resourceType"]
          when "MedicinalProductDefinition"
            @medicinal_product = MedicinalProduct.new(resource)
          when "PackagedProductDefinition"
            @packages << Package.new(resource)
          when "RegulatedAuthorization"
            @authorizations << Authorization.new(resource)
          when "Ingredient"
            @ingredients << Ingredient.new(resource)
          end
        end
      end
    end

    class MedicinalProduct
      attr_reader :names, :atc_code, :classification, :it_codes

      def initialize(resource)
        @names = {}
        resource["name"]&.each do |name|
          lang = name.dig("usage", 0, "language", "coding", 0, "code")
          @names[lang] = name["productName"]
        end

        # Get ATC code (classification[0])
        @atc_code = resource.dig("classification", 0, "coding", 0, "code")

        # Get product classification (generic/reference) (classification[1])
        @classification = resource.dig("classification", 1, "coding", 0, "code")
        
        # Get IT codes (Index Therapeuticus) from classification with correct system
        @it_codes = []
        resource["classification"]&.each do |cls|
          cls["coding"]&.each do |coding|
            if coding["system"]&.include?("index-therapeuticus")
              # Format IT code from "080300" to "08.03.00" or "08.03."
              it_code = format_it_code(coding["code"])
              @it_codes << it_code if it_code
            end
          end
        end
      end

      def name_de
        @names["de-CH"] || @names["de"]
      end

      def name_fr
        @names["fr-CH"] || @names["fr"]
      end

      def name_it
        @names["it-CH"] || @names["it"]
      end
      
      def it_code
        # Return first IT code (primary), formatted like "08.03.00"
        @it_codes.first
      end
      
      private
      
      def format_it_code(code)
        return nil unless code && code.match?(/^\d{6}$/)
        
        # Convert "080300" to "08.03.00"
        "#{code[0..1]}.#{code[2..3]}.#{code[4..5]}"
      end
    end

    class Package
      attr_reader :gtin, :description, :swissmedic_no8, :legal_status, :resource_id

      def initialize(resource)
        @resource_id = resource["id"]
        @gtin = resource.dig("packaging", "identifier", 0, "value")
        @description = resource["description"]

        # Extract SwissmedicNo8 from GTIN (last 8 digits)
        if @gtin && @gtin.length >= 8
          @swissmedic_no8 = @gtin[-8..-1]
        end

        @legal_status = resource.dig("legalStatusOfSupply", 0, "code", "coding", 0, "code")
      end
    end

    class Authorization
      attr_reader :identifier, :auth_type, :holder_name, :prices, :foph_dossier_no,
        :status, :listing_status, :subject_reference, :cost_share, :limitations

      def initialize(resource)
        @identifier = resource.dig("identifier", 0, "value")
        @auth_type = resource.dig("type", "coding", 0, "display")
        @holder_name = resource.dig("contained", 0, "name")
        @subject_reference = resource.dig("subject", 0, "reference")
        @prices = []
        @foph_dossier_no = nil
        @status = nil
        @listing_status = nil
        @cost_share = nil
        @limitations = []

        # Parse extensions for reimbursement info and prices
        resource["extension"]&.each do |ext|
          if ext["url"]&.include?("reimbursementSL")
            parse_reimbursement_extension(ext)
          end
        end
        
        # Parse indications for limitations
        parse_indications(resource["indication"])
      end

      def marketing_authorization?
        @auth_type == "Marketing Authorisation"
      end

      def reimbursement_sl?
        @auth_type == "Reimbursement SL"
      end

      private

      def parse_reimbursement_extension(ext)
        ext["extension"]&.each do |sub_ext|
          case sub_ext["url"]
          when "FOPHDossierNumber"
            @foph_dossier_no = sub_ext.dig("valueIdentifier", "value")
          when "status"
            @status = sub_ext.dig("valueCodeableConcept", "coding", 0, "display")
          when "listingStatus"
            @listing_status = sub_ext.dig("valueCodeableConcept", "coding", 0, "display")
          when "costShare"
            @cost_share = sub_ext["valueInteger"]
          else
            # Check if this is a productPrice extension (has nested extensions)
            if sub_ext["url"]&.include?("productPrice")
              @prices << parse_price_extension(sub_ext)
            end
          end
        end
      end

      def parse_price_extension(ext)
        price = {}
        ext["extension"]&.each do |sub_ext|
          case sub_ext["url"]
          when "type"
            price[:type] = sub_ext.dig("valueCodeableConcept", "coding", 0, "code")
          when "value"
            price[:value] = sub_ext.dig("valueMoney", "value")
            price[:currency] = sub_ext.dig("valueMoney", "currency")
          when "changeDate"
            price[:change_date] = sub_ext["valueDate"]
          when "changeType"
            price[:change_type] = sub_ext.dig("valueCodeableConcept", "coding", 0, "display")
          end
        end
        price
      end
      
      def parse_indications(indications)
        return unless indications
        
        indications.each do |indication|
          indication["extension"]&.each do |ext|
            if ext["url"]&.include?("regulatedAuthorization-limitation")
              @limitations << parse_limitation_extension(ext)
            end
          end
        end
      end
      
      def parse_limitation_extension(ext)
        limitation = {}
        ext["extension"]&.each do |sub_ext|
          case sub_ext["url"]
          when "status"
            limitation[:status] = sub_ext.dig("valueCodeableConcept", "coding", 0, "display")
            limitation[:status_code] = sub_ext.dig("valueCodeableConcept", "coding", 0, "code")
          when "statusDate"
            limitation[:status_date] = sub_ext["valueDate"]
          when "limitationText"
            limitation[:text] = sub_ext["valueString"]
          when "period"
            limitation[:start_date] = sub_ext.dig("valuePeriod", "start")
            limitation[:end_date] = sub_ext.dig("valuePeriod", "end")
          when "firstLimitationDate"
            limitation[:first_date] = sub_ext["valueDate"]
          end
        end
        limitation
      end
    end

    class Ingredient
      attr_reader :substance_name, :quantity, :unit

      def initialize(resource)
        @substance_name = resource.dig("substance", "code", "concept", "text")
        strength = resource.dig("substance", "strength", 0)
        @quantity = strength&.dig("presentationQuantity", "value")
        @unit = strength&.dig("presentationQuantity", "unit")

        # Handle textPresentation for ranges like "340-660"
        @text_presentation = strength&.dig("textPresentation")
      end

      def quantity_text
        @text_presentation || (@quantity ? "#{@quantity}" : "")
      end
    end

    # Main parser class that provides compatibility with XML parser
    class PreparationsParser
      attr_reader :preparations

      def initialize(ndjson_file)
        @preparations = []
        parse_file(ndjson_file)
      end

      def parse_file(ndjson_file)
        File.foreach(ndjson_file, encoding: 'UTF-8') do |line|
          next if line.strip.empty?

          bundle = Bundle.new(line)
          next unless bundle.medicinal_product

          # Create a preparation structure compatible with XML parser output
          prep = create_preparation(bundle)
          @preparations << prep if prep
        end
      end

      private

      def create_preparation(bundle)
        mp = bundle.medicinal_product

        # Create preparation hash structure
        prep = OpenStruct.new
        prep.NameDe = mp.name_de
        prep.NameFr = mp.name_fr
        prep.NameIt = mp.name_it
        prep.AtcCode = mp.atc_code
        prep.OrgGenCode = map_org_gen_code(mp.classification)
        prep.ItCode = mp.it_code  # Add IT code

        # Map packages
        prep.Packs = OpenStruct.new
        prep.Packs.Pack = bundle.packages.map do |pkg|
          pack = OpenStruct.new
          pack.GTIN = pkg.gtin
          pack.SwissmedicNo8 = pkg.swissmedic_no8
          pack.DescriptionDe = pkg.description
          pack.DescriptionFr = pkg.description
          pack.DescriptionIt = pkg.description
          pack.SwissmedicCategory = map_legal_status(pkg.legal_status)

          # Find prices and additional data for this package
          pack.Prices = create_prices_for_package(bundle, pkg)
          
          # Add limitations and cost share
          pack.Limitations = create_limitations_for_package(bundle, pkg)
          pack.CostShare = get_cost_share_for_package(bundle, pkg)

          pack
        end

        # Map ingredients
        prep.Substances = OpenStruct.new
        prep.Substances.Substance = bundle.ingredients.map do |ing|
          substance = OpenStruct.new
          substance.DescriptionLa = ing.substance_name
          substance.Quantity = ing.quantity_text
          substance.QuantityUnit = ing.unit
          substance
        end

        # Extract SwissmedicNo5 from the first authorization
        marketing_auth = bundle.authorizations.find(&:marketing_authorization?)
        if marketing_auth
          # SwissmedicNo5 is typically the first 5 digits of the identifier
          prep.SwissmedicNo5 = marketing_auth.identifier&.to_s&.[](0, 5)
        end

        prep
      end

      def create_prices_for_package(bundle, package)
        prices = OpenStruct.new

        # Find reimbursement authorization for this package by resource ID
        # Match by ending with ID to handle both PackagedProductDefinition and CHIDMPPackagedProductDefinition
        reimbursement = bundle.authorizations.find do |auth|
          auth.reimbursement_sl? && auth.subject_reference&.end_with?(package.resource_id)
        end

        return prices unless reimbursement

        reimbursement.prices.each do |price|
          if price[:type] == "756002005002"
            exf = OpenStruct.new
            exf.Price = price[:value]
            exf.ValidFromDate = price[:change_date]
            exf.PriceTypeCode = price[:type]
            prices.ExFactoryPrice = exf
          elsif price[:type] == "756002005001"
            pub = OpenStruct.new
            pub.Price = price[:value]
            pub.ValidFromDate = price[:change_date]
            pub.PriceTypeCode = price[:type]
            prices.PublicPrice = pub
          end
        end

        prices
      end
      
      def create_limitations_for_package(bundle, package)
        # Find reimbursement authorization for this package
        reimbursement = bundle.authorizations.find do |auth|
          auth.reimbursement_sl? && auth.subject_reference&.end_with?(package.resource_id)
        end

        return nil unless reimbursement
        return nil if reimbursement.limitations.empty?
        
        # Convert FHIR limitations to OpenStruct format
        limitations = OpenStruct.new
        limitations.Limitation = reimbursement.limitations.map do |lim|
          limitation = OpenStruct.new
          limitation.LimitationCode = ""  # Not in FHIR
          limitation.LimitationType = ""  # Could derive from status
          limitation.LimitationNiveau = ""  # Not in FHIR
          limitation.LimitationValue = ""  # Not in FHIR
          limitation.DescriptionDe = lim[:text] || ""
          limitation.DescriptionFr = ""  # May need separate language version
          limitation.DescriptionIt = ""  # May need separate language version
          limitation.ValidFromDate = lim[:status_date] || lim[:start_date] || ""
          limitation.ValidThruDate = lim[:end_date] || ""
          limitation
        end
        
        limitations
      end
      
      def get_cost_share_for_package(bundle, package)
        # Find reimbursement authorization for this package
        reimbursement = bundle.authorizations.find do |auth|
          auth.reimbursement_sl? && auth.subject_reference&.end_with?(package.resource_id)
        end

        reimbursement&.cost_share
      end

      def map_org_gen_code(classification)
        return nil unless classification

        case classification
        when "756001003001"
          "G"
        when "756001003002"
          "O"
        else
          nil
        end
      end

      def map_legal_status(status_code)
        return nil unless status_code

        # Map FHIR codes to Swissmedic categories
        case status_code
        when "756005022001"
          "A"
        when "756005022003"
          "B"
        when "756005022005"
          "C"
        when "756005022007"
          "D"
        when "756005022009"
          "E"
        else
          nil
        end
      end
    end
  end

  # FHIR Extractor - Compatible with existing BagXmlExtractor
  class FhirExtractor < Extractor
    def initialize(fhir_file)
      @fhir_file = fhir_file
    end

    def to_hash
      data = {}
      Oddb2xml.log "FhirExtractor: Parsing FHIR file #{@fhir_file}"

      # Parse FHIR NDJSON
      result = FhirPreparationsEntry.parse(@fhir_file)

      result.Preparations.Preparation.each do |seq|
        next unless seq
        next if seq.SwissmedicNo5 && seq.SwissmedicNo5.eql?("0")

        # Build item structure matching BagXmlExtractor
        item = {}
        item[:data_origin] = "fhir"
        item[:refdata] = true
        item[:product_key] = nil  # Not available in FHIR
        item[:desc_de] = ""  # Not in FHIR at product level
        item[:desc_fr] = ""
        item[:desc_it] = ""
        item[:name_de] = (name = seq.NameDe) ? name : ""
        item[:name_fr] = (name = seq.NameFr) ? name : ""
        item[:name_it] = (name = seq.NameIt) ? name : ""
        item[:swissmedic_number5] = (num5 = seq.SwissmedicNo5) ? num5.to_s.rjust(5, "0") : ""
        item[:org_gen_code] = (orgc = seq.OrgGenCode) ? orgc : ""
        item[:deductible] = ""  # Will be set per package based on cost_share
        item[:deductible20] = ""  # Will be set per package based on cost_share  
        item[:atc_code] = (atcc = seq.AtcCode) ? atcc : ""
        item[:comment_de] = ""  # Not available in FHIR
        item[:comment_fr] = ""
        item[:comment_it] = ""
        item[:it_code] = (itc = seq.ItCode) ? itc : ""  # NOW available in FHIR!

        # Build substances array
        item[:substances] = []
        if seq.Substances && seq.Substances.Substance
          seq.Substances.Substance.each_with_index do |sub, i|
            item[:substances] << {
              index: i.to_s,
              name: (name = sub.DescriptionLa) ? name : "",
              quantity: (qtty = sub.Quantity) ? qtty : "",
              unit: (unit = sub.QuantityUnit) ? unit : ""
            }
          end
        end

        item[:pharmacodes] = []
        item[:packages] = {}

        # Process packages
        if seq.Packs && seq.Packs.Pack
          seq.Packs.Pack.each do |pac|
            next unless pac.GTIN

            ean13 = pac.GTIN.to_s

            # Ensure SwissmedicNo8 has leading zeros
            if pac.SwissmedicNo8 && pac.SwissmedicNo8.length < 8
              pac.SwissmedicNo8 = pac.SwissmedicNo8.rjust(8, "0")
            end

            Oddb2xml.setEan13forNo8(pac.SwissmedicNo8, ean13) if pac.SwissmedicNo8

            # Build price structures
            exf = {price: "", valid_date: "", price_code: ""}
            if pac.Prices && pac.Prices.ExFactoryPrice
              exf[:price] = pac.Prices.ExFactoryPrice.Price.to_s if pac.Prices.ExFactoryPrice.Price
              exf[:valid_date] = pac.Prices.ExFactoryPrice.ValidFromDate if pac.Prices.ExFactoryPrice.ValidFromDate
              exf[:price_code] = "PEXF"
            end

            pub = {price: "", valid_date: "", price_code: ""}
            if pac.Prices && pac.Prices.PublicPrice
              pub[:price] = pac.Prices.PublicPrice.Price.to_s if pac.Prices.PublicPrice.Price
              pub[:valid_date] = pac.Prices.PublicPrice.ValidFromDate if pac.Prices.PublicPrice.ValidFromDate
              pub[:price_code] = "PPUB"
            end

            # Build package entry matching BagXmlExtractor structure
            item[:packages][ean13] = {
              ean13: ean13,
              name_de: (name = seq.NameDe) ? name : "",
              name_fr: (name = seq.NameFr) ? name : "",
              name_it: (name = seq.NameIt) ? name : "",
              desc_de: (desc = pac.DescriptionDe) ? desc : "",
              desc_fr: (desc = pac.DescriptionFr) ? desc : "",
              desc_it: (desc = pac.DescriptionIt) ? desc : "",
              sl_entry: true,
              swissmedic_category: (cat = pac.SwissmedicCategory) ? cat : "",
              swissmedic_number8: (num = pac.SwissmedicNo8) ? num : "",
              prices: {exf_price: exf, pub_price: pub}
            }

            # Map limitations from FHIR
            item[:packages][ean13][:limitations] = []
            if pac.Limitations && pac.Limitations.Limitation
              pac.Limitations.Limitation.each do |lim|
                # Calculate is_deleted safely
                is_deleted = false
                if lim.ValidThruDate
                  begin
                    is_deleted = Date.parse(lim.ValidThruDate) < Date.today
                  rescue
                    is_deleted = false
                  end
                end
                
                item[:packages][ean13][:limitations] << {
                  it: item[:it_code],
                  key: :swissmedic_number8,
                  id: pac.SwissmedicNo8 || "",
                  code: lim.LimitationCode || "",
                  type: lim.LimitationType || "",
                  value: lim.LimitationValue || "",
                  niv: lim.LimitationNiveau || "",
                  desc_de: lim.DescriptionDe || "",
                  desc_fr: lim.DescriptionFr || "",
                  desc_it: lim.DescriptionIt || "",
                  vdate: lim.ValidFromDate || "",
                  del: is_deleted
                }
              end
            end
            item[:packages][ean13][:limitation_points] = ""
            
            # Map cost_share to deductible flags
            if pac.CostShare
              case pac.CostShare
              when 10
                item[:deductible] = "Y"
              when 20
                item[:deductible20] = "Y"
              when 40
                # New value - might need new field or special handling
                item[:deductible] = "Y"  # Fallback to standard deductible
              end
            end

            # Store in data hash with ean13 as key
            data[ean13] = item
          end
        end
      end

      Oddb2xml.log "FhirExtractor: Extracted #{data.size} packages"
      data
    end
  end
end

# Compatibility layer - makes FHIR parser compatible with existing XML parser usage
class FhirPreparationsEntry
  attr_reader :Preparations

  def self.parse(ndjson_file)
    parser = Oddb2xml::FHIR::PreparationsParser.new(ndjson_file)
    entry = new
    entry.Preparations = OpenStruct.new
    entry.Preparations.Preparation = parser.preparations
    entry
  end

  attr_writer :Preparations
end

# Extend PreparationsEntry to handle both XML and FHIR
class PreparationsEntry
  class << self
    alias_method :original_parse, :parse

    def parse(input)
      # Check if input is a file path ending in .ndjson
      if input.is_a?(String) && File.exist?(input) && input.end_with?(".ndjson")
        # Parse as FHIR
        FhirPreparationsEntry.parse(input)
      else
        # Parse as XML (original behavior)
        original_parse(input)
      end
    end
  end
end
