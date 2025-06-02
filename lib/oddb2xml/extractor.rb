require "nokogiri"
require "spreadsheet"
require "stringio"
require "rubyXL"
require "rubyXL/convenience_methods/workbook"
require "csv"
require "oddb2xml/xml_definitions"

module Oddb2xml
  module TxtExtractorMethods
    def initialize(str)
      Oddb2xml.log("TxtExtractorMethods #{str} #{str.to_s.size} bytes")
      @io = StringIO.new(str)
    end

    def to_hash
      data = {}
      while (line = @io.gets)
        next unless /\d{13}/.match?(line)
        ean13 = line.chomp.delete("\"")
        data[ean13] = true
      end
      data
    end
  end

  class Extractor
    attr_accessor :xml
    def initialize(xml)
      Oddb2xml.log("Extractor #{xml} xml #{xml.size} bytes")
      @xml = xml
    end
  end

  class LppvExtractor < Extractor
    include TxtExtractorMethods
  end

  class BagXmlExtractor < Extractor
    def to_hash
      data = {}
      result = PreparationsEntry.parse(@xml.sub(STRIP_FOR_SAX_MACHINE, ""), lazy: true)
      result.Preparations.Preparation.each do |seq|
        if seq.SwissmedicNo5.eql?("0")
          puts "BagXmlExtractor Skipping SwissmedicNo5 0 for #{seq.NameDe} #{seq.DescriptionDe} #{seq.CommentDe}"
          next
        end
        item = {}
        item[:data_origin] = "bag_xml"
        item[:refdata] = true
        item[:product_key] = seq.ProductCommercial
        item[:desc_de] = (desc = seq.DescriptionDe) ? desc : ""
        item[:desc_fr] = (desc = seq.DescriptionFr) ? desc : ""
        item[:desc_it] = (desc = seq.DescriptionIt) ? desc : ""
        item[:name_de] = (name = seq.NameDe) ? name : ""
        item[:name_fr] = (name = seq.NameFr) ? name : ""
        item[:name_it] = (name = seq.NameIt) ? name : ""
        item[:swissmedic_number5] = (num5 = seq.SwissmedicNo5) ? num5.rjust(5, "0") : ""
        item[:org_gen_code] = (orgc = seq.OrgGenCode) ? orgc : ""
        item[:deductible] = (ddbl = seq.FlagSB) ? ddbl : ""
        item[:deductible20] = (ddbl20 = seq.FlagSB20) ? ddbl20 : ""
        item[:atc_code] = (atcc = seq.AtcCode) ? atcc : ""
        item[:comment_de] = (info = seq.CommentDe) ? info : ""
        item[:comment_fr] = (info = seq.CommentFr) ? info : ""
        item[:comment_it] = (info = seq.CommentIt) ? info : ""
        item[:it_code] = ""
        seq.ItCodes.ItCode.each do |itc|
          if item[:it_code].to_s.empty?
            it_code = itc.Code.to_s
            item[:it_code] = /(\d+)\.(\d+)\.(\d+)./.match?(it_code) ? it_code : ""
          end
        end
        item[:substances] = []
        seq.Substances.Substance.each_with_index do |sub, i|
          item[:substances] << {
            index: i.to_s,
            name: (name = sub.DescriptionLa) ? name : "",
            quantity: (qtty = sub.Quantity) ? qtty : "",
            unit: (unit = sub.QuantityUnit) ? unit : ""
          }
        end
        item[:pharmacodes] = []
        item[:packages] = {} # pharmacode => package
        seq.Packs.Pack.each do |pac|
          if pac.SwissmedicNo8 && pac.SwissmedicNo8.length < 8
            puts "BagXmlExtractor: Adding leading zeros for SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}" if $VERBOSE
            pac.SwissmedicNo8 = pac.SwissmedicNo8.rjust(8, "0")
          end
          unless pac.GTIN
            if pac.SwissmedicNo8
              ean12 = "7680" + pac.SwissmedicNo8
              pac.GTIN = (ean12 + Oddb2xml.calc_checksum(ean12)) unless @artikelstamm
              # puts "BagXmlExtractor: Missing GTIN in SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}."
            else
              puts "BagXmlExtractor: Missing GTIN and SwissmedicNo8 in SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}"
              next
            end
          end
          ean13 = pac.GTIN.to_s
          Oddb2xml.setEan13forNo8(pac.SwissmedicNo8, ean13) if pac.SwissmedicNo8
          # packages
          exf = {price: "", valid_date: "", price_code: ""}
          if pac&.Prices&.ExFactoryPrice
            exf[:price] = pac.Prices.ExFactoryPrice.Price if pac.Prices.ExFactoryPrice.Price
            exf[:valid_date] = pac.Prices.ExFactoryPrice.ValidFromDate if pac.Prices.ExFactoryPrice.ValidFromDate
            exf[:price_code] = pac.Prices.ExFactoryPrice.PriceTypeCode if pac.Prices.ExFactoryPrice.PriceTypeCode
          end
          pub = {price: "", valid_date: "", price_code: ""}
          if pac&.Prices&.PublicPrice
            pub[:price] = pac.Prices.PublicPrice.Price if pac.Prices.PublicPrice.Price
            pub[:valid_date] = pac.Prices.PublicPrice.ValidFromDate if pac.Prices.PublicPrice.ValidFromDate
            pub[:price_code] = pac.Prices.PublicPrice.PriceTypeCode if pac.Prices.PublicPrice.PriceTypeCode
          end
          item[:packages][ean13] = {
            ean13: ean13,
            name_de: (desc = seq.NameDe) ? desc : "",
            name_fr: (desc = seq.NameFr) ? desc : "",
            name_it: (desc = seq.NameIt) ? desc : "",
            desc_de: (desc = pac.DescriptionDe) ? desc : "",
            desc_fr: (desc = pac.DescriptionFr) ? desc : "",
            desc_it: (desc = pac.DescriptionIt) ? desc : "",
            sl_entry: true,
            swissmedic_category: (cat = pac.SwissmedicCategory) ? cat : "",
            swissmedic_number8: (num = pac.SwissmedicNo8) ? num : "",
            prices: {exf_price: exf, pub_price: pub}
          }
          # related all limitations
          item[:packages][ean13][:limitations] = []
          limitations = Hash.new { |h, k| h[k] = [] }
          limitations[:seq] = if seq.Limitations
            seq.Limitations.Limitation.collect { |x| x }
          end
          # in it-codes
          if seq&.ItCodes && seq&.ItCodes&.ItCode
            limitations[:itc] = []
            seq.ItCodes.ItCode.each { |x| limitations[:itc] += x.Limitations.Limitation if x.Limitations.Limitation }
          else
            limitations[:itc] = nil
          end
          # in pac
          limitations[:pac] = if pac && pac.Limitations
            (lims = pac.Limitations.Limitation) ? lims.to_a : nil
          end
          limitations.each_pair do |lim_key, lims|
            key = ""
            id = ""
            case lim_key
            when :seq, :itc
              key = :swissmedic_number5
              id = item[key].to_s
            when :pac
              key = :swissmedic_number8
              id = item[:packages][ean13][key].to_s
            end
            if id.empty? && item[:packages][ean13][:swissmedic_number8]
              key = :swissmedic_number8
              id = item[:packages][ean13][key].to_s
            end
            lims&.each do |lim|
              limitation = {
                it: item[:it_code],
                key: key,
                id: id,
                code: (lic = lim.LimitationCode) ? lic : "",
                type: (lit = lim.LimitationType) ? lit : "",
                value: (liv = lim.LimitationValue) ? liv : "",
                niv: (niv = lim.LimitationNiveau) ? niv : "",
                desc_de: (dsc = lim.DescriptionDe) ? dsc : "",
                desc_fr: (dsc = lim.DescriptionFr) ? dsc : "",
                desc_it: (dsc = lim.DescriptionIt) ? dsc : "",
                vdate: (dat = lim.ValidFromDate) ? dat : ""
              }
              deleted = false
              if (upto = ((thr = lim.ValidThruDate) ? thr : nil)) &&
                  upto =~ (/\d{2}\.\d{2}\.\d{2}/)
                begin
                  deleted = true if Date.strptime(upto, "%d.%m.%y") >= Date.today
                rescue ArgumentError
                end
              end
              limitation[:del] = deleted
              item[:packages][ean13][:limitations] << limitation
            end
          end
          # limitation points
          pts = pac.PointLimitations.PointLimitation.first # only first points
          item[:packages][ean13][:limitation_points] = pts ? pts.Points : ""
          if pac.SwissmedicNo8
            ean12 = "7680" + pac.SwissmedicNo8
            correct_ean13 = ean12 + Oddb2xml.calc_checksum(ean12)
            unless pac.GTIN.eql?(correct_ean13)
              puts "pac.GTIN #{pac.GTIN} should be #{correct_ean13}"
              item[:packages][ean13][:CORRECT_EAN13] = correct_ean13
            end
          end
          data[ean13] = item
        end
      end
      data
    end
  end

  class RefdataExtractor < Extractor
    def initialize(xml, type)
      @type = (type == :pharma ? "PHARMA" : "NONPHARMA")
      super(xml)
    end

    def to_hash
      data = {}
      result = SwissRegArticles.parse(@xml.sub(STRIP_FOR_SAX_MACHINE, ""), lazy: true)
      result.Article.each do |article|
        article_type = article.MedicinalProduct.ProductClassification.ProductClass
        if article_type != @type
          next
        end
        ean13 = @type == "PHARMA" ? article.PackagedProduct.DataCarrierIdentifier : article.MedicinalProduct.Identifier
        if ean13.size < 13
          puts "Refdata #{@type} use 13 chars not #{ean13.size} for #{ean13}" if $VERBOSE
          ean13 = ean13.rjust(13, "0")
        end
        if ean13.size == 14 && ean13[0] == "0"
          puts "Refdata #{@type} remove leading '0' for #{ean13}" if $VERBOSE
          ean13 = ean13[1..-1]
        end
        item = {}
        item[:ean13] = ean13
        item[:no8] = article.PackagedProduct.RegulatedAuthorisationIdentifier || ""
        item[:data_origin] = "refdata"
        item[:refdata] = true
        item[:_type] = @type.downcase.to_sym
        item[:last_change] = "" # TODO: Date and time of last data change
        item[:desc_de] = ""
        item[:desc_fr] = ""
        item[:desc_it] = ""
        article.PackagedProduct.Name.each do |name|
          if name.Language == "DE"
            item[:desc_de] = name.FullName
          elsif name.Language == "FR"
            item[:desc_fr] = name.FullName
          elsif name.Language == "IT"
            item[:desc_it] = name.FullName
          end
        end
        item[:atc_code] = article.MedicinalProduct.ProductClassification.Atc || ""
        item[:company_name] = article.PackagedProduct.Holder.Name || ""
        item[:company_ean] = article.PackagedProduct.Holder.Identifier || ""
        data[ean13] = item
      end
      data
    end
  end

  class SwissmedicExtractor < Extractor
    def initialize(filename, type)
      @filename = File.join(DOWNLOADS, File.basename(filename))
      @filename = File.join(SpecData, File.basename(filename)) if defined?(RSpec) && !File.exist?(@filename)
      @type = type
      Oddb2xml.log("SwissmedicExtractor #{@filename} #{File.size(@filename)} bytes")
      return unless File.exist?(@filename)
      @sheet = RubyXL::Parser.parse(File.expand_path(@filename)).worksheets[0]
    end

    def to_arry
      data = []
      return data unless @sheet
      case @type
      when :orphan
        col_zulassung = 6
        raise "Could not find Zulassungsnummer in column #{col_zulassung} of #{@filename}" unless /Zulassungs.*nummer/.match?(@sheet[3][col_zulassung].value)
        @sheet.each do |row|
          next unless row[col_zulassung]
          number = row[col_zulassung].value.to_i
          if number != 0
            data << sprintf("%05d", number)
          end
        end
      end
      # puts "found #{data.uniq.size} entities for type #{@type}"
      data.uniq
    end

    # Packungen.xlsx COLUMNS_FEBRUARY_2019
    def to_hash
      data = {}
      return data unless @sheet
      case @type
      when :package
        Oddb2xml.check_column_indices(@sheet)
        ith = COLUMNS_FEBRUARY_2019.keys.index(:index_therapeuticus)
        iksnr = COLUMNS_FEBRUARY_2019.keys.index(:iksnr)
        seq_name = COLUMNS_FEBRUARY_2019.keys.index(:name_base)
        i_3 = COLUMNS_FEBRUARY_2019.keys.index(:ikscd)
        seqnr = COLUMNS_FEBRUARY_2019.keys.index(:seqnr)
        cat = COLUMNS_FEBRUARY_2019.keys.index(:ikscat)
        siz = COLUMNS_FEBRUARY_2019.keys.index(:size)
        atc = COLUMNS_FEBRUARY_2019.keys.index(:atc_class)
        list_code = COLUMNS_FEBRUARY_2019.keys.index(:production_science)
        eht = COLUMNS_FEBRUARY_2019.keys.index(:unit)
        sub = COLUMNS_FEBRUARY_2019.keys.index(:substances)
        comp = COLUMNS_FEBRUARY_2019.keys.index(:composition)

        # production_science Heilmittelcode, possible values are
        # Allergene
        # Anthroposophika
        # ayurvedische Arzneimittel
        # Bakterien- und Hefepräparate
        # Biotechnologika
        # Blutprodukte
        # Generator
        # Heilmittelcode
        # Homöopathika
        # Impfstoffe
        # Phytotherapeutika
        # Radiopharmazeutika
        # Synthetika human
        # tibetische Arzneimittel
        # Tierarzneimittel
        # Transplantat: Gewebeprodukt
        @sheet.each_with_index do |row, i|
          next if i <= 1
          next unless row && row[iksnr] && row[i_3]
          next unless (row[iksnr].value.to_i > 0) && (row[i_3].value.to_i > 0)
          no8 = sprintf("%05d", row[iksnr].value.to_i) + sprintf("%03d", row[i_3].value.to_i)
          unless no8.empty?
            next if no8.to_i == 0
            ean_base12 = "7680#{no8}"
            prodno = Oddb2xml.gen_prodno(row[iksnr].value.to_i, row[seqnr].value.to_i)
            ean13 = (ean_base12.ljust(12, "0") + Oddb2xml.calc_checksum(ean_base12))
            Oddb2xml.setEan13forProdno(prodno, ean13)
            Oddb2xml.setEan13forNo8(no8, ean13)
            data[no8] = {
              iksnr: row[iksnr].value.to_i,
              no8: no8,
              ean13: ean13,
              prodno: prodno,
              seqnr: row[seqnr].value,
              ith_swissmedic: row[ith] ? row[ith].value.to_s : "",
              swissmedic_category: row[cat].value.to_s,
              atc_code: row[atc] ? Oddb2xml.add_epha_changes_for_ATC(row[iksnr].value.to_s, row[atc].value.to_s) : "",
              list_code: row[list_code] ? row[list_code].value.to_s : "",
              package_size: row[siz] ? row[siz].value.to_s : "",
              einheit_swissmedic: row[eht] ? row[eht].value.to_s : "",
              substance_swissmedic: row[sub] ? row[sub].value.to_s : "",
              composition_swissmedic: row[comp] ? row[comp].value.to_s : "",
              sequence_name: row[seq_name] ? row[seq_name].value.to_s : "",
              is_tier: (row[list_code] == "Tierarzneimittel"),
              gen_production: row[COLUMNS_FEBRUARY_2019.keys.index(:gen_production)].value.to_s,
              insulin_category: row[COLUMNS_FEBRUARY_2019.keys.index(:insulin_category)].value.to_s,
              drug_index: row[COLUMNS_FEBRUARY_2019.keys.index(:drug_index)].value.to_s,
              data_origin: "swissmedic_package",
              expiry_date: row[COLUMNS_FEBRUARY_2019.keys.index(:expiry_date)].value.to_s,
              company_name: row[COLUMNS_FEBRUARY_2019.keys.index(:company)].value.to_s,
              size: row[COLUMNS_FEBRUARY_2019.keys.index(:size)].value.to_s,
              unit: row[COLUMNS_FEBRUARY_2019.keys.index(:unit)].value.to_s
            }
          end
        end
      end
      data
    end
  end

  class MigelExtractor < Extractor
    def initialize(bin)
      Oddb2xml.log("MigelExtractor #{io} #{File.size(io)} bytes")
      book = Spreadsheet.open(io, "rb")
      @sheet = book.worksheet(0)
    end

    def to_hash
      data = {}
      @sheet.each_with_index do |row, i|
        next if i.zero?
        phar = row[1]
        next if phar == 0
        ean13 = row[0]
        ean13 = phar unless ean13.to_s.length == 13
        data[ean] = {
          refdata: true,
          ean13: ean13,
          pharmacode: phar,
          desc_de: row[3],
          desc_fr: row[4],
          quantity: row[5], # quantity
          company_name: row[6],
          company_ean: row[7],
          data_origin: "migel"
        }
        data
      end
      data
    end
  end

  class SwissmedicInfoExtractor < Extractor
    def to_hash
      data = Hash.new { |h, k| h[k] = [] }
      return data unless @xml.size > 0
      result = MedicalInformationsContent.parse(@xml.sub(STRIP_FOR_SAX_MACHINE, ""), lazy: true)
      result.medicalInformation.each do |pac|
        lang = pac.lang.to_s
        next unless /de|fr/.match?(lang)
        item = {}
        item[:refdata] = true
        item[:data_origin] = "swissmedic_info"
        item[:name] = (name = pac.title) ? name : ""
        item[:owner] = (ownr = pac.authHolder) ? ownr : ""
        item[:style] = Nokogiri::HTML.fragment(pac.style).to_html(encoding: "UTF-8")
        html = Nokogiri::HTML.fragment(pac.content.force_encoding("UTF-8"))
        item[:paragraph] = html
        numbers = /(\d{5})[,\s]*(\d{5})?|(\d{5})[,\s]*(\d{5})?[,\s]*(\d{5})?/.match(html)
        if numbers
          [$1, $2, $3].compact.each do |n| # plural
            item[:monid] = n
            data[lang] << item
          end
        end
      end
      data
    end
  end

  class EphaExtractor < Extractor
    def initialize(str)
      Oddb2xml.log("EphaExtractor #{str.size} bytes")
      @io = StringIO.new(str)
    end

    def to_arry
      data = []
      ixno = 0
      inhalt = @io.read
      inhalt.split("\n").each do |line|
        ixno += 1
        next if /ATC1.*Name1.*ATC2.*Name2/.match?(line)
        # line = '"'+line unless /^"/.match(line)
        begin
          row = CSV.parse_line(line.gsub('""', '"'))
          action = {}
          next unless row.size > 8
          action[:data_origin] = "epha"
          action[:ixno] = ixno
          action[:title] = row[4]
          action[:atc1] = row[0]
          action[:atc2] = row[2]
          action[:mechanism] = row[5]
          action[:effect] = row[6]
          action[:measures] = row[7]
          action[:grad] = row[8]
          data << action
        rescue CSV::MalformedCSVError
          puts "CSV::MalformedCSVError in line #{ixno}: #{line}"
        end
      end
      data
    end
  end

  class MedregbmExtractor < Extractor
    def initialize(str, type)
      @io = StringIO.new(str)
      @type = type
    end

    def to_arry
      data = []
      case @type
      when :company
        while (line = @io.gets)
          row = line.chomp.split("\t")
          next if /^GLN/.match?(row[0])
          data << {
            data_origin: "medreg",
            gln: row[0].to_s.gsub(/[^0-9]/, ""), #=> GLN Betrieb
            name_1: row[1].to_s, #=> Betriebsname 1
            name_2: row[2].to_s, #=> Betriebsname 2
            address: row[3].to_s, #=> Strasse
            number: row[4].to_s, #=> Nummer
            post: row[5].to_s, #=> PLZ
            place: row[6].to_s, #=> Ort
            region: row[7].to_s, #=> Bewilligungskanton
            country: row[8].to_s, #=> Land
            type: row[9].to_s, #=> Betriebstyp
            authorization: row[10].to_s #=> BTM Berechtigung
          }
        end
      when :person
        while (line = @io.gets)
          row = line.chomp.split("\t")
          next if /^GLN/.match?(row[0])
          data << {
            data_origin: "medreg",
            gln: row[0].to_s.gsub(/[^0-9]/, ""), #=> GLN Person
            last_name: row[1].to_s, #=> Name
            first_name: row[2].to_s, #=> Vorname
            post: row[3].to_s, #=> PLZ
            place: row[4].to_s, #=> Ort
            region: row[5].to_s, #=> Bewilligungskanton
            country: row[6].to_s, #=> Land
            license: row[7].to_s, #=> Bewilligung Selbstdispensation
            certificate: row[8].to_s, #=> Diplom
            authorization: row[9].to_s #=> BTM Berechtigung
          }
        end
      end
      data
    end
  end

  class ZurroseExtractor < Extractor
    # see http://dev.ywesee.com/Bbmb/TransferDat
    def initialize(dat, extended = false, artikelstamm = false)
      @@extended = extended
      @artikelstamm = artikelstamm
      FileUtils.makedirs(WORK_DIR)
      @@error_file ||= File.open(File.join(WORK_DIR, "duplicate_ean13_from_zur_rose.txt"), "wb+:ISO-8859-14")
      @@items_without_ean13s ||= 0
      @@duplicated_ean13s ||= 0
      @@zur_rose_items ||= 0
      if dat
        @io = if File.exist?(dat)
          File.open(dat, "rb:ISO-8859-14")
        else
          StringIO.new(dat)
        end
        @io
      end
    end

    def to_hash
      data = {}
      if @io
        while (line = @io.gets)
          ean13 = "-1"
          line = Oddb2xml.patch_some_utf8(line).chomp
          # next unless /(7680\d{9})(\d{1})$/.match(line) # Skip non pharma
          next if /(ad us\.* vet)|(\(vet\))/i.match?(line)
          if @@extended
            next unless (match_data = line.match(/(\d{13})(\d{1})$/))
          else
            next unless (match_data = line.match(/(7680\d{9})(\d{1})$/))
          end
          pharma_code = line[3..9]
          if match_data[1].to_s == "0000000000000"
            @@items_without_ean13s += 1
            next if @artikelstamm && pharma_code.to_i == 0
            ean13 = Oddb2xml::FAKE_GTIN_START + pharma_code.to_s unless @artikelstamm
          else
            ean13 = match_data[1]
          end
          if data[ean13]
            @@error_file.puts "Duplicate ean13 #{ean13} in line \nact: #{line.chomp}\norg: #{data[ean13][:line]}"
            @@items_without_ean13s -= 1
            @@duplicated_ean13s += 1
            next
          end

          pexf = sprintf("%.2f", line[60, 6].gsub(/(\d{2})$/, '.\1').to_f)
          ppub = sprintf("%.2f", line[66, 6].gsub(/(\d{2})$/, '.\1').to_f)
          next if @artikelstamm && /^113/.match(line) && ppub.eql?("0.0") && pexf.eql?("0.0")
          next unless ean13
          key = ean13
          key = (Oddb2xml::FAKE_GTIN_START + pharma_code.to_s) if ean13.to_i <= 0 # dummy ean13
          data[key] = {
            data_origin: "zur_rose",
            line: line.chomp,
            ean13: ean13,
            clag: line[73],
            vat: line[96],
            description: line[10..59].sub(/\s+$/, ""),
            quantity: "",
            pharmacode: pharma_code,
            price: pexf,
            pub_price: ppub,
            type: :nonpharma,
            cmut: line[2]
          }
          @@zur_rose_items += 1
        end
      end
      if defined?(@@extended) && @@extended
        @@error_file.puts get_error_msg
      end
      @@error_file.close
      @@error_file = nil
      data
    end
    if defined?(@@extended) && @@extended
      at_exit do
        puts get_error_msg
      end
    end

    private

    def get_error_msg
      if defined?(@@extended) && @@extended
        msg = "Added #{@@items_without_ean13s} via pharmacodes of #{@@zur_rose_items} items when extracting the transfer.dat from \"Zur Rose\""
        msg += "\n  found #{@@duplicated_ean13s} lines with duplicated ean13" if @@duplicated_ean13s > 0
        return msg
      end
      nil
    end
  end

  class FirstbaseExtractor < Extractor
    def initialize(file)
      @sheet = RubyXL::Parser.parse(file).worksheets[0]
    end

    def to_hash
      data = {}
      return data unless @sheet
      @sheet.each_with_index do |row, i|
        next if i <= 1
        if row.nil?
          puts "Empty row (#{i}) in firstbase"
          next
        end
        gtin = row[0].value.to_s.gsub(/^0+/, '')
        data[gtin] = {
          gtin: gtin,
          gln: row[1].value.to_s,
          target_market: row[2] ? row[2].value.to_s: "",
          gpc: row[3] ? row[3].value.to_s: "",
          trade_item_description_de: row[4] ? row[4].value.to_s: "",
          trade_item_description_en: row[5] ? row[5].value.to_s: "",
          trade_item_description_fr: row[6] ? row[6].value.to_s: "",
          trade_item_description_it: row[7] ? row[7].value.to_s: "",
          manufacturer_name: row[8] ? row[8].value.to_s: "",
          start_availability_date: row[9] ? row[9].value.to_s: "",
          gross_weight: row[10] ? row[10].value.to_s: "",
          net_weight: row[11] ? row[11].value.to_s: "",
        }
      end
      data
    end
  end
end
