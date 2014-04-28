# encoding: utf-8

require 'nokogiri'
module Nokogiri
  module XML
    class Document < Nokogiri::XML::Node
      attr_writer :tag_suffix
      alias :create_element_origin :create_element
      def create_element name, *args, &block
        name += (@tag_suffix || '')
        create_element_origin(name, *args, &block)
      end
    end
  end
end

module Oddb2xml
  class Builder
    attr_accessor :subject, :index, :items, :flags, :lppvs,
                  :actions, :migel, :orphans, :fridges,
                  :infos, :packs, :prices,
                  :ean14, :tag_suffix,
                  :companies, :people
    def initialize(args = {})
      @options    = args
      @subject    = nil
      @index      = {}
      @items      = {}
      @flags      = {}
      @lppvs      = {}
      @infos      = {}
      @packs      = {}
      @migel      = {}
      @prices     = {} # zurrose
      @actions    = []
      @orphans    = []
      @fridges    = []
      @ean14      = false
      @companies  = []
      @people     = []
      @tag_suffix = nil
      if block_given?
        yield self
      end
    end
    def to_xml(subject=nil)
      Oddb2xml.log "to_xml subject #{subject ? subject.to_s :  @subject.to_s} for #{self.class}"
      if subject
        self.send('build_' + subject.to_s)
      elsif @subject
        self.send('build_' + @subject.to_s)
      end
    end
    def to_dat(subject=nil)
      Oddb2xml.log  "to_dat subject #{subject ? subject.to_s :  @subject.to_s} for #{self.class}"
      if subject
        self.send('build_' + subject.to_s)
      elsif @subject
        self.send('build_' + @subject.to_s)
      end
    end
    private
    def prepare_articles(reset=false)
      @articles = nil if reset
      unless @articles
        Oddb2xml.log("prepare_articles starting with #{@articles ? @articles.size : 'no'} articles")
        @articles = [] # base is 'DE'
        @index['DE'].each_pair do |phar, indices|
          obj = {
            :de => indices,
            :fr => @index['FR'][phar],
          }
          if migel = @migel[phar]
            # delete duplicates
            @migel[phar] = nil
          end
          if seq = @items[phar]
            obj[:seq] = seq
          end
          @articles << obj
        end
        # add
        @migel.values.compact.each do |migel|
          next if migel[:pharmacode].empty?
          obj = {}
          %w[de fr].each do |lang|
            entry = {
              :ean             => migel[:ean],
              :pharmacode      => migel[:pharmacode],
              :status          => 'I',
              :stat_date       => '',
              :lang            => lang.capitalize,
              :desc            => migel["desc_#{lang}".intern],
              :atc_code        => '',
              :additional_desc => migel[:additional_desc],
              :company_ean     => migel[:company_ean],
              :company_name    => migel[:company_name],
              :migel           => true,
            }
            obj[lang.intern] = [entry]
          end
          @articles << obj
        end
        nrAdded = 0
        if @options[:extended]
          Oddb2xml.log("prepare_articles prepare_local_index")
          local_index = {}
          %w[de fr].each { |lang| local_index[lang] = {} }
          %w[de fr].each {
            |lang|
          @articles.each{|article|
                         ean = article[lang.intern][0][:ean]
                                                       next if ean == nil or ean.to_i == 0
                                                      local_index[lang][ean] = article
                                                      }
                                                      }
          Oddb2xml.log("prepare_articles extended")
          @prices.each{
            |ean13, info|
          obj = {}
          found = false
          %w[de fr].each do |lang|
          #              existing = @articles.find{|art| art[lang.intern] and art[lang.intern][0][:ean] == ean13 }
          existing = local_index[lang][ean13]
            if existing
              found = true
              existing[:price] = info[:price]
                                      existing[:pub_price] = info[:pub_price]
                      else
                      entry = {
                               :desc            => info[:description],
                               :status          => 'I', # or it will not be emitted in the dat
                              :atc_code        => '',
                               :ean             => ean13,
                               :lang            => lang.capitalize,
                               :pharmacode      => info[:pharmacode],
                               :price           => info[:price],
                               :pub_price       => info[:pub_price],
                               :type            => info[:type],
                               }
                      obj[lang.intern] = [entry]
                      @index[lang.upcase][ean13] = entry
                      end
                      end
                      unless found
                      @articles << obj
                      nrAdded += 1
                      end
                      }
          end
      end
      Oddb2xml.log("prepare_articles done. Added #{nrAdded} prices. Total #{@articles.size}")
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
        exit 2 if @options[:extended] and @substances.size == 0
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
        limitations.uniq! {|lim| lim[:id] + lim[:code] + lim[:type] }
        @limitations = limitations.sort_by {|lim| lim[:code] }
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
      unless @codes
        @codes = {
          'X' => {:int => 11, :txt => 'Kontraindiziert'},
          'E' => {:int => 12, :txt => 'Kontraindiziert'},
          'D' => {:int => 13, :txt => 'Kombination meiden'},
          'C' => {:int => 14, :txt => 'Monitorisieren'},
          'B' => {:int => 15, :txt => 'Vorsichtsmassnahmen'},
          'A' => {:int => 16, :txt => 'keine Massnahmen'}
        }
      end
    end
    def prepare_products
      unless @products
        @products = []
        @index['DE'].each_pair do |phar, indices|
          indices.each_with_index do |index, i|
            obj = {
              :seq => @items[phar],
              :pac => nil,
              :no8 => nil,
              :de  => index,
              :fr  => @index['FR'][phar][i],
              :st  => index[:status],
              # swissINDEX and Packungen.xls(if swissINDEX does not have EAN)
              :ean => index[:ean],
              :atc => index[:atc_code],
              :ith => '',
              :siz => '',
              :eht => '',
              :sub => '',
            }
            if obj[:ean] # via EAN-Code
              obj[:no8] = obj[:ean][4..11]
            end
            if obj[:no8] and ppac = @packs[obj[:no8].intern] and # Packungen.xls
               !ppac[:is_tier]
              # If swissINDEX does not have EAN
              if obj[:ean].nil? or obj[:ean].empty?
                obj[:ean] = ppac[:ean].to_s
              end
              # If swissINDEX dose not have ATC-Code
              if obj[:atc].nil? or obj[:atc].empty?
                obj[:atc] = ppac[:atc_code].to_s
              end
              obj[:ith] = ppac[:ith_swissmedic]
              obj[:siz] = ppac[:package_size]
              obj[:eht] = ppac[:einheit_swissmedic]
              obj[:sub] = ppac[:substance_swissmedic]
            end
            if obj[:ean][0..3] == '7680'
              @products << obj
            end
          end
        end
      end
      @products
    end
    def build_substance
      prepare_substances
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.SUBSTANCE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          Oddb2xml.log "build_substance #{@substances.size} substances"
        exit 2 if @options[:extended] and @substances.size == 0
        @substances.each_with_index do |sub_name, i|
            xml.SB('DT' => '') {
              xml.SUBNO((i + 1).to_i)
              #xml.NAMD
              #xml.ANAMD
              #xml.NAMF
              xml.NAML sub_name
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @substances.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_limitation
      prepare_limitations
      Oddb2xml.log "build_limitation #{@limitations.size} limitations"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.LIMITATION(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
        @limitations.each do |lim|
            xml.LIM('DT' => '') {
              case lim[:key]
              when :swissmedic_number8
                xml.SwissmedicNo8 lim[:id]
              when :swissmedic_number5
                xml.SwissmedicNo5 lim[:id]
              when :pharmacode
                xml.Pharmacode    lim[:id]
              end
              xml.IT         lim[:it]
              xml.LIMTYP     lim[:type]
              xml.LIMVAL     lim[:value]
              xml.LIMNAMEBAG lim[:code] # original LIMCD
              xml.LIMNIV     lim[:niv]
              xml.DSCRD      lim[:desc_de]
              xml.DSCRF      lim[:desc_fr]
              xml.VDAT       lim[:vdate]
              if lim[:del]
                xml.DEL 3
              end
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @limitations.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_interaction
      prepare_interactions
      prepare_codes
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.INTERACTION(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          Oddb2xml.log "build_interaction #{@interactions.size} interactions"
          @interactions.sort_by{|ix| ix[:ixno] }.each do |ix|
            xml.IX('DT' => '') {
              xml.IXNO  ix[:ixno]
              xml.TITD  ix[:title]
              #xml.TITF
              xml.GRP1D ix[:atc1]
              #xml.GRP1F
              xml.GRP2D ix[:atc2]
              #xml.GRP2F
              xml.EFFD  ix[:effect]
              #xml.EFFF
              if dict = @codes[ix[:grad].upcase]
                xml.RLV  dict[:int]
                xml.RLVD dict[:txt]
                #xml.RLVF
              end
              #xml.EFFTXTD
              #xml.EFFTXTF
              xml.MECHD ix[:mechanism]
              #xml.MECHF
              xml.MEASD ix[:measures]
              #xml.MEASF
              #xml.REMD
              #xml.REMF
              #xml.LIT
              xml.DEL false
              #xml.IXMCH {
              #  xml.TYP
              #  xml.TYPD
              #  xml.TYPF
              #  xml.CD
              #  xml.CDD
              #  xml.CDF
              #  xml.TXTD
              #  xml.TXTF
              #}
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @interactions.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_code
      prepare_codes
      Oddb2xml.log "build_code #{@codes.size} codes"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.CODE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          @codes.each_pair do |val, definition|
            xml.CD('DT' => '') {
              xml.CDTYP   definition[:int]
              xml.CDVAL   val
              xml.DSCRSD  definition[:txt]
              #xml.DSCRSF
              #xml.DSCRMD
              #xml.DSCRMF
              #xml.DSCRD
              #xml.DSCRF
              xml.DEL     false
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @codes.keys.length
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_product
      prepare_substances
      prepare_products
      prepare_interactions
      prepare_codes
      Oddb2xml.log "build_product #{@products.size} products"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.PRODUCT(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          list = []
          length = 0
          @products.each do |obj|
            seq = obj[:seq]
            length += 1
            xml.PRD('DT' => '') {
              ean = obj[:ean].to_s
              xml.GTIN ean
              ppac = ((_ppac = @packs[ean[4..11].intern] and !_ppac[:is_tier]) ? _ppac : {})
              unless ppac
                ppac = @packs.find{|pac| pac.ean == ean }.first
              end
              xml.PRODNO ppac[:prodno] if ppac[:prodno] and !ppac[:prodno].empty?
              if seq
                %w[de fr].each do |l|
                  name = "name_#{l}".intern
                  desc = "desc_#{l}".intern
                  elem = "DSCR" + l[0].chr.upcase
                  if !seq[name].empty? and !seq[desc].empty?
                    xml.send(elem, seq[name] + ' ' + seq[desc])
                  elsif !seq[desc].empty?
                    xml.send(elem, [desc])
                  end
                end
              end
              #xml.BNAMD
              #xml.BNAMF
              #xml.ADNAMD
              #xml.ADNAMF
              #xml.SIZE
              if seq
                xml.ADINFD seq[:comment_de]   unless seq[:comment_de].empty?
                xml.ADINFF seq[:comment_fr]   unless seq[:comment_fr].empty?
                xml.GENCD  seq[:org_gen_code] unless seq[:org_gen_code].empty?
              end
              #xml.GENGRP
              xml.ATC obj[:atc] unless obj[:atc].empty?
              xml.IT  obj[:ith] unless obj[:ith].empty?
              #xml.ITBAG
              #xml.KONO
              #xml.TRADE
              #xml.PRTNO
              #xml.MONO
              #xml.CDGALD
              #xml.CDGALF
              #xml.FORMD
              #xml.FORMF
              #xml.DOSE
              #xml.DOSEU
              #xml.DRGFD
              #xml.DRGFF
              obj[:no8] =~ /(\d{5})(\d{3})/
              if @orphans.include?($1.to_s)
                xml.ORPH true
              end
              #xml.BIOPHA
              #xml.BIOSIM
              #xml.BFS
              #xml.BLOOD
              #xml.MSCD # always empty
              #xml.DEL
              xml.CPT {
                #xml.CPTLNO
                #xml.CNAMED
                #xml.CNAMEF
                #xml.IDXIND
                #xml.DDDD
                #xml.DDDU
                #xml.DDDA
                #xml.IDXIA
                #xml.IXREL
                #xml.GALF
                #xml.DRGGRPCD
                #xml.PRBSUIT
                #xml.CSOLV
                #xml.CSOLVQ
                #xml.CSOLVQU
                #xml.PHVAL
                #xml.LSPNSOL
                #xml.APDURSOL
                #xml.EXCIP
                #xml.EXCIPQ
                #xml.EXCIPCD
                #xml.EXCIPCF
                #xml.PQTY
                #xml.PQTYU
                #xml.SIZEMM
                #xml.WEIGHT
                #xml.LOOKD
                #xml.LOOKF
                #xml.IMG2
                if seq
                  seq[:substances].each do |sub|
                    xml.CPTCMP {
                      xml.LINE  sub[:index]    unless sub[:index].empty?
                      xml.SUBNO(@substances.index(sub[:name]) + 1) if @substances.include?(sub[:name])
                      xml.QTY   sub[:quantity] unless sub[:quantity].empty?
                      xml.QTYU  sub[:unit]     unless sub[:unit].empty?
                      #xml.WHK
                    }
                  end
                  @interactions.each do |ix|
                    if [ix[:act1], ix[:act2]].include?(seq[:atc_code])
                      xml.CPTIX {
                        xml.IXNO ix[:ixno]
                        #xml.GRP
                        xml.RLV  @codes[ix[:grad]]
                      }
                    end
                  end
                end
                #xml.CPTROA {
                  #xml.SYSLOC
                  #xml.ROA
                #}
              }
              #xml.PRDICD { # currently empty
                #xml.ICD
                #xml.RTYP
                #xml.RSIG
                #xml.REMD
                #xml.REMF
              #}
              xml.PackGrSwissmedic    obj[:siz] unless obj[:siz].empty?
              xml.EinheitSwissmedic   obj[:eht] unless obj[:eht].empty?
              xml.SubstanceSwissmedic obj[:sub] unless obj[:sub].empty?
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_article
      prepare_limitations
      prepare_articles
      idx = 0
      Oddb2xml.log "build_article #{idx} of #{@articles.size} articles"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.ARTICLE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          @articles.each do |obj|
            idx += 1
        Oddb2xml.log "build_article #{idx} of #{@articles.size} articles" if idx % 500 == 0
        obj[:de].each_with_index do |de_idx, i|
              fr_idx = obj[:fr][i]              # swissindex FR
              pac,no8 = nil,de_idx[:ean][4..11] # BAG-XML(SL/LS)
              ppac = nil                        # Packungen
              ean = de_idx[:ean]
              ean = nil if ean.match(/^000000/)
              if obj[:seq]
                pac = obj[:seq][:packages][de_idx[:pharmacode]]
                pac = obj[:seq][:packages][ean] unless pac
              else
                pac = @items[ean][:packages][ean] if @items and ean and @items[ean] and @items[ean][:packages]
              end
              if no8
                ppac = ((_ppac = @packs[no8.intern] and !_ppac[:is_tier]) ? _ppac : nil)
              end
              price = nil
              if !@prices.empty? && ean && @prices[ean]
                price = @prices[ean] # zurrose
              end
              xml.ART('DT' => '') {
                xml.PHAR  de_idx[:pharmacode] unless de_idx[:pharmacode].empty?
                #xml.GRPCD
                #xml.CDS01
                #xml.CDS02
                if ppac
                  xml.SMCAT ppac[:swissmedic_category] unless ppac[:swissmedic_category].empty?
                end
                if no8 and !no8.to_s.empty?
                  if ean and ean[0..3] == "7680"
                    xml.SMNO no8.to_s
                  end
                end
                if ppac
                  xml.PRODNO ppac[:prodno] if ppac[:prodno] and !ppac[:prodno].empty?
                end
                #xml.HOSPCD
                #xml.CLINCD
                #xml.ARTTYP
                if price
                  xml.VAT price[:vat]
                end

                if de_idx
                  xml.SALECD(de_idx[:status].empty? ? 'N' : de_idx[:status])
                end
                if pac and pac[:limitation_points]
                  #xml.INSLIM
                  xml.LIMPTS pac[:limitation_points] unless pac[:limitation_points].empty?
                end
                #xml.GRDFR
                if no8 and !no8.empty? and
                   no8.to_s =~ /(\d{5})(\d{3})/
                  xml.COOL 1 if @fridges.include?($1.to_s)
                end
                #xml.TEMP
                if ean and not ean.empty?
                  flag = @flags[ean]
                  # as same flag
                  xml.CDBG(flag ? 'Y' : 'N')
                  xml.BG(flag ? 'Y' : 'N')
                end
                #xml.EXP
                xml.QTY   de_idx[:additional_desc] if de_idx[:additional_desc] and not de_idx[:additional_desc].empty?
                xml.DSCRD de_idx[:desc]            if de_idx[:desc] and not de_idx[:desc].empty?
                xml.DSCRF fr_idx[:desc]            if fr_idx[:desc] and not fr_idx[:desc].empty?
                xml.SORTD de_idx[:desc].upcase     if de_idx[:desc] and not de_idx[:desc].empty?
                xml.SORTF fr_idx[:desc].upcase     if fr_idx[:desc] and not fr_idx[:desc].empty?
                #xml.QTYUD
                #xml.QTYUF
                #xml.IMG
                #xml.IMG2
                #xml.PCKTYPD
                #xml.PCKTYPF
                #xml.MULT
                if obj[:seq]
                  xml.SYN1D obj[:seq][:name_de] unless obj[:seq][:name_de].empty?
                  xml.SYN1F obj[:seq][:name_fr] unless obj[:seq][:name_fr].empty?
                end
                if obj[:seq]
                  case obj[:seq][:deductible]
                  when 'Y'; xml.SLOPLUS 1; # 20%
                  when 'N'; xml.SLOPLUS 2; # 10%
                  else      xml.SLOPLUS '' # k.A.
                  end
                end
                #xml.NOPCS
                #xml.HSCD
                #xml.MINI
                #xml.DEPCD
                #xml.DEPOT
                #xml.BAGSL
                #xml.BAGSLC
                #xml.LOACD
                if de_idx[:status] == 'I'
                  xml.OUTSAL de_idx[:stat_date] if de_idx[:stat_date] and not de_idx[:stat_date].empty?
                end
                #xml.STTOX
                #xml.NOTI
                #xml.GGL
                #xml.CE
                #xml.SMDAT
                #xml.SMCDAT
                #xml.SIST
                #xml.ESIST
                #xml.BIOCID
                #xml.BAGNO
                #xml.LIGHT
                #xml.DEL
                xml.ARTCOMP {
                  # use ean13(gln) as COMPNO
                  xml.COMPNO de_idx[:company_ean] if de_idx[:company_ean] and not de_idx[:company_ean].empty?
                  #xml.ROLE
                  #xml.ARTNO1
                  #xml.ARTNO2
                  #xml.ARTNO3
                }
                xml.ARTBAR {
                  xml.CDTYP  'E13'
                  xml.BC     ean if ean and not ean.empty?
                  xml.BCSTAT 'A' # P is alternative
                  #xml.PHAR2
                }
                #xml.ARTCH {
                  #xml.PHAR2
                  #xml.CHTYPE
                  #xml.LINENO
                  #xml.NOUNITS
                #}
                if pac and pac[:prices]
                  pac[:prices].each_pair do |key, price|
                    xml.ARTPRI {
                     xml.VDAT  price[:valid_date] unless price[:valid_date].empty?
                     xml.PTYP  price[:price_code] unless price[:price_code].empty?
                     xml.PRICE price[:price]      unless price[:price].empty?
                    }
                  end
                end
                if price
                  xml.ARTPRI {
                    xml.VDAT  Time.parse(datetime).strftime("%d.%m.%Y")
                    xml.PTYP  "ZURROSE"
                    xml.PRICE price[:price]
                  }
                  xml.ARTPRI {
                    xml.VDAT  Time.parse(datetime).strftime("%d.%m.%Y")
                    xml.PTYP  "ZURROSEPUB"
                    xml.PRICE price[:pub_price]
                  }
                end
                #xml.ARTMIG {
                  #xml.VDAT
                  #xml.MIGCD
                  #xml.LINENO
                #}
                #xml.ARTDAN {
                  #xml.CDTYP
                  #xml.LINENO
                  #xml.CDVAL
                #}
                #xml.ARTLIM {
                #  xml.LIMCD
                #}
                if nincd = detect_nincd(de_idx)
                  xml.ARTINS {
                    #xml.VDAT
                    #xml.INCD
                    xml.NINCD nincd
                  }
                end
              }
            end
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @articles.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      Oddb2xml.log "build_article. Done #{idx} of #{@articles.size} articles"
      _builder.to_xml
    end
    def build_fi
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.KOMPENDIUM(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          length = 0
          %w[de fr].each do |lang|
            infos = @infos[lang].uniq {|i| i[:monid] }
            length += infos.length
            infos.each do |info|
              xml.KMP(
                'MONTYPE' => 'fi', # only
                'LANG'    => lang.upcase,
                'DT'      => ''
              ) {
                unless info[:name].empty?
                  xml.name  { xml.p(info[:name]) }
                end
                unless info[:owner].empty?
                  xml.owner { xml.p(info[:owner]) }
                end
                xml.monid     info[:monid]                    unless info[:monid].empty?
                xml.paragraph { xml.cdata(info[:paragraph]) } unless info[:paragraph].empty?
              }
            end
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD length
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_fi_product
      prepare_products
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.KOMPENDIUM_PRODUCT(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime
        ) {
          length = 0
          info_index = {}
          %w[de fr].each do |lang|
            @infos[lang].each_with_index do |info, i|
              info_index[info[:monid]] = i
            end
          end
          @products.group_by{|obj|
            obj[:no8].to_s[0..4] # swissmedic_number5
          }.each_pair do |monid, products|
            if info_index[monid]
              xml.KP('DT' => '') {
                xml.MONID monid
                products.each do |obj|
                  xml.GTIN obj[:ean]
                  length += 1
                end
                # as orphans ?
                xml.DEL(@orphans.include?(monid) ? true : false)
              }
            end
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD length
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_company
      Oddb2xml.log "build_company #{@companies.size} companies"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.Betriebe(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'VALID_DATE'        => datetime
        ) {
          @companies.each do |c|
            xml.Betrieb('DT' => '') {
              xml.GLN_Betrieb        c[:gln]           unless c[:gln].empty?
              xml.Betriebsname_1     c[:name_1]        unless c[:name_1].empty?
              xml.Betriebsname_2     c[:name_2]        unless c[:name_2].empty?
              xml.Strasse            c[:address]       unless c[:address].empty?
              xml.Nummer             c[:number]        unless c[:number].empty?
              xml.PLZ                c[:post]          unless c[:post].empty?
              xml.Ort                c[:place]         unless c[:place].empty?
              xml.Bewilligungskanton c[:region]        unless c[:region].empty?
              xml.Land               c[:country]       unless c[:country].empty?
              xml.Betriebstyp        c[:type]          unless c[:type].empty?
              xml.BTM_Berechtigung   c[:authorization] unless c[:authorization].empty?
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @companies.length
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_person
      Oddb2xml.log "build_person #{@people.size} persons"
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T%z')
        xml.Personen(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'VALID_DATE'        => datetime
        ) {
          @people.each do |p|
            xml.Person('DT' => '') {
              xml.GLN_Person         p[:gln]         unless p[:gln].empty?
              xml.Name               p[:last_name]   unless p[:last_name].empty?
              xml.Vorname            p[:first_name]  unless p[:first_name].empty?
              xml.PLZ                p[:post]        unless p[:post].empty?
              xml.Ort                p[:place]       unless p[:place].empty?
              xml.Bewilligungskanton p[:region]      unless p[:region].empty?
              xml.Land               p[:country]     unless p[:country].empty?
              xml.Bewilligung_Selbstdispensation p[:license] unless p[:license].empty?
              xml.Diplom             p[:certificate]   unless p[:certificate].empty?
              xml.BTM_Berechtigung   p[:authorization] unless p[:authorization].empty?
            }
          end
          xml.RESULT {
            xml.OK_ERROR   'OK'
            xml.NBR_RECORD @people.length
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def detect_nincd(de_idx)
      if @lppvs[de_idx[:ean]] # LPPV
        20
      elsif @items[de_idx[:pharmacode]] # BAG-XML (SL/LS)
        10
      elsif (de_idx[:migel] or # MiGel (xls)
             de_idx[:_type] == :nonpharma) # MiGel (swissindex)
        13
      else
        # fallback via EAN
        bag_entry_via_ean = @items.values.select do |i|
          next unless i[:packages]
          i[:packages].values.select {|_pac| _pac[:ean] == de_idx[:ean] }.length != 0
        end.length
        if bag_entry_via_ean > 0
          10
        else
          nil
        end
      end
    end

    ### --- see oddb2tdat
    DAT_LEN = {
      :RECA =>  2,
      :CMUT =>  1,
      :PHAR =>  7,
      :ABEZ => 50,
      :PRMO =>  6,
      :PRPU =>  6,
      :CKZL =>  1,
      :CLAG =>  1,
      :CBGG =>  1,
      :CIKS =>  1,
      :ITHE =>  7,
      :CEAN => 13,
      :CMWS =>  1,
    }
    def format_price(price_str, len=6, int_len=4, frac_len=2)
      price = price_str.split('.')
      pre = ''
      las = ''
      pre = "%0#{int_len}d" % (price[0] ? price[0] : '0')
      las = if price[1]
              if price[1].size < frac_len
                price[1] + "0"*(frac_len-price[2].to_s.size)
              else
                price[1][0,frac_len]
              end
            else
              '0'*frac_len
            end
      (pre.to_s + las.to_s)[0,len]
    end
    def format_date(date_str, len=7)
      date = date_str.gsub('.','')
      if date.size < len
        date = date + '0'*(len-date.size)
      end
      date[0,len]
    end
    def format_name(name)
      if RUBY_VERSION.to_f < 1.9 # for multibyte chars length support
        chars = name.scan(/./mu).to_a
        diff  = DAT_LEN[:ABEZ] - chars.length
        if diff > 0
          chars += Array.new(diff, ' ')
        elsif diff < 0
          chars = chars[0,DAT_LEN[:ABEZ]]
        end
        chars.to_s
      else
        name = name[0,DAT_LEN[:ABEZ]] if name.length > DAT_LEN[:ABEZ]
        "%-#{DAT_LEN[:ABEZ]}s" % name
      end
    end
    def build_dat
      prepare_articles
      rows = []
      @articles.each do |obj|
        obj[:de].each_with_index do |idx, i|
          ean = idx[:ean]
          next if ((ean.to_s.length != 13) and !ean14)
          next if idx[:type] == :nonpharma
          row = ''
          # Oddb2tdat.parse
          if idx[:status] =~ /A|I/
            pac,no8 = nil,nil
            if obj[:seq] and obj[:seq][:packages]
              pac = obj[:seq][:packages][idx[:pharmacode]]
              pac = obj[:seq][:packages][ean] unless pac
            else
              pac = @items[ean][:packages][ean] if @items and @items[ean] and @items[ean][:packages]
            end
             # :swissmedic_numbers
            if pac
              no8 = pac[:swissmedic_number8].intern
            end
            if pac and pac[:prices] == nil and no8
              ppac = ((ppac = @packs[no8.intern] and ppac[:is_tier]) ? ppac : nil)
              pac = ppac if ppac
            end
            row << "%#{DAT_LEN[:RECA]}s"  % '11'
            row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = idx[:pharmacode] and phar.size > 3) # does not check expiration_date
                                              idx[:status] == 'I' ? '3' : '1'
                                            else
                                              '3'
                                            end
            row << "%0#{DAT_LEN[:PHAR]}d" % idx[:pharmacode].to_i
            abez = ( # de name
              idx[:desc].to_s + " " +
              (pac ? pac[:name_de].to_s : '') +
              (idx[:additional_desc] ? idx[:additional_desc] : '')
            ).gsub(/"/, '')
            row << format_name(abez)
            row << "%#{DAT_LEN[:PRMO]}s"  % (pac ? format_price(pac[:prices][:exf_price][:price].to_s) : ('0' * DAT_LEN[:PRMO]))
            row << "%#{DAT_LEN[:PRPU]}s"  % (pac ? format_price(pac[:prices][:pub_price][:price].to_s) : ('0' * DAT_LEN[:PRPU]))
            row << "%#{DAT_LEN[:CKZL]}s"  % if (@lppvs[ean])
                                              '2'
                                            elsif pac # sl_entry
                                              '1'
                                            else
                                              '3'
                                            end
            row << "%#{DAT_LEN[:CLAG]}s"  % if ((no8 && no8.to_s =~ /(\d{5})(\d{3})/) and
                                                @fridges.include?($1.to_s))
                                              '1'
                                            else
                                              '0'
                                            end
            row << "%#{DAT_LEN[:CBGG]}s"  % if ((pac && pac[:narcosis_flag] == 'Y') or # BAGXml
                                                (@flags[ean]))                   # ywesee BM_update
                                              '3'
                                            else
                                              '0'
                                            end
            row << "%#{DAT_LEN[:CIKS]}s"  % if (no8 && @packs[no8] && !@packs[no8][:is_tier]) # Packungen.xls
                                              @packs[no8][:swissmedic_category]
                                            else
                                              '0'
                                            end.gsub(/(\+|\s)/, '')
            row << "%0#{DAT_LEN[:ITHE]}d" % if (no8 && @packs[no8] && !@packs[no8][:is_tier])
                                              format_date(@packs[no8][:ith_swissmedic])
                                            else
                                              ('0' * DAT_LEN[:ITHE])
                                            end.to_i
            row << "%0#{DAT_LEN[:CEAN]}d" % (ean.match(/^000000/) ? 0 : ean.to_i)
            row << "%#{DAT_LEN[:CMWS]}s"  % '2' # pharma
            rows << row
          end
        end
      end
      rows.join("\n")
    end
    def build_with_migel_dat
      reset = true
      prepare_articles(reset)
      rows = []
      @articles.each do |obj|
        obj[:de].each_with_index do |idx, i|
          row = ''
          next if ((idx[:ean].to_s.length != 13) and !ean14)
          # Oddb2tdat.parse_migel
          row << "%#{DAT_LEN[:RECA]}s"  % '11'
          row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = idx[:pharmacode] and phar.size > 3)
                                            '1'
                                          else
                                            '3'
                                          end
          row << "%0#{DAT_LEN[:PHAR]}d" % idx[:pharmacode].to_i
          abez = ( # de name
            idx[:desc].to_s + " " +
          (idx[:additional_desc] ? idx[:additional_desc] : '')
          ).gsub(/"/, '')
          row << format_name(abez)
          row << "%#{DAT_LEN[:PRMO]}s"  % ('0' * DAT_LEN[:PRMO])
          row << "%#{DAT_LEN[:PRPU]}s"  % ('0' * DAT_LEN[:PRPU])
          row << "%#{DAT_LEN[:CKZL]}s"  % '3' # sl_entry and lppv
          row << "%#{DAT_LEN[:CLAG]}s"  % '0'
          row << "%#{DAT_LEN[:CBGG]}s"  % '0'
          row << "%#{DAT_LEN[:CIKS]}s"  % ' ' # no category
          row << "%0#{DAT_LEN[:ITHE]}d" %  0
          row << idx[:ean].to_s.rjust(DAT_LEN[:CEAN], '0')
          row << "%#{DAT_LEN[:CMWS]}s"  % '1' # nonpharma
          rows << row
        end
      end
      rows.join("\n")
    end
  end
end
