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
                  :infos, :packs,
                  :ean14, :tag_suffix
    def initialize
      @subject    = nil
      @index      = {}
      @items      = {}
      @flags      = {}
      @lppvs      = {}
      @infos      = {}
      @packs      = {}
      @migel      = {}
      @actions    = []
      @orphans    = []
      @fridges    = []
      @ean14      = true
      @tag_suffix = nil
      if block_given?
        yield self
      end
    end
    def to_xml(subject=nil)
      if subject
        self.send('build_' + subject.to_s)
      elsif @subject
        self.send('build_' + @subject.to_s)
      end
    end
    def to_dat(subject=nil)
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
            }
            obj[lang.intern] = [entry]
          end
          @articles << obj
        end
      end
    end
    def prepare_substances
      unless @substances
        @substances = []
        @items.values.uniq.each do |seq|
          seq[:substances].each do |sub|
            @substances << sub[:name]
          end
        end
        @substances.uniq!
        @substances.sort!
      end
    end
    def prepare_limitations
      unless @limitations
        @limitations = []
        @items.values.uniq.each do |seq|
          seq[:packages].each_value do |pac|
            @limitations += pac[:limitations]
          end
        end
        # ID is no longer fixed TAG (swissmedicNo8, swissmedicNo5, pharmacode)
        # limitation.xml needs all duplicate entries by this keys.
        @limitations.uniq! {|lim| lim[:id] + lim[:code] + lim[:type] }
        @limitations.sort_by!{|lim| lim[:code] }
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
            obj = {}
            obj = {
              :ean => index[:ean],
              :atc => index[:atc_code],
              # additional tags
              :ith => '',
              :seq => @items[phar],
              :pac => nil,
              :no8 => nil,
              :de  => index,
              :fr  => @index['FR'][phar][i],
              :st  => index[:status],
            }
            if obj[:seq] and obj[:pac] = obj[:seq][:packages][phar]
              obj[:no8] = obj[:pac][:swissmedic_number8].to_s
              obj[:atc] = obj[:pac][:atc_code].to_s
              obj[:ith] = obj[:pac][:it_code].to_s # first one
              unless obj[:ean]
                if obj[:no8] and ppac = @packs[obj[:no8].intern] # Packungen.xls
                  obj[:ean] = ppac[:ean].to_s
                  obj[:atc] = ppac[:atc_code].to_s
                  obj[:ith] = ppac[:ith_swissmedic].to_s
                  obj[:st]  = 'I'
                end
              end
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
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.SUBSTANCE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          @substances.each_with_index do |sub_name, i|
            xml.SB('DT' => '') {
              xml.SUBNO (i + 1).to_i
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
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.LIMITATION(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          @limitations.each do |lim|
            xml.LIM('DT' => '') {
              case lim[:key]
              when :swissmedic_number8
                xml.SwissmedicNo8 lim[:id]
              when :swissmedic_number5
                xml.SwissmedicNo5 lim[:id]
              when :pharmacode
                xml.Pharmacode lim[:id]
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
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.INTERACTION(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
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
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.CODE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
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
              xml.DEL false
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
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.PRODUCT(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          list = []
          length = 0
          @products.each do |obj|
            seq = obj[:seq]
            next unless seq # option
            length += 1
            xml.PRD('DT' => '') {
              xml.GTIN obj[:ean].to_s
              if seq
                %w[de fr].each do |l|
                  name = "name_#{l}".intern
                  desc = "desc_#{l}".intern
                  elem = "DSCR" + l[0].upcase
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
                      xml.SUBNO @substances.index(sub[:name]) + 1 if @substances.include?(sub[:name])
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
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.ARTICLE(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          @articles.each do |obj|
            obj[:de].each_with_index do |de_idx, i|
              fr_idx = obj[:fr][i] # swiss index FR
              pac,no8 = nil,nil    # BAG XML (additional data)
              ppac = nil           # Packungen
              if obj[:seq]
                pac = obj[:seq][:packages][de_idx[:pharmacode]]
                if pac
                  no8  = pac[:swissmedic_number8].intern
                  ppac = @packs[no8]
                end
              end
              xml.ART('DT' => '') {
                xml.PHAR  de_idx[:pharmacode] unless de_idx[:pharmacode].empty?
                #xml.GRPCD
                #xml.CDS01
                #xml.CDS02
                #xml.PRDNO
                if pac
                  if !pac[:swissmedic_category].empty?
                    xml.SMCAT pac[:swissmedic_category]
                  elsif ppac && ppac[:swissmedic_category]
                    xml.SMCAT ppac[:swissmedic_category]
                  end
                end
                if pac
                  xml.SMNO no8.to_s unless no8.to_s.empty?
                end
                #xml.HOSPCD
                #xml.CLINCD
                #xml.ARTTYP
                #xml.VAT
                if de_idx
                  xml.SALECD de_idx[:status].empty? ? 'N' : de_idx[:status]
                end
                if pac
                  #xml.INSLIM
                  xml.LIMPTS pac[:limitation_points] unless pac[:limitation_points].empty?
                end
                #xml.GRDFR
                if pac
                  if no8.empty? and
                     no8.to_s =~ /(\d{5})(\d{3})/
                    xml.COOL 1 if @fridges.include?($1.to_s)
                  end
                end
                #xml.TEMP
                unless de_idx[:ean].empty?
                  flag = @flags[de_idx[:ean]]
                  # as same flag
                  xml.CDBG (flag ? 'Y' : 'N')
                  xml.BG   (flag ? 'Y' : 'N')
                end
                #xml.EXP
                xml.QTY   de_idx[:additional_desc] unless de_idx[:additional_desc].empty?
                xml.DSCRD de_idx[:desc]            unless de_idx[:desc].empty?
                xml.DSCRF fr_idx[:desc]            unless fr_idx[:desc].empty?
                xml.SORTD de_idx[:desc].upcase     unless de_idx[:desc].empty?
                xml.SORTF fr_idx[:desc].upcase     unless fr_idx[:desc].empty?
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
                if de_idx[:status] == "I"
                  xml.OUTSAL de_idx[:stat_date] unless de_idx[:stat_date].empty?
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
                  xml.COMPNO de_idx[:company_ean] unless de_idx[:company_ean].empty?
                  #xml.ROLE
                  #xml.ARTNO1
                  #xml.ARTNO2
                  #xml.ARTNO3
                }
                xml.ARTBAR {
                  xml.CDTYP  'E13'
                  xml.BC     de_idx[:ean] unless de_idx[:ean].empty?
                  xml.BCSTAT 'A' # P is alternative
                  #xml.PHAR2
                }
                #xml.ARTCH {
                  #xml.PHAR2
                  #xml.CHTYPE
                  #xml.LINENO
                  #xml.NOUNITS
                #}
                if pac
                  pac[:prices].each_pair do |key, price|
                    xml.ARTPRI {
                     xml.VDAT  price[:valid_date] unless price[:valid_date].empty?
                     xml.PTYP  price[:price_code] unless price[:price_code].empty?
                     xml.PRICE price[:price]      unless price[:price].empty?
                    }
                  end
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
                if @lppvs[de_idx[:ean]]
                  xml.ARTINS {
                    #xml.VDAT
                    #xml.INCD
                    xml.NINCD 20
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
      _builder.to_xml
    end
    def build_fi
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.tag_suffix = @tag_suffix
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.KOMPENDIUM(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          length = 0
          %w[de fr].each do |lang|
            length += @infos[lang].length
            @infos[lang].each do |info|
              xml.KMP(
                'MONTYPE' => 'fi', # only
                'LANG'    => lang.upcase,
                'DT'      => '',
              ) {
                unless info[:name].empty?
                  xml.name { xml.p info[:name] }
                end
                unless info[:owner].empty?
                  xml.owner { xml.p info[:owner] }
                end
                xml.monid info[:monid] unless info[:monid].empty?
                xml.paragraph { xml.cdata info[:paragraph] unless info[:paragraph].empty? }
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
        datetime = Time.new.strftime('%FT%T.%7N%z')
        xml.KOMPENDIUM_PRODUCT(
          'xmlns:xsd'         => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'         => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'             => 'http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration',
          'CREATION_DATETIME' => datetime,
          'PROD_DATE'         => datetime,
          'VALID_DATE'        => datetime,
        ) {
          length = 0
          info_index = {}
          %w[de fr].each do |lang|
            @infos[lang].each_with_index do |info, i|
              info_index[info[:monid]] = i
            end
          end
          @products.select{|obj| obj[:seq] }.
            group_by{|obj| obj[:seq][:swissmedic_number5] }.each_pair do |monid, products|
            if info_index[monid]
              xml.KP('DT' => '') {
                xml.MONID monid
                products.each do |obj|
                  xml.GTIN obj[:ean]
                  length += 1
                end
                # as orphans ?
                xml.DEL @orphans.include?(monid) ? true : false
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

    ### --- see oddb2tdat
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
    def build_dat
      prepare_articles
      rows = []
      @articles.each do |obj|
        obj[:de].each_with_index do |idx, i|
          row = ''
          # Oddb2tdat.parse
          if idx[:status] =~ /A|I/
            pac,no8 = nil,nil
            if obj[:seq]
              pac = obj[:seq][:packages][idx[:pharmacode]]
            end
            # :swissmedic_numbers
            if pac
              no8 = pac[:swissmedic_number8].intern
            end
            row << "%#{DAT_LEN[:RECA]}s"  % '11'
            row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = idx[:pharmacode] and phar.size > 3) # does not check expiration_date
                                              idx[:status] == "I" ? '3' : '1'
                                            else
                                              '3'
                                            end
            row << "%0#{DAT_LEN[:PHAR]}d" % idx[:pharmacode].to_i
            row << "%-#{DAT_LEN[:ABEZ]}s" % (
                                              idx[:desc].to_s.gsub(/"/, '') + " " +
                                              (pac ? pac[:name_de].to_s : '') +
                                              idx[:additional_desc]
                                            ).to_s[0, DAT_LEN[:ABEZ]].gsub(/"/, '')
            row << "%#{DAT_LEN[:PRMO]}s"  % (pac ? format_price(pac[:prices][:exf_price][:price].to_s) : ('0' * DAT_LEN[:PRMO]))
            row << "%#{DAT_LEN[:PRPU]}s"  % (pac ? format_price(pac[:prices][:pub_price][:price].to_s) : ('0' * DAT_LEN[:PRPU]))
            row << "%#{DAT_LEN[:CKZL]}s"  % if (@lppvs[idx[:ean]])
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
                                                (@flags[idx[:ean]]))                   # ywesee BM_update
                                              '3'
                                            else
                                              '0'
                                            end
            row << "%#{DAT_LEN[:CIKS]}s"  % if (pac && pac[:swissmedic_category] =~ /^[ABCDE]$/) # BAGXml
                                              pac[:swissmedic_category]
                                            elsif (no8 && @packs[no8])                           # Packungen.xls
                                              @packs[no8][:swissmedic_category]
                                            else
                                              '0'
                                            end.gsub(/(\+|\s)/, '')
            row << "%0#{DAT_LEN[:ITHE]}d" % if (no8 && @packs[no8])
                                              format_date(@packs[no8][:ith_swissmedic])
                                            else
                                              ('0' * DAT_LEN[:ITHE])
                                            end.to_i
            row << "%0#{DAT_LEN[:CEAN]}d" % idx[:ean].to_i
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
          next if (!ean14 && idx[:ean].to_s.length != 13)
          # Oddb2tdat.parse_migel
          row << "%#{DAT_LEN[:RECA]}s"  % '11'
          row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = idx[:pharmacode] and phar.size > 3)
                                            '1'
                                          else
                                            '3'
                                          end
          row << "%0#{DAT_LEN[:PHAR]}d" % idx[:pharmacode].to_i
          row << "%-#{DAT_LEN[:ABEZ]}s" % (
                                            idx[:desc].to_s.gsub(/"/, '') + " " +
                                            idx[:additional_desc]
                                          ).to_s[0, DAT_LEN[:ABEZ]].gsub(/"/, '')
          row << "%#{DAT_LEN[:PRMO]}s"  % ('0' * DAT_LEN[:PRMO])
          row << "%#{DAT_LEN[:PRPU]}s"  % ('0' * DAT_LEN[:PRPU])
          row << "%#{DAT_LEN[:CKZL]}s"  % '3' # sl_entry and lppv
          row << "%#{DAT_LEN[:CLAG]}s"  % '0'
          row << "%#{DAT_LEN[:CBGG]}s"  % '0'
          row << "%#{DAT_LEN[:CIKS]}s"  % ' ' # no category
          row << "%0#{DAT_LEN[:ITHE]}d" %  0
          row << "%0#{DAT_LEN[:CEAN]}d" % (idx[:ean] ? idx[:ean].to_i : 0)
          row << "%#{DAT_LEN[:CMWS]}s"  % '1' # nonpharma
          rows << row
        end
      end
      rows.join("\n")
    end
  end
end
