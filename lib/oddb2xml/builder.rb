require "nokogiri"
require "oddb2xml/util"
require "oddb2xml/calc"
require "csv"

class Numeric
  # round a given number to the nearest step
  def round_by(increment)
    (self / increment).round * increment
  end
end

module Nokogiri
  module XML
    class Document < Nokogiri::XML::Node
      attr_writer :tag_suffix
      alias_method :create_element_origin, :create_element
      def create_element name, *args, &block
        name += (@tag_suffix || "")
        create_element_origin(name, *args, &block)
      end
    end
  end
end

module Oddb2xml
  XML_OPTIONS = {
    "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
    "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
    "xmlns" => "http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration",
    "CREATION_DATETIME" => Time.new.strftime("%FT%T%z"),
    "PROD_DATE" => Time.new.strftime("%FT%T%z"),
    "VALID_DATE" => Time.new.strftime("%FT%T%z"),
    "GENERATED_BY" => "oddb2xml #{VERSION}"
  }
  class Builder
    Data_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data"))
    @@article_overrides = YAML.load_file(File.join(Data_dir, "article_overrides.yaml"))
    @@product_overrides = YAML.load_file(File.join(Data_dir, "product_overrides.yaml"))
    @@ignore_file = File.join(Data_dir, "gtin2ignore.yaml")
    @@gtin2ignore = YAML.load_file(@@ignore_file) if File.exist?(@@ignore_file)
    @@gtin2ignore ||= []
    attr_accessor :subject, :refdata, :items, :flags, :lppvs,
      :actions, :migel, :orphan,
      :infos, :packs, :infos_zur_rose,
      :ean14, :tag_suffix,
      :companies, :people,
      :xsd
    def initialize(args = {})
      @options = args
      @subject = nil
      @refdata = {}
      @items = {} # Spezailitäteniste: SL-Items from Preparations.xml in BAG, using GTINS as key
      @flags = {}
      @lppvs = {}
      @infos = {}
      @packs = {}
      @migel = {}
      @infos_zur_rose ||= {}
      @actions = []
      @orphan = []
      @ean14 = false
      @companies = []
      @people = []
      @tag_suffix = nil
      @pharmacode = {} # index pharmacode => item
      if block_given?
        yield self
      end
    end

    def to_xml(subject = nil)
      Oddb2xml.log "to_xml subject #{subject || @subject}"
      if subject
        send("build_" + subject.to_s)
      elsif @subject
        send("build_" + @subject.to_s)
      end
    end

    def to_dat(subject = nil)
      Oddb2xml.log "to_dat subject #{subject ? subject.to_s : @subject.to_s} for #{self.class}"
      if subject
        send("build_" + subject.to_s)
      elsif @subject
        send("build_" + @subject.to_s)
      end
    end

    private_class_method

    def prepare_articles(reset = false)
      @articles = nil if reset
      unless @articles
        Oddb2xml.log("prepare_articles starting with #{@articles ? @articles.size : "no"} articles.")
        @articles = []
        @refdata.each do |ean13, obj|
          unless SKIP_MIGEL_DOWNLOADER
            if @migel[ean13]
              # delete duplicates
              @migel[ean13] = nil
            end
          end
          if (seq = @items[obj[:ean13]])
            obj[:seq] = seq.clone
          end
          @articles << obj
          @pharmacode[obj[:pharmacode]] = obj
        end
        # add
        unless SKIP_MIGEL_DOWNLOADER
          @migel.values.compact.each do |migel|
            next unless migel[:pharmacode]
            entry = {
              ean13: migel[:ean13],
              pharmacode: migel[:pharmacode],
              stat_date: "",
              desc_de: migel[:desc_de],
              desc_fr: migel[:desc_fr],
              atc_code: "",
              quantity: migel[:quantity],
              company_ean: migel[:company_ean],
              company_name: migel[:company_name],
              migel: true
            }
            @articles << entry
          end
        end
        nr_added = 0
        if @options[:extended] || @options[:artikelstamm]
          Oddb2xml.log("prepare_articles extended prepare_local_index having already #{@articles.size} articles")
          nr_items = 0
          @infos_zur_rose.each do |ean13, info|
            nr_items += 1
            pharmacode = info[:pharmacode]
            if @pharmacode[pharmacode]
              @pharmacode[pharmacode][:price] = info[:price]
              @pharmacode[pharmacode][:pub_price] = info[:pub_price]
              next
            end
            obj = {}
            found = false
            existing = @refdata[ean13]
            if existing
              found = true
              existing[:price] = info[:price]
              existing[:pub_price] = info[:pub_price]
            else
              entry = {
                desc: info[:description],
                desc_de: info[:description],
                status: info[:status] == "3" ? "I" : "A", # from ZurRose, we got 1,2 or 3 means aktive, aka available in trade
                atc_code: "",
                ean13: ean13,
                pharmacode: pharmacode,
                price: info[:price],
                pub_price: info[:pub_price],
                type: info[:type]
              }
              if pharmacode
                @refdata[pharmacode] = entry
              else
                @refdata[ean13] = entry
              end
              obj = entry
            end
            if !found && (obj.size > 0)
              @articles << obj unless @options[:artikelstamm]
              nr_added += 1
            end
          end
        end
      end
      Oddb2xml.log("prepare_articles done. Added #{nr_added} prices. Total #{@articles.size}")
    end

    def prepare_substances
      unless @substances
        Oddb2xml.log("prepare_substances from #{@items.size} items")
        @substances = []
        @items.values.uniq.each do |seq|
          next unless seq[:substances]
          seq[:substances].each do |sub|
            @substances << sub[:name]
          end
        end
        @substances.uniq!
        @substances.sort!
        Oddb2xml.log("prepare_substances done. Total #{@substances.size} from #{@items.size} items")
        exit 2 if (@options[:extended] || @options[:artikelstamm]) && (@substances.size == 0)
      end
    end

    def prepare_limitations
      unless @limitations
        Oddb2xml.log("prepare_limitations from #{@items.size} items")
        limitations = []
        @items.values.uniq.each do |seq|
          next unless seq[:packages]
          seq[:packages].each_value do |pac|
            limitations += pac[:limitations]
          end
        end
        # ID is no longer fixed TAG (swissmedicNo8, swissmedicNo5, pharmacode)
        # limitation.xml needs all duplicate entries by this keys.
        limitations.uniq! { |lim| lim[:id].to_s + lim[:code] + lim[:type] }
        @limitations = limitations.sort_by { |lim| lim[:code] }
        Oddb2xml.log("prepare_limitations done. Total #{@limitations.size} from #{@items.size} items")
      end
    end

    def prepare_interactions
      unless @interactions
        @interactions = []
        @actions.each do |act|
          @interactions << act
        end
      end
    end

    def prepare_codes
      @codes ||= {
        "X" => {int: 11, txt: "Kontraindiziert"},
        "D" => {int: 13, txt: "Kombination meiden"},
        "C" => {int: 14, txt: "Monitorisieren"},
        "B" => {int: 15, txt: "Vorsichtsmassnahmen"},
        "A" => {int: 16, txt: "keine Massnahmen"}
      }
    end

    def prepare_products
      unless @products
        @products = {}
        if @chapter70items
          Chapter70xtractor::LIMITATIONS.each do |key, desc_de|
            puts "Chapter70: Adding lim #{key} #{desc_de}" if $VERBOSE
            @limitations << {code: key,
                             id: (key.eql?("L") ? "70.02" : "70.01"),
                             desc_de: desc_de,
                             desc_fr: "",
                             chap70: true}
          end
          @chapter70items.values.each do |item|
            next unless item[:limitation] && item[:limitation].length > 0
            rose = @infos_zur_rose.values.find { |x| x[:pharmacode]&.eql?(item[:pharmacode]) }
            ean13 = rose[:ean13] if rose
            ean13 ||= "9999" + item[:pharmacode]
            prodno = item[:pharmacode]
            obj = {
              chapter70: true,
              ean13: ean13,
              description: item[:description],
              code: item[:limitation] # LIMNAMEBAG
            }
            @products[prodno] = obj
            puts "Chapter70: Adding product #{ean13} #{obj}" if $VERBOSE
          end
        end
        @refdata.each_pair do |ean13, item|
          next if item&.is_a?(Hash) && item[:atc_code] && /^Q/i.match(item[:atc_code])
          next if item[:prodno] && @products[item[:prodno]]
          refdata_atc = item[:atc_code]
          obj = {
            seq: @items[ean13] || @items[item[:ean13]],
            pac: nil,
            no8: nil,
            ean13: item[:ean13],
            atc: refdata_atc,
            ith: "",
            siz: "",
            eht: "",
            sub: "",
            comp: "",
            data_origin: "refdata-product"
          }
          # obj[:pexf_refdata] = item[:price]
          # obj[:ppub_refdata] = item[:pub_price=]
          # obj[:pharmacode=]  = item[:pharmacode=]
          if obj[:ean13] # via EAN-Code
            obj[:no8] = obj[:ean13].to_s[4..11]
          end
          swissmedic_pack = @packs[item[:no8]]
          if swissmedic_pack
            swissmedic_atc = swissmedic_pack[:atc_code]
            if swissmedic_atc && swissmedic_atc.length >= 3 && (refdata_atc.nil? || !refdata_atc.eql?(swissmedic_atc))
              puts "WARNING: #{ean13} ATC-code #{swissmedic_atc} from swissmedic overrides #{refdata_atc} one from refdata #{item[:desc_de]}"
              item[:data_origin] += "-swissmedic-ATC"
              item[:atc] = swissmedic_atc
            end
          end
          if obj[:no8] && (ppac = @packs[obj[:no8]]) && # Packungen.xls
              !ppac[:is_tier]
            # If RefData does not have EAN
            if obj[:ean13].nil?
              obj[:ean13] = ppac[:ean13]
            end
            # If RefData dose not have ATC-Code
            if obj[:atc].nil? || obj[:atc].empty?
              obj[:atc] = ppac[:atc_code].to_s
            end
            obj[:ith] = ppac[:ith_swissmedic]
            obj[:siz] = ppac[:package_size]
            obj[:eht] = ppac[:einheit_swissmedic]
            obj[:sub] = ppac[:substance_swissmedic]
            obj[:comp] = ppac[:composition_swissmedic]
          end
          obj[:price] = item[:price]
          obj[:pub_price] = item[:pub_price]

          if obj[:ean13].to_s[0..3] == "7680"
            if item[:prodno]
              @products[item[:prodno]] = obj
            else
              @products[ean13] = obj
            end
          end
        end
      end
      @products
    end

    def build_substance
      prepare_substances
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.SUBSTANCE(
          XML_OPTIONS
        ) {
          Oddb2xml.log "build_substance #{@substances.size} substances"
          exit 2 if (@options[:extended] || @options[:artikelstamm]) && (@substances.size == 0)
          nbr_records = 0
          @substances.each_with_index do |sub_name, i|
            xml.SB("DT" => "") do
              xml.SUBNO((i + 1).to_i)
              # xml.NAMD
              # xml.ANAMD
              # xml.NAMF
              xml.NAML sub_name
              nbr_records += 1
            end
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_limitation
      prepare_limitations
      Oddb2xml.log "build_limitation #{@limitations.size} limitations"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.LIMITATION(XML_OPTIONS) do
          nbr_records = 0
          @limitations.each do |lim|
            if lim[:id].empty?
              puts "Skipping empty id of #{lim}"
              next
            end
            xml.LIM("DT" => "") do
              case lim[:key]
              when :swissmedic_number8
                xml.SwissmedicNo8 lim[:id]
              when :swissmedic_number5
                xml.SwissmedicNo5 lim[:id]
              when :pharmacode
                xml.Pharmacode lim[:id]
              end
              xml.IT lim[:it]
              xml.LIMTYP lim[:type]
              xml.LIMVAL lim[:value]
              xml.LIMNAMEBAG lim[:code] # original LIMCD
              xml.LIMNIV lim[:niv]
              xml.DSCRD lim[:desc_de]
              xml.DSCRF lim[:desc_fr]
              xml.VDAT lim[:vdate]
              nbr_records += 1
            end
          end
          xml.RESULT do
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          end
        end
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_interaction
      prepare_interactions
      prepare_codes
      nbr_records = 0
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.INTERACTION(XML_OPTIONS) {
          Oddb2xml.log "build_interaction #{@interactions.size} interactions"
          @interactions.sort_by { |ix| ix[:ixno] }.each do |ix|
            xml.IX("DT" => "") {
              xml.IXNO ix[:ixno]
              xml.TITD ix[:title]
              # xml.TITF
              xml.GRP1D ix[:atc1]
              # xml.GRP1F
              xml.GRP2D ix[:atc2]
              # xml.GRP2F
              xml.EFFD ix[:effect]
              # xml.EFFF
              if @codes && ix[:grad]
                if (dict = @codes[ix[:grad].upcase])
                  xml.RLV dict[:int]
                  xml.RLVD dict[:txt]
                  # xml.RLVF
                end
              end
              # xml.EFFTXTD
              # xml.EFFTXTF
              xml.MECHD ix[:mechanism]
              # xml.MECHF
              xml.MEASD ix[:measures]
              # xml.MEASF
              # xml.REMD
              # xml.REMF
              # xml.LIT
              xml.DEL false
              # xml.IXMCH {
              #  xml.TYP
              #  xml.TYPD
              #  xml.TYPF
              #  xml.CD
              #  xml.CDD
              #  xml.CDF
              #  xml.TXTD
              #  xml.TXTF
              # }
              nbr_records += 1
            }
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_code
      prepare_codes
      nbr_records = 0
      Oddb2xml.log "build_code #{@codes.size} codes"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.CODE(XML_OPTIONS) {
          @codes.each_pair do |val, definition|
            xml.CD("DT" => "") {
              xml.CDTYP definition[:int]
              xml.CDVAL val
              xml.DSCRSD definition[:txt]
              # xml.DSCRSF
              # xml.DSCRMD
              # xml.DSCRMF
              # xml.DSCRD
              # xml.DSCRF
              xml.DEL false
              nbr_records += 1
            }
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def add_missing_products_from_swissmedic(add_to_products = false)
      Oddb2xml.log "build_product add_missing_products_from_swissmedic. Starting with #{@products.size} products and #{@packs.size} @packs"
      ean13_to_product = {}
      @products.each { |ean13, obj|
        ean13_to_product[ean13] = obj
        obj[:pharmacode] ||= @refdata[ean13][:pharmacode] if @refdata[ean13]
      }
      ausgabe = File.open(File.join(WORK_DIR, "missing_in_refdata.txt"), "w+")
      size_old = ean13_to_product.size
      @missing = []
      Oddb2xml.log "build_product add_missing_products_from_swissmedic. Imported #{size_old} ean13_to_product from @products. Checking #{@packs.size} @packs"
      @packs.each_with_index do |de_idx, index|
        ean = de_idx[1][:ean13]
        next if @refdata[ean]
        list_code = de_idx[1][:list_code]
        next if list_code && /Tierarzneimittel/.match(list_code)
        if add_to_products
          @products[ean] = {seq: {name_de: de_idx.last[:sequence_name],
                                  desc_de: "",
                                  name_fr: "",
                                  desc_fr: "",
                                  atc_code: de_idx.last[:atc_code]},
                            pac: nil,
                            sequence_name: de_idx.last[:sequence_name],
                            no8: de_idx.last[:prodno],
                            ean13: ean,
                            atc: de_idx.last[:atc_code],
                            ith: de_idx.last[:ith_swissmedic],
                            siz: de_idx.last[:package_size],
                            eht: de_idx.last[:einheit_swissmedic],
                            sub: de_idx.last[:substance_swissmedic],
                            comp: de_idx.last[:composition_swissmedic],
                            drug_index: de_idx.last[:drug_index]}
        end
        ean13_to_product[ean] = de_idx[1]
        @missing << de_idx[1]
        ausgabe.puts "#{ean},#{de_idx[1][:sequence_name]}"
      end
      corrected_size = ean13_to_product.size
      Oddb2xml.log "build_product add_missing_products_from_swissmedic. Added #{corrected_size - size_old} corrected_size #{corrected_size} size_old #{size_old} ean13_to_product."
    end

    def build_product
      self.class.class_eval do
        def check_name(obj, lang = :de)
          ean = obj[:ean13]
          refdata = @refdata[ean]
          if lang == :de
            name = refdata && refdata[:desc_de] ? refdata[:desc_de] : obj[:sequence_name]
          elsif lang == :fr
            name = refdata && refdata[:desc_fr] ? refdata[:desc_fr] : obj[:sequence_name]
          else
            return false
          end
          return false if !name || name.empty? || name.length < 3
          name[0..119] # limit to maximal 120 chars as specified in the XSD
        end
      end
      prepare_substances
      prepare_products
      prepare_interactions
      prepare_codes
      add_missing_products_from_swissmedic
      nbr_products = 0
      Oddb2xml.log "build_product #{@products.size + @missing.size} products"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        emitted = []
        xml.PRODUCT(XML_OPTIONS) {
          @missing.each do |obj|
            ean = obj[:ean13]
            next unless check_name(obj, :de)
            next unless check_name(obj, :fr)
            next if /^Q/i.match?(obj[:atc])
            if obj[:prodno]
              next if emitted.index(obj[:prodno])
              emitted << obj[:prodno]
            end
            xml.PRD("DT" => obj[:last_change]) {
              nbr_products += 1
              xml.GTIN ean
              xml.PRODNO obj[:prodno] if obj[:prodno]
              xml.DSCRD check_name(obj, :de)
              xml.DSCRF check_name(obj, :fr)
              xml.ATC obj[:atc_code] unless obj[:atc_code].empty?
              xml.IT obj[:ith_swissmedic] if obj[:ith_swissmedic]
              xml.CPT
              xml.PackGrSwissmedic obj[:package_size] if obj[:package_size]
              xml.EinheitSwissmedic obj[:einheit_swissmedic] if obj[:einheit_swissmedic]
              xml.SubstanceSwissmedic obj[:substance_swissmedic] if obj[:substance_swissmedic]
              xml.CompositionSwissmedic obj[:composition_swissmedic] if obj[:composition_swissmedic]
            }
          end
          @products.sort.to_h.each do |ean13, obj|
            next if /^Q/i.match?(obj[:atc])
            seq = obj[:seq]
            ean = obj[:ean13]
            next unless check_name(obj, :de)
            next unless check_name(obj, :fr)
            xml.PRD("DT" => obj[:last_change]) do
              nbr_products += 1
              xml.GTIN ean
              ppac = ((a_ppac = @packs[ean.to_s[4..11]]) && !a_ppac[:is_tier] ? a_ppac : {})
              ppac ||= @packs.find { |pac| pac.ean == ean }.first
              xml.PRODNO ppac[:prodno] if ppac[:prodno] && !ppac[:prodno].empty?
              xml.DSCRD check_name(obj, :de)
              xml.DSCRF check_name(obj, :fr)
              # xml.BNAMD
              # xml.BNAMF
              # xml.ADNAMD
              # xml.ADNAMF
              # xml.SIZE
              if seq
                xml.ADINFD seq[:comment_de] unless seq[:comment_de] && seq[:comment_de].empty?
                xml.ADINFF seq[:comment_fr] unless seq[:comment_fr] && seq[:comment_fr].empty?
                xml.GENCD seq[:org_gen_code] unless seq[:org_gen_code] && seq[:org_gen_code].empty?
              end
              # xml.GENGRP
              xml.ATC obj[:atc] unless obj[:atc].empty?
              xml.IT obj[:ith] unless obj[:ith].empty?
              # xml.ITBAG
              # xml.KONO
              # xml.TRADE
              # xml.PRTNO
              # xml.MONO
              # xml.CDGALD
              # xml.CDGALF
              # xml.FORMD
              # xml.FORMF
              # xml.DOSE
              # xml.DOSEU
              # xml.DRGFD
              # xml.DRGFF
              obj[:no8] =~ /(\d{5})(\d{3})/
              if @orphan.include?($1.to_s)
                xml.ORPH true
              end
              # xml.BIOPHA
              # xml.BIOSIM
              # xml.BFS
              # xml.BLOOD
              # xml.MSCD # always empty
              # xml.DEL
              xml.CPT {
                # xml.CPTLNO
                # xml.CNAMED
                # xml.CNAMEF
                # xml.IDXIND
                # xml.DDDD
                # xml.DDDU
                # xml.DDDA
                # xml.IDXIA
                # xml.IXREL
                # xml.GALF
                # xml.DRGGRPCD
                # xml.PRBSUIT
                # xml.CSOLV
                # xml.CSOLVQ
                # xml.CSOLVQU
                # xml.PHVAL
                # xml.LSPNSOL
                # xml.APDURSOL
                # xml.EXCIP
                # xml.EXCIPQ
                # xml.EXCIPCD
                # xml.EXCIPCF
                # xml.PQTY
                # xml.PQTYU
                # xml.SIZEMM
                # xml.WEIGHT
                # xml.LOOKD
                # xml.LOOKF
                # xml.IMG2
                if seq
                  seq[:substances].each do |sub|
                    xml.CPTCMP {
                      xml.LINE sub[:index] unless sub[:index].empty?
                      xml.SUBNO(@substances.index(sub[:name]) + 1) if @substances.include?(sub[:name])
                      xml.QTY sub[:quantity] unless sub[:quantity].empty?
                      xml.QTYU sub[:unit] unless sub[:unit].empty?
                      # xml.WHK
                    }
                  end
                  @interactions.each do |ix|
                    if [ix[:act1], ix[:act2]].include?(seq[:atc_code])
                      xml.CPTIX {
                        xml.IXNO ix[:ixno]
                        # xml.GRP
                        xml.RLV @codes[ix[:grad]]
                      }
                    end
                  end
                end
                # xml.CPTROA {
                # xml.SYSLOC
                # xml.ROA
                # }
              }
              # xml.PRDICD { # currently empty
              # xml.ICD
              # xml.RTYP
              # xml.RSIG
              # xml.REMD
              # xml.REMF
              # }
              xml.PackGrSwissmedic obj[:siz] unless obj[:siz].empty?
              xml.EinheitSwissmedic obj[:eht] unless obj[:eht].empty?
              xml.SubstanceSwissmedic obj[:sub] unless obj[:sub].empty?
              xml.CompositionSwissmedic obj[:comp] unless obj[:comp].empty?
            end
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_products
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def prepare_calc_items(suppress_composition_parsing: false)
      @calc_items = {}
      packungen_xlsx = File.join(Oddb2xml::DOWNLOADS, "swissmedic_package.xlsx")
      return unless File.exist?(packungen_xlsx)
      workbook = RubyXL::Parser.parse(packungen_xlsx)
      row_nr = 0
      workbook.worksheets[0].each do |row|
        row_nr += 1
        next unless row && row.cells[0] && row.cells[0].value && (row.cells[0].value.to_i > 0)
        iksnr = "%05i" % row.cells[0].value.to_i
        if row_nr % 250 == 0
          puts "#{Time.now}: At row #{row_nr} iksnr #{iksnr}"
          $stdout.flush
        end
        seq_name = COLUMNS_FEBRUARY_2019.keys.index(:name_base)
        i_3 = COLUMNS_FEBRUARY_2019.keys.index(:ikscd)
        siz = COLUMNS_FEBRUARY_2019.keys.index(:size)
        atc = COLUMNS_FEBRUARY_2019.keys.index(:atc_class)
        list_code = COLUMNS_FEBRUARY_2019.keys.index(:production_science)
        unit = COLUMNS_FEBRUARY_2019.keys.index(:unit)
        sub = COLUMNS_FEBRUARY_2019.keys.index(:substances)
        comp = COLUMNS_FEBRUARY_2019.keys.index(:composition)

        no8 = iksnr + sprintf("%03d", row.cells[i_3].value.to_i)
        name = row.cells[seq_name] ? row.cells[seq_name].value : nil
        atc_code = row.cells[atc] ? row.cells[atc].value : nil
        list_code = row.cells[list_code] ? row.cells[list_code].value : nil
        package_size = row.cells[siz] ? row.cells[siz].value : nil
        unit = row.cells[unit] ? row.cells[unit].value : nil
        active_substance = row.cells[sub] ? row.cells[sub].value : nil
        composition = row.cells[comp] ? row.cells[comp].value : nil

        # skip veterinary product
        next if atc_code && /^Q/i.match(atc_code)
        next if list_code && /Tierarzneimittel/.match(list_code)
        info = nil
        begin
          info = if suppress_composition_parsing
            Calc.new(name, package_size, unit)
          else
            Calc.new(name, package_size, unit, active_substance, composition)
          end
        rescue
          puts "#{Time.now}: #{row_nr} iksnr #{iksnr} rescue from Calc.new"
        end
        ean12 = "7680" + no8
        ean13 = (ean12 + Oddb2xml.calc_checksum(ean12))
        @calc_items[ean13] = info
      end
    end

    def emit_substance(xml, substance, emit_active = false)
      xml.MORE_INFO substance.more_info if substance.more_info
      xml.SUBSTANCE_NAME substance.name
      xml.IS_ACTIVE_AGENT substance.is_active_agent if emit_active
      if substance.dose
        if substance.qty.is_a?(Float) || substance.qty.is_a?(Integer)
          xml.QTY substance.qty
          xml.UNIT substance.unit
        else
          xml.DOSE_TEXT substance.dose.to_s
        end
      end
      if substance.chemical_substance
        xml.CHEMICAL_SUBSTANCE {
          emit_substance(xml, substance.chemical_substance)
        }
      end
      if substance.salts && (substance.salts.size > 0)
        xml.SALTS do
          substance.salts.each do |salt|
            xml.SALT do
              emit_substance(xml, salt)
            end
          end
        end
      end
    end

    def build_calc
      prepare_calc_items
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.ARTICLES(XML_OPTIONS) do
          @calc_items.each do |ean13, info|
            if info&.compositions
              xml.ARTICLE do
                xml.GTIN ean13
                xml.NAME info.column_c
                xml.PKG_SIZE info.pkg_size
                xml.SELLING_UNITS info.selling_units
                xml.MEASURE info.measure # Nur wenn Lösung wen Spalte M ml, Spritze

                if info.galenic_form.is_a?(String)
                  xml.GALENIC_FORM info.galenic_form
                  xml.GALENIC_GROUP "Unknown"
                else
                  xml.GALENIC_FORM info.galenic_form.description
                  xml.GALENIC_GROUP info.galenic_group ? info.galenic_group.description : "Unknown"
                end
                xml.COMPOSITIONS do
                  info.compositions.each do |composition|
                    xml.COMPOSITION do
                      xml.EXCIPIENS { emit_substance(xml, composition.excipiens) } if composition.excipiens
                      xml.LABEL composition.label if composition.label
                      xml.LABEL_DESCRIPTION composition.label_description if composition.label_description
                      xml.CORRESP composition.corresp if composition.corresp
                      if composition.substances && (composition.substances.size > 0)
                        xml.SUBSTANCES do
                          composition.substances.each { |substance| xml.SUBSTANCE { emit_substance(xml, substance, true) } }
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      csv_name = File.join(WORK_DIR, "oddb_calc.csv")
      CSV.open(csv_name, "w+", col_sep: ";") do |csv|
        csv << ["gtin"] + @calc_items.values.first.headers
        @calc_items.each do |key, value|
          if value&.to_array
            csv << [key] + value.to_array
          else
            puts "key #{key.inspect} WITHOUT #{value.inspect}"
          end
        end
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_article
      @overriden_salecd = []
      prepare_limitations
      prepare_articles
      idx = 0
      nbr_records = 0
      Oddb2xml.log "build_article #{idx} of #{@articles.size} articles"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        eans_from_refdata = @articles.collect { |refdata| refdata[:ean13] }
        eans_from_preparations = @items.keys
        missing_eans = []
        eans_from_preparations.each do |ean|
          next if ean.to_i == 0
          unless @articles.collect { |x| x[:ean13] }.index(ean)
            item = @items[ean].clone
            item[:pharmacode] ||= "123456" if defined?(RSpec)
            item[:ean13] = ean
            item[:_type] = :preparations_xml
            item[:desc_de] = item[:name_de] + " " + item[:desc_de]
            item[:desc_fr] = item[:name_fr] + " " + item[:desc_fr]
            @articles << item
          end
          unless eans_from_refdata.index(ean)
            missing_eans << ean
          end
        end
        xml.ARTICLE(XML_OPTIONS) {
          @articles.sort! { |a, b| a[:ean13] <=> b[:ean13] }
          @articles.each do |obj|
            idx += 1
            Oddb2xml.log "build_article #{obj[:ean13]}: #{idx} of #{@articles.size} articles" if idx % 500 == 0
            pac, no8 = nil, obj[:ean13].to_s[4..11] # BAG-XML(SL/LS)
            pack_info = nil
            pack_info = @packs[no8] if no8 # info from Packungen.xlsx from swissmedic_info
            ppac = nil # Packungen
            ean = obj[:ean13]
            next if pack_info && /Tierarzneimittel/.match(pack_info[:list_code])
            next if obj[:desc_de] && /ad us vet/i.match(obj[:desc_de])
            pharma_code = obj[:pharmacode]
            # ean = 0 if sprintf('%013d', ean).match(/^000000/)
            if obj[:seq]
              pac = obj[:seq][:packages][obj[:pharmacode]]
              pac ||= obj[:seq][:packages][ean]
            elsif @items && ean && @items[ean] && @items[ean][:packages]
              pac = @items[ean][:packages][ean]
            end
            if no8
              ppac = ((a_ppac = pack_info) && !a_ppac[:is_tier] ? a_ppac : nil)
            end
            zur_rose = nil
            if !@infos_zur_rose.empty? && ean && @infos_zur_rose[ean]
              zur_rose = @infos_zur_rose[ean] # zurrose
            end
            xml.ART("DT" => obj[:last_change] || "") do
              nbr_records += 1
              # Ignore Lint/RequireParentheses warning on next line!
              xml.REF_DATA obj[:refdata] || @migel[pharma_code] ? "1" : "0"
              if obj[:pharmacode] && obj[:pharmacode].length > 0
                xml.PHAR obj[:pharmacode]
              elsif zur_rose
                puts "Adding #{zur_rose[:pharmacode]} to article GTIN #{ean}"
                xml.PHAR zur_rose[:pharmacode]
              end
              # xml.GRPCD
              # xml.CDS01
              # xml.CDS02
              if ppac
                xml.SMCAT ppac[:swissmedic_category][0] unless ppac[:swissmedic_category].empty?
                xml.GEN_PRODUCTION ppac[:gen_production] unless ppac[:gen_production].empty?
                xml.INSULIN_CATEGORY ppac[:insulin_category] unless ppac[:insulin_category].empty?
                xml.DRUG_INDEX ppac[:drug_index] unless ppac[:drug_index].empty?
              end
              if no8 && !no8.to_s.empty?
                if ean && (ean.to_s[0..3] == "7680")
                  xml.SMNO no8.to_s
                end
              end
              if ppac
                xml.PRODNO ppac[:prodno] if ppac[:prodno] && !ppac[:prodno].empty?
              end
              # xml.HOSPCD
              # xml.CLINCD
              # xml.ARTTYP
              if zur_rose
                xml.VAT zur_rose[:vat]
              end
              emit_salecd(xml, ean, obj)
              if pac && pac[:limitation_points]
                # xml.INSLIM
                xml.LIMPTS pac[:limitation_points] unless pac[:limitation_points].empty?
              end
              # xml.GRDFR
              xml.COOL 1 if ppac && /Blutprodukte|impfstoffe/.match(ppac[:list_code])
              # xml.TEMP
              if ean
                flag = ppac && !ppac[:drug_index].empty? ? true : false
                # as same flag
                xml.CDBG(flag ? "Y" : "N")
                xml.BG(flag ? "Y" : "N")
              end
              xml.DSCRD obj[:desc_de] if obj[:desc_de] && !obj[:desc_de].empty?
              xml.DSCRF obj[:desc_fr] if obj[:desc_fr] && !obj[:desc_fr].empty?
              xml.DSCRF obj[:desc_de] if !obj[:desc_fr] || obj[:desc_fr].empty?
              xml.SORTD obj[:desc_de].upcase if obj[:desc_de] && !obj[:desc_de].empty?
              xml.SORTF obj[:desc_fr].upcase if obj[:desc_fr] && !obj[:desc_fr].empty?
              xml.SORTF obj[:desc_de].upcase if !obj[:desc_fr] || obj[:desc_fr].empty?
              # xml.QTYUD
              # xml.QTYUF
              # xml.IMG
              # xml.IMG2
              # xml.PCKTYPD
              # xml.PCKTYPF
              # xml.MULT
              if obj[:seq]
                xml.SYN1D obj[:seq][:name_de] unless obj[:seq][:name_de].empty?
                xml.SYN1F obj[:seq][:name_fr] unless obj[:seq][:name_fr].empty?
              end
              if obj[:seq]
                case obj[:seq][:deductible]
                when "Y" then xml.SLOPLUS 1; # 20%
                when "N" then xml.SLOPLUS 2; # 10%
                else xml.SLOPLUS "" # k.A.
                end
              end
              # xml.NOPCS
              # xml.HSCD
              # xml.MINI
              # xml.DEPCD
              # xml.DEPOT
              # xml.BAGSL
              # xml.BAGSLC
              # xml.LOACD
              if obj[:stat_date]
                xml.OUTSAL obj[:stat_date] if obj[:stat_date] && !obj[:stat_date].empty?
              end
              # xml.STTOX
              # xml.NOTI
              # xml.GGL
              # xml.CE
              # xml.SMDAT
              # xml.SMCDAT
              # xml.SIST
              # xml.ESIST
              # xml.BIOCID
              # xml.BAGNO
              # xml.LIGHT
              # xml.DEL
              xml.ARTCOMP {
                # use ean13(gln) as COMPNO
                xml.COMPNO obj[:company_ean] if obj[:company_ean] && (obj[:company_ean].to_s.length > 1)
                # xml.ROLE
                # xml.ARTNO1
                # xml.ARTNO2
                # xml.ARTNO3
              }
              if ean
                xml.ARTBAR {
                  xml.CDTYP "E13"
                  xml.BC ean #  /^9999|^0000|^0$/.match(ean.to_s) ? 0 : sprintf('%013d', ean)
                  xml.BCSTAT "A" # P is alternative
                }
              end
              if pac && pac[:prices]
                pac[:prices].each_pair do |key, price|
                  xml.ARTPRI {
                    xml.VDAT price[:valid_date] unless price[:valid_date].empty?
                    xml.PTYP price[:price_code] unless price[:price_code].empty?
                    xml.PRICE price[:price] unless price[:price].empty?
                  }
                end
              end
              if zur_rose
                price = zur_rose[:price]
                xml.ARTPRI {
                  xml.PTYP "ZURROSE"
                  xml.PRICE price
                }
                xml.ARTPRI {
                  xml.PTYP "ZURROSEPUB"
                  xml.PRICE zur_rose[:pub_price]
                }
                unless @options[:percent].nil?
                  xml.ARTPRI {
                    xml.PTYP "RESELLERPUB"
                    xml.PRICE (price.to_f * (1 + (@options[:percent].to_f / 100))).round_by(0.05).round(2)
                  }
                end
              end
              nincd = detect_nincd(obj)
              if nincd
                xml.ARTINS {
                  xml.NINCD nincd
                }
              end
            end
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.log "build_article. Done #{idx} of #{@articles.size} articles. Overrode #{@overriden_salecd.size} SALECD"
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_fi
      nbr_records = 0
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.KOMPENDIUM(XML_OPTIONS) {
          %w[de fr].each do |lang|
            infos = @infos[lang].uniq { |i| i[:monid] }
            infos.each do |info|
              xml.KMP(
                "MONTYPE" => "fi", # only
                "LANG" => lang.upcase,
                "DT" => ""
              ) {
                unless info[:name].empty?
                  xml.name info[:name]
                end
                unless info[:owner].empty?
                  xml.owner info[:owner]
                end
                xml.monid info[:monid] unless info[:monid].empty?
                xml.style { xml.cdata(info[:style]) } if info[:style]
                xml.paragraph { xml.cdata(Nokogiri::HTML.fragment(info[:paragraph].to_html).to_html(encoding: "UTF-8")) } if info[:paragraph]
                nbr_records += 1
              }
            end
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_fi_product
      prepare_products
      nbr_records = 0
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.KOMPENDIUM_PRODUCT(XML_OPTIONS) {
          info_index = {}
          %w[de fr].each do |lang|
            @infos[lang].each_with_index do |info, i|
              info_index[info[:monid]] = i
            end
            # prod
            @products.each do |ean13, prod|
              next unless prod[:seq] && prod[:seq][:packages]
              seq = prod[:seq]
              prod[:seq][:packages].each { |phar, package|
                next unless package[:swissmedic_number8]
                m = /(\d{5})(\d{3})/.match(package[:swissmedic_number8])
                next unless m
                number = m[1].to_s
                idx = info_index[number]
                next unless idx
                xml.KP("DT" => "") {
                  xml.MONID @infos[lang][idx][:monid]
                  xml.PRDNO seq[:product_key] unless seq[:product_key].empty?
                  # as orphan ?
                  xml.DEL @orphan.include?(number) ? true : false
                  nbr_records += 1
                }
              }
            end
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_company
      nbr_records = 0
      Oddb2xml.log "build_company #{@companies.size} companies"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.Betriebe(XML_OPTIONS) {
          @companies.each do |c|
            xml.Betrieb("DT" => "") {
              xml.GLN_Betrieb c[:gln] unless c[:gln].empty?
              xml.Betriebsname_1 c[:name_1] unless c[:name_1].empty?
              xml.Betriebsname_2 c[:name_2] unless c[:name_2].empty?
              xml.Strasse c[:address] unless c[:address].empty?
              xml.Nummer c[:number] unless c[:number].empty?
              xml.PLZ c[:post] unless c[:post].empty?
              xml.Ort c[:place] unless c[:place].empty?
              xml.Bewilligungskanton c[:region] unless c[:region].empty?
              xml.Land c[:country] unless c[:country].empty?
              xml.Betriebstyp c[:type] unless c[:type].empty?
              xml.BTM_Berechtigung c[:authorization] unless c[:authorization].empty?
              nbr_records += 1
            }
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def build_person
      nbr_records = 0
      Oddb2xml.log "build_person #{@people.size} persons"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        xml.Personen(XML_OPTIONS) {
          @people.each do |p|
            xml.Person("DT" => "") {
              xml.GLN_Person p[:gln] unless p[:gln].empty?
              xml.Name p[:last_name] unless p[:last_name].empty?
              xml.Vorname p[:first_name] unless p[:first_name].empty?
              xml.PLZ p[:post] unless p[:post].empty?
              xml.Ort p[:place] unless p[:place].empty?
              xml.Bewilligungskanton p[:region] unless p[:region].empty?
              xml.Land p[:country] unless p[:country].empty?
              xml.Bewilligung_Selbstdispensation p[:license] unless p[:license].empty?
              xml.Diplom p[:certificate] unless p[:certificate].empty?
              xml.BTM_Berechtigung p[:authorization] unless p[:authorization].empty?
              nbr_records += 1
            }
          end
          xml.RESULT {
            xml.OK_ERROR "OK"
            xml.NBR_RECORD nbr_records
            xml.ERROR_CODE ""
            xml.MESSAGE ""
          }
        }
      end
      Oddb2xml.add_hash(a_builder.to_xml)
    end

    def detect_nincd(de_idx)
      if @lppvs[de_idx[:ean13].to_s] # LPPV
        20
      elsif @items[de_idx[:pharmacode]] # BAG-XML (SL/LS)
        10
      elsif de_idx[:migel] || # MiGel (xls)
          (de_idx[:_type] == :nonpharma) # MiGel (swissindex)
        13
      else
        # fallback via EAN
        bag_entry_via_ean = @items.values.select do |item|
          next unless item[:packages]
          item[:packages].values.count { |a_pac| a_pac[:ean13].to_s.eql?(de_idx[:ean13].to_s) } != 0
        end
        if bag_entry_via_ean.length > 0
          10
        end
      end
    end

    ### --- see oddb2tdat
    DAT_LEN = {
      RECA: 2,
      CMUT: 1,
      PHAR: 7,
      ABEZ: 50,
      PRMO: 6,
      PRPU: 6,
      CKZL: 1,
      CLAG: 1,
      CBGG: 1,
      CIKS: 1,
      ITHE: 7,
      CEAN: 13,
      CMWS: 1
    }
    def format_price(price_str, len = 6, int_len = 4, frac_len = 2)
      price = price_str.split(".")
      pre = "%0#{int_len}d" % (price[0] || "0")
      las = if price[1]
        if price[1].size < frac_len
          price[1] + "0" * (frac_len - price[2].to_s.size)
        else
          price[1][0, frac_len]
        end
      else
        "0" * frac_len
      end
      (pre.to_s + las.to_s)[0, len]
    end

    def format_date(date_str, len = 7)
      date = date_str.delete(".")
      if date.size < len
        date += "0" * (len - date.size)
      end
      date[0, len]
    end

    # The migel name must be always 50 chars wide and in ISO 8859-1 format
    def format_name(name, length)
      ("%-#{length}s" % name)[0..length - 1]
    end

    def build_dat
      prepare_articles
      rows = []
      @articles.each do |obj|
        ean = obj[:ean13]
        next if (ean.to_s.length != 13) && !ean14
        next if obj[:type] == :nonpharma
        row = ""
        pack_info = nil
        if (x = @packs.find { |k, v| v[:ean13].eql?(ean) })
          pack_info = x[1]
        end
        # Oddb2tdat.parse
        pac, no8 = nil, nil
        if obj[:seq] && obj[:seq][:packages]
          pac = obj[:seq][:packages][obj[:pharmacode]]
          pac ||= obj[:seq][:packages][ean]
        elsif @items && @items[ean] && @items[ean][:packages]
          pac = @items[ean][:packages][ean]
        end
        # :swissmedic_numbers
        if pac
          no8 = pac[:swissmedic_number8]
        end
        if pac && pac[:prices].nil? && no8
          ppac = ((ppac = pack_info) && ppac[:is_tier] ? ppac : nil)
          pac = ppac if ppac
        end
        row << "%#{DAT_LEN[:RECA]}s" % "11"
        zur_rose = @infos_zur_rose[ean] # zurrose
        row << if zur_rose && zur_rose[:cmut]
          zur_rose[:cmut]
        else
          "1"
        end
        row << "%0#{DAT_LEN[:PHAR]}d" % obj[:pharmacode].to_i
        abez = ( # de name
          obj[:desc_de].to_s + " " +
          (pac ? pac[:name_de].to_s : "") +
          (obj[:quantity] || "")
        ).delete('"')
        if @infos_zur_rose[ean]
          price_exf = sprintf("%06i", (@infos_zur_rose[ean][:price].to_f * 100).to_i)
          price_public = sprintf("%06i", (@infos_zur_rose[ean][:pub_price].to_f * 100).to_i)
          if !@options[:percent].nil?
            price_public = sprintf("%06i", (price_exf.to_f * (1 + (@options[:percent].to_f / 100))).round_by(0.05).round(2))
          end
        elsif pac && pac[:prices]
          price_exf = sprintf("%06i", (pac[:prices][:exf_price][:price].to_f * 100).to_i) if pac[:prices][:exf_price] && pac[:prices][:exf_price][:price]
          price_public = sprintf("%06i", (pac[:prices][:pub_price][:price].to_f * 100).to_i) if pac[:prices][:pub_price] && pac[:prices][:pub_price][:price]
        end
        row << format_name(Oddb2xml.patch_some_utf8(abez), DAT_LEN[:ABEZ])
        if price_exf.to_s.length > DAT_LEN[:PRMO] ||
            price_public.to_s.length > DAT_LEN[:PRPU]
          puts "Price exfactory #{price_exf} or public #{price_public} is too high to be added into transfer.dat"
          break
        end
        row << "%#{DAT_LEN[:PRMO]}s" % (price_exf ? price_exf.to_s : ("0" * DAT_LEN[:PRMO]))
        row << "%#{DAT_LEN[:PRPU]}s" % (price_public ? price_public.to_s : ("0" * DAT_LEN[:PRPU]))
        row << "%#{DAT_LEN[:CKZL]}s" % if @lppvs[ean]
                 "2"
               elsif pac # sl_entry
                 "1"
               else
                 "3"
               end
        row << "%#{DAT_LEN[:CLAG]}s" % if ppac && /Blutproduct|impfstoffe/.match(ppac[:list_code]) # COOL
                 "1"
               else
                 "0"
               end
        row << "%#{DAT_LEN[:CBGG]}s" % if pack_info && pack_info[:drug_index]
                 "3"
               else
                 "0"
               end
        row << "%#{DAT_LEN[:CIKS]}s" % if no8 && pack_info && !pack_info[:is_tier] # Packungen.xls
                 pack_info[:swissmedic_category]
               else
                 "0"
               end.gsub(/(\+|\s)/, "")
        row << "%0#{DAT_LEN[:ITHE]}d" % if no8 && pack_info && !pack_info[:is_tier]
                 format_date(pack_info[:ith_swissmedic])
               else
                 ("0" * DAT_LEN[:ITHE])
               end.to_i
        row << "%0#{DAT_LEN[:CEAN]}d" % (/^000000/.match?(sprintf("%013d", ean.to_i)) ? 0 : ean.to_i)
        row << "%#{DAT_LEN[:CMWS]}s" % "2" # pharma
        rows << row
      end
      rows.join("\n")
    end

    def build_with_migel_dat
      reset = true
      prepare_articles(reset)
      rows = []
      @articles.each do |obj|
        row = ""
        next if (obj[:ean13].to_s.length != 13) && !ean14
        # Oddb2tdat.parse_migel
        row << "%#{DAT_LEN[:RECA]}s" % "11"
        row << "%#{DAT_LEN[:CMUT]}s" % if (phar = obj[:pharmacode]) && (phar.size > 3)
                 "1"
               else
                 "3"
               end
        row << "%0#{DAT_LEN[:PHAR]}d" % obj[:pharmacode].to_i
        abez = ( # de name
          obj[:desc_de].to_s + " " +
        (obj[:quantity] || "")
        ).delete('"')
        row << format_name(Oddb2xml.patch_some_utf8(abez), DAT_LEN[:ABEZ])
        row << "0" * DAT_LEN[:PRMO]
        row << "0" * DAT_LEN[:PRPU]
        row << "%#{DAT_LEN[:CKZL]}s" % "3" # sl_entry and lppv
        row << "%#{DAT_LEN[:CLAG]}s" % "0"
        row << "%#{DAT_LEN[:CBGG]}s" % "0"
        row << "%#{DAT_LEN[:CIKS]}s" % " " # no category
        row << "%0#{DAT_LEN[:ITHE]}d" % 0
        row << obj[:ean13].to_s.rjust(DAT_LEN[:CEAN], "0")
        row << "%#{DAT_LEN[:CMWS]}s" % "1" # nonpharma
        rows << row
      end
      rows.join("\n")
    end

    def emit_salecd(xml, ean13, obj)
      zur_rose = nil
      if !@infos_zur_rose.empty? && ean13 && @infos_zur_rose[ean13]
        zur_rose = @infos_zur_rose[ean13] # zurrose
      end
      nincd = detect_nincd(obj)
      in_refdata = !!(obj[:seq] && obj[:seq][:packages] && obj[:seq][:packages][ean13] && obj[:seq][:packages][ean13][:swissmedic_number8])
      status = if nincd && nincd == 13
        "A"
      else
        zur_rose && zur_rose[:cmut] != "3" ? "A" : "I"
      end
      if in_refdata && !"A".eql?(status)
        msg = "Overriding status #{status} nincd #{nincd} for #{ean13} as in refdata_pharma"
        # Oddb2xml.log msg
        @overriden_salecd << ean13
        xml.SALECD("A") { xml.comment(msg) }
      else
        xml.SALECD(status) { xml.comment("expiry_date #{obj[:expiry_date]}") if obj[:expiry_date] }
      end
    end

    def build_artikelstamm
      @@emitted_v5_gtins = []
      @csv_file = CSV.open(File.join(WORK_DIR, "artikelstamm_#{Date.today.strftime("%d%m%Y")}_v5.csv"), "w+")
      @csv_file << ["gtin", "name", "pkg_size", "galenic_form", "price_ex_factory", "price_public", "prodno", "atc_code", "active_substance", "original", "it-code", "sl-liste"]
      @csv_file.sync = true
      variant = "build_artikelstamm"
      # @infos_zur_rose.delete_if { |key, val| val[:cmut].eql?('3') } # collect only active zur rose item
      # No. Marco did not filter it, eg. 8804121 in rtikelstamm_oddb2xml_051217_v5.xm
      self.class.class_eval do
        def check_article_name(obj, lang = :de)
          ean = obj[:ean13]
          refdata = @refdata[ean]
          if lang == :de
            name = refdata && refdata[:desc_de] ? refdata[:desc_de] : obj[:sequence_name]
          elsif lang == :fr
            name = refdata && refdata[:desc_fr] ? refdata[:desc_fr] : obj[:sequence_name]
          else
            return "--missing--"
          end
          return "--missing--" if !name || name.empty? || name.length < 3
          name[0..119] # limit to maximal 120 chars as specified in the XSD
        end
      end
      self.class.class_eval do
        def override(xml, id, field, default_value)
          has_overrides = /\d{13}/.match?(id.to_s) ? @@article_overrides[id.to_i] : @@product_overrides[id.to_i]
          if has_overrides && has_overrides[field.to_s]
            new_value = has_overrides[field.to_s]
            if new_value.to_s.eql?(default_value.to_s)
              xml.comment("obsolete override")
            else
              xml.comment("override #{default_value} with")
            end
            cmd = "xml.#{field} \"#{new_value}\""
          else
            cmd = "xml.#{field} \"#{default_value.to_s.delete('"')}\""
          end
          eval cmd if default_value
        end
      end
      self.class.class_eval do
        def emit_items(xml)
          nr_items = 0
          gtins_to_article = {}
          @articles.each { |article| gtins_to_article[article[:ean13]] = article }
          sl_gtins = @items.values.collect { |x| x[:packages].keys }.flatten.uniq
          gtins = gtins_to_article.keys + @infos_zur_rose.keys + @packs.values.collect { |x| x[:ean13] } + sl_gtins
          gtins = (gtins - @@gtin2ignore)
          gtins.sort!.uniq!
          gtins.each do |ean13|
            no8 = ean13.to_s[4..11] # BAG-XML(SL/LS)
            next if ean13 == 0
            obj = gtins_to_article[ean13] || @items.values.find { |x| x[:packages].keys.index(ean13) } || @infos_zur_rose[ean13]
            if obj
              obj = @packs[no8].merge(obj) if @packs[no8]
            else
              obj = @packs[no8] # obj not yet in refdata. Use data from swissmedic_package.xlsx
            end
            nr_items += 1
            Oddb2xml.log "build_artikelstamm #{ean13}: #{nr_items} of #{gtins.size} articles" if nr_items % 5000 == 0
            item = @items[ean13]
            pack_info = nil
            pack_info = @packs[no8] if no8 && /#{ean13}/.match(@packs[no8].to_s) # info from Packungen.xlsx from swissmedic_info
            next if pack_info && /Tierarzneimittel/.match(pack_info[:list_code])
            next if obj[:desc_de] && /ad us vet/i.match(obj[:desc_de])
            sequence = obj[:seq]
            if sequence.nil? && @packs[no8] && /#{ean13}/.match(@packs[no8].to_s)
              sequence = {packages: {ean13 => @packs[no8]}}
              obj[:seq] = sequence.clone
            end
            if sequence.nil? && @items[ean13] && @items[ean13][:packages][ean13]
              sequence = @items[ean13]
            end
            if sequence
              if obj[:seq] && !obj[:seq][:packages].keys.index(ean13)
                # puts "unable to find  #{ean13} in #{obj[:seq][:packages].keys}"
                next
              end
              sequence[:packages].each do |gtin, package|
                pkg_gtin = package[:ean13].clone
                if package[:no8] && (new_ean_13 = Oddb2xml.getEan13forNo8(package[:no8]))
                  if !new_ean_13.eql?(pkg_gtin)
                    puts "Setting #{new_ean_13} for #{pkg_gtin}"
                    pkg_gtin = new_ean_13
                  end
                end
                info = @calc_items[pkg_gtin]
                if @@emitted_v5_gtins.index(pkg_gtin)
                  next
                else
                  @@emitted_v5_gtins << pkg_gtin.clone
                end
                options = {"PHARMATYPE" => "P"}
                xml.ITEM(options) do
                  name = item[:name_de] + " " + item[:desc_de].strip + " " + package[:desc_de] if package && package[:desc_de]
                  name ||= @refdata[pkg_gtin] ? @refdata[pkg_gtin][:desc_de] : nil
                  name ||= @infos_zur_rose[ean13][:description] if @infos_zur_rose[ean13]
                  name ||= obj[:name_de] + ", " + obj[:desc_de].strip if obj[:name_de]
                  name ||= (item[:desc_de] + item[:name_de]) if item
                  name ||= obj[:sequence_name]
                  xml.GTIN pkg_gtin.to_s.rjust(13, "0")
                  xml.SALECD("A")
                  # maxLength for DSCR is 50 for Artikelstamm v3
                  xml.DSCR(name) # for description for zur_rose
                  name_fr = item[:name_fr] + " " + item[:desc_fr].strip + " " + package[:desc_fr] if package && package[:desc_fr]
                  name_fr ||= @refdata[pkg_gtin] ? @refdata[pkg_gtin][:desc_fr] : nil
                  # Zugelassenen Packungen has only german names
                  name_fr ||= (obj[:name_fr] + ", " + obj[:desc_fr]).strip if obj[:name_fr]
                  # ZuRorse has only german names
                  name_fr ||= (item[:name_fr] + ", " + item[:desc_fr]) if item
                  name_fr ||= name
                  xml.DSCRF(name_fr)
                  if obj[:company_name] || obj[:company_ean]
                    xml.COMP do # Manufacturer
                      xml.NAME obj[:company_name][0..99] # limit to 100 chars as in XSD
                      xml.GLN obj[:company_ean]
                    end
                  end
                  pexf = ppub = nil
                  if package[:prices]
                    pexf ||= package[:prices][:exf_price][:price]
                    ppub ||= package[:prices][:pub_price][:price]
                  elsif @items[ean13] && @items[ean13][:packages] && @items[ean13][:packages][ean13] && (bag_prices = @items[ean13][:packages][ean13][:prices])
                    pexf ||= bag_prices[:exf_price][:price]
                    ppub ||= bag_prices[:pub_price][:price]
                  else
                    pexf ||= obj[:price]
                    ppub ||= obj[:pub_price]
                  end
                  ppub = nil if ppub && ppub.size == 0
                  pexf = nil if pexf && pexf.size == 0
                  if !(obj[:price] && !obj[:price].empty?) || !(obj[:pub_price] && !obj[:pub_price].empty?)
                    zur_rose_detail = @infos_zur_rose.values.find { |x| x[:ean13].to_i == ean13.to_i }
                    if zur_rose_detail
                      pexf ||= zur_rose_detail[:price]
                      ppub ||= zur_rose_detail[:pub_price]
                    end
                  end
                  xml.PEXF pexf if pexf
                  xml.PPUB ppub if ppub
                  measure = ""
                  if info
                    # MEASSURE Measurement Unit,e.g. Pills or milliliters
                    #             <DSCR>HIRUDOID Creme 3 mg/g 40 g</DSCR>
                    xml.PKG_SIZE info.pkg_size.to_i if info.pkg_size
                    if info.measure
                      measure = info.measure
                    elsif info.pkg_size && info.unit
                      measure = info.pkg_size + " " + info.unit
                    elsif info.pkg_size
                      measure = info.pkg_size
                    end
                    xml.MEASURE measure
                    xml.MEASUREF measure
                    # Die Darreichungsform dieses Items. zB Tablette(n) oder Spritze(n)
                    xml.DOSAGE_FORM info.galenic_form.descriptions["de"] if info.galenic_form.descriptions["de"]
                    xml.DOSAGE_FORMF info.galenic_form.descriptions["fr"] if info.galenic_form.descriptions["fr"]
                  end
                  xml.SL_ENTRY "true" if sl_gtins.index(pkg_gtin)
                  xml.IKSCAT package[:swissmedic_category][0] if package[:swissmedic_category] && package[:swissmedic_category].length > 0
                  xml.GENERIC_TYPE sequence[:org_gen_code] if sequence[:org_gen_code] && !sequence[:org_gen_code].empty?
                  xml.LPPV "true" if @lppvs[pkg_gtin.to_s] # detect_nincd
                  if item && item[:deductible]
                    case item[:deductible]
                      when "Y" then xml.DEDUCTIBLE 20; # 20%
                      when "N" then xml.DEDUCTIBLE 10; # 10%
                    end
                  end
                  prodno = Oddb2xml.getProdnoForEan13(pkg_gtin)
                  atc = package[:atc_code]
                  refdata_atc = @refdata[pkg_gtin][:atc_code] if @refdata && @refdata[pkg_gtin] && @refdata[pkg_gtin]
                  if refdata_atc && atc.nil?
                    puts "WARNING: #{pkg_gtin} ATC-code from refdata #{refdata_atc} as Swissmedic ATC is nil #{name}"
                    atc = refdata_atc
                  end
                  unless prodno # find a prodno from packages for vaccinations
                    if atc && /^J07/.match(atc) && !/^J07AX/.match(atc)
                      pack = @packs.values.find { |v| v && v[:atc_code].eql?(atc) }
                      if pack
                        prodno = pack[:prodno]
                        Oddb2xml.log "Patching vaccination for #{pkg_gtin} #{atc} #{name} via prodno #{prodno}"
                      else
                        Oddb2xml.log "unable to find a pack/prodno for  vaccination for #{pkg_gtin} #{atc} #{name}"
                      end
                    end
                  end
                  xml.PRODNO prodno if prodno
                  @csv_file << [pkg_gtin, name, package[:unit], measure,
                    pexf || "",
                    ppub || "",
                    prodno, atc, package[:substance_swissmedic],
                    sequence[:org_gen_code], package[:ith_swissmedic],
                    @items[pkg_gtin] ? "SL" : ""]
                end
              end
            else # non pharma
              if @@emitted_v5_gtins.index(ean13)
                next
              else
                @@emitted_v5_gtins << ean13.clone
              end
              # Set the pharmatype to 'Y' for outdated products, which are no longer found
              # in refdata/packungen
              chap70 = nil
              if @chapter70items.values.find { |x| x[:pharmacode]&.eql?(obj[:pharmacode]) }
                Oddb2xml.log "found chapter #{obj[:pharmacode]}" if $VERBOSE
                chap70 = true
              end
              patched_pharma_type = (/^7680/.match(ean13.to_s.rjust(13, "0")) || chap70 ? "P" : "N")
              next if /^#{Oddb2xml::FAKE_GTIN_START}/o.match?(ean13.to_s)
              next if obj[:data_origin].eql?("zur_rose") && /^7680/.match(ean13) # must skip inactiv items
              xml.ITEM({"PHARMATYPE" => patched_pharma_type}) do
                xml.GTIN ean13.to_s.rjust(13, "0")
                if obj[:pharmacode] && obj[:pharmacode].length > 0
                  xml.PHAR obj[:pharmacode]
                elsif (zur_rose = @infos_zur_rose[ean13])
                  puts "Artikelstamm: Adding #{zur_rose[:pharmacode]} to article GTIN #{ean13}"
                  xml.PHAR zur_rose[:pharmacode]
                elsif /^7680/.match?(ean13)
                  puts "Artikelstamm: No pharmacode for article GTIN #{ean13} via ZurRose"
                end
                emit_salecd(xml, ean13, obj)
                description = obj[:desc_de] || obj[:description] # for description for zur_rose
                xml.DSCR(description)
                xml.DSCRF(obj[:desc_fr] || "--missing--")
                if obj[:company_ean] && !obj[:company_ean].empty?
                  xml.COMP do
                    xml.GLN obj[:company_ean]
                  end
                end
                if !(obj[:price] && !obj[:price].empty?) || !(obj[:pub_price] && !obj[:pub_price].empty?)
                  zur_rose_detail = @infos_zur_rose.values.find { |x| x[:ean13].to_i == ean13.to_i }
                end
                ppub = nil
                pexf = nil
                if obj[:price] && !obj[:price].empty?
                  xml.PEXF(pexf = obj[:price])
                elsif zur_rose_detail
                  if zur_rose_detail[:price] && !zur_rose_detail[:price].empty? && !zur_rose_detail[:price].eql?("0.00")
                    # Oddb2xml.log "NonPharma: #{ean13} adding PEXF #{zur_rose_detail[:price]} #{description}"
                    xml.PEXF(pexf = zur_rose_detail[:price])
                  end
                end
                if obj[:pub_price] && !obj[:pub_price].empty?
                  xml.PPUB(ppub = obj[:pub_price])
                elsif zur_rose_detail
                  if zur_rose_detail[:pub_price] && !zur_rose_detail[:pub_price].empty? && !zur_rose_detail[:pub_price].eql?("0.00")
                    # Oddb2xml.log "NonPharma: #{ean13} adding PPUB #{zur_rose_detail[:pub_price]} #{description}"
                    xml.PPUB(ppub = zur_rose_detail[:pub_price])
                  end
                end
                @csv_file << [ean13, description, "", "", pexf, ppub, "", "", "", "", "", ""]
                if chap70
                  xml.comment "Chapter70 hack #{ean13.to_s.rjust(13, "0")} #{description.encode(xml: :text).gsub("--", "-")}"
                  xml.SL_ENTRY "true"
                  xml.PRODNO obj[:pharmacode]
                end
              end
            end
          end
          @csv_file.close if @csv_file && !@csv_file.closed?
          nr_items
        end
      end
      unless @prepared
        require "oddb2xml/chapter_70_hack"
        Oddb2xml::Chapter70xtractor.parse
        @chapter70items = Oddb2xml::Chapter70xtractor.items
        prepare_limitations
        prepare_articles
        prepare_products
        add_missing_products_from_swissmedic(true)
        prepare_calc_items(suppress_composition_parsing: true)
        @prepared = true
        @old_rose_size = @infos_zur_rose.size
      end
      nr_products = 0
      nr_articles = 0
      @nr_articles = 0
      used_limitations = []
      # Oddb2xml.log "#{variant} #{nr_products} of #{@products.size} articles and ignore #{@@gtin2ignore.size} gtins specified via #{@@ignore_file}"
      a_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
        xml.doc.tag_suffix = @tag_suffix
        elexis_strftime_format = "%FT%T\.%L%:z"
        @@cumul_ver = (Date.today.year - 2013) * 12 + Date.today.month
        options_xml = {
          "xmlns" => "http://elexis.ch/Elexis_Artikelstamm_v5",
          "CREATION_DATETIME" => Time.new.strftime(elexis_strftime_format),
          "BUILD_DATETIME" => Time.new.strftime(elexis_strftime_format),
          "DATA_SOURCE" => "oddb2xml"
        }
        emitted_prodno = []
        no8_to_prodno = {}
        @packs.collect { |key, val| no8_to_prodno[key] = val [:prodno] }
        xml.comment("Produced by #{__FILE__} version #{VERSION} at #{Time.now}")
        xml.ARTIKELSTAMM(options_xml) do
          xml.PRODUCTS do
            products = @products.sort_by { |ean13, obj| ean13 }
            products.each do |product|
              ean13 = product[0]
              obj = product[1]
              next if /^Q/i.match?(obj[:atc])
              ean = obj[:ean13]
              sequence = obj[:seq]
              sequence ||= @products[ean][:seq] if @products[ean]
              next unless check_article_name(obj, :de)
              ppac = ((a_ppac = @packs[ean.to_s[4..11]]) && !a_ppac[:is_tier] ? a_ppac : {})
              prodno = ppac[:prodno] if ppac[:prodno] && !ppac[:prodno].empty?
              prodno = obj[:pharmacode] if obj[:chapter70]
              my_pack = @packs.values.find { |x| x[:iksnr].to_i == obj[:seq][:swissmedic_number5].to_i } if obj[:seq]
              if my_pack && !prodno
                prodno ||= my_pack[:prodno]
                puts "Setting prodno #{prodno} for #{ean13} #{my_pack[:sequence_name]}"
              end
              next unless prodno
              next if emitted_prodno.index(prodno)
              sequence ||= @articles.find { |x| x[:ean13].eql?(ean) }
              unless obj[:chapter70]
                next unless sequence && (sequence[:name_de] || sequence[:desc_de])
                if Oddb2xml.getEan13forProdno(prodno).size == 0 && !obj[:no8].eql?(Oddb2xml.getNo8ForEan13(ean))
                  puts "No item found for prodno #{prodno} no8 #{obj[:no8]} #{sequence[:name_de]}"
                  next
                end
              end
              emitted_prodno << prodno
              nr_products += 1
              xml.PRODUCT do
                xml.PRODNO prodno
                if sequence
                  xml.SALECD("A") # these products are always active!
                  name_de = "#{sequence[:name_de]} #{sequence[:desc_de]}".strip if sequence[:name_de]
                  name_de ||= if ppac && /stk/i.match(sequence[:desc_de])
                    ppac[:sequence_name]
                  else
                    sequence[:desc_de]
                  end
                  name_fr = "#{sequence[:name_fr]} #{sequence[:desc_fr]}".strip if sequence[:name_fr]
                  name_fr ||= (ppac && ppac[:sequence_name])
                  override(xml, prodno, :DSCR, name_de.strip)
                  override(xml, prodno, :DSCRF, name_fr.strip)
                  # use overriden ATC if possibel
                  atc = sequence[:atc] || sequence[:atc_code]
                  xml.ATC atc if atc && !atc.empty?
                end
                if sequence && sequence[:packages] && (first_package = sequence[:packages].values.first) &&
                    (first_limitation = first_package[:limitations].first)
                  lim_code = first_limitation[:code]
                  used_limitations << lim_code unless used_limitations.index(lim_code)
                  xml.LIMNAMEBAG lim_code
                elsif obj[:chapter70]
                  xml.comment "Chapter70 hack prodno #{prodno} #{obj[:description].encode(xml: :text).gsub("--", "-")}"
                  xml.SALECD("A") # these products are always active!
                  xml.DSCR obj[:description]
                  xml.DSCRF ""
                  if @limitations.index(obj[:code])
                    xml.LIMNAMEBAG obj[:code]
                    used_limitations << obj[:code]
                  end
                end
                if sequence && sequence[:substances]
                  value = if sequence[:substances].size > 1
                    "Verschiedene Kombinationen"
                  elsif sequence[:substances].first
                    sequence[:substances].first[:name]
                  else
                    obj[:sub]
                  end
                  override(xml, prodno, :SUBSTANCE, value) if value
                end
              end
            end
          end
          emitted_lim_code = []
          xml.LIMITATIONS do
            @limitations.sort! { |left, right| left[:code] <=> right[:code] }
            @limitations.each do |lim|
              unless lim[:chap70]
                next unless used_limitations.index(lim[:code])
                next if emitted_lim_code.index(lim[:code])
              end
              emitted_lim_code << lim[:code]
              xml.LIMITATION do
                xml.comment "Chapter70 2 hack" if lim[:chap70]
                xml.LIMNAMEBAG lim[:code] # original LIMCD
                xml.DSCR Oddb2xml.html_decode(lim[:desc_de])
                xml.DSCRF Oddb2xml.html_decode(lim[:desc_fr])
                xml.LIMITATION_PTS(lim[:value].to_s.length > 1 ? lim[:value] : 1)
              end
            end
          end
          xml.ITEMS do
            nr_articles = emit_items(xml)
          end
        end
      end
      Oddb2xml.log "#{variant}. Done #{nr_products} of #{@products.size} products, #{@limitations.size} limitations and #{nr_articles}/#{@nr_articles} articles. @@emitted_v5_gtins #{@@emitted_v5_gtins.size}"
      # we don't add a SHA256 hash for each element in the article
      # Oddb2xml.add_hash(a_builder.to_xml)
      # doc = REXML::Document.new( source, { :raw => :all })
      # doc.write( $stdout, 0 )
      lines = []
      lines << "  - #{sprintf("%5d", @products.size)} products"
      lines << "  - #{sprintf("%5d", @limitations.size)} limitations"
      lines << "  - #{sprintf("%5d", @nr_articles)} articles"
      lines << "  - #{sprintf("%5d", @@gtin2ignore.size)} ignored GTINS"
      @@articlestamm_v5_info_lines = lines
      a_builder.to_xml({indent: 4, encoding: "UTF-8"})
    end

    private_class_method
    def self.articlestamm_v5_info_lines
      @@articlestamm_v5_info_lines
    end
  end
end
