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
    attr_accessor :subject, :index, :items, :flags,
                  :actions,
                  :orphans, :fridges,
                  :infos, :packs, :ean14,
                  :tag_suffix
    def initialize
      @subject    = nil
      @index      = {}
      @items      = {}
      @flags      = {}
      @infos      = {}
      @packs      = {}
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
        @index['DE'].each_pair do |pharmacode, index|
          object = {
            :de => index,
            :fr => @index['FR'][pharmacode],
          }
          if seq = @items[pharmacode]
            object[:seq] = seq
          end
          @articles << object
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
        @limitations.uniq! {|lim| lim[:code] + lim[:type] }
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
        # merge company info from swissINDEX
        @products = []
        @products = @items.values.uniq.map do |seq|
          %w[de fr].each do |lang|
            name_key = "company_name_#{lang}".intern
            seq[name_key] = ''
            if pharmacode = seq[:pharmacodes].first
              indices = @index[lang.upcase]
              if index = indices[pharmacode]
                seq[name_key] = index[:company_name]
              end
            end
          end
          seq
        end
      end
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
              xml.LIMCD  lim[:key] # swissmedic_number8 or swissmedic_number5
              xml.IT     lim[:it]
              xml.LIMTYP lim[:type]
              xml.LIMVAL lim[:value]
              xml.LIMNAMEBAG lim[:code] # LIMCD
              xml.LIMNIV lim[:niv]
              xml.DSCRD  lim[:desc_de]
              xml.DSCRF  lim[:desc_fr]
              xml.VDAT   lim[:vdate]
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
          @products.each do |seq|
            xml.PRD('DT' => '') {
              xml.PRDNO seq[:product_key] unless seq[:product_key].empty?
              %w[de fr].each do |l|
                name = "name_#{l}".intern
                desc = "desc_#{l}".intern
                elem = "DSCR" + l[0].upcase
                if !seq[name].empty? and !seq[desc].empty?
                  xml.send(elem, seq[name] + ' ' + seq[desc])
                elsif !seq[desc].empty?
                  xml.send(elem, seq[desc])
                end
              end
              #xml.BNAMD
              #xml.BNAMF
              #xml.ADNAMD
              #xml.ADNAMF
              #xml.SIZE
              xml.ADINFD seq[:comment_de]   unless seq[:comment_de].empty?
              xml.ADINFF seq[:comment_fr]   unless seq[:comment_fr].empty?
              xml.GENCD  seq[:org_gen_code] unless seq[:org_gen_code].empty?
              #xml.GENGRP
              xml.ATC    seq[:atc_code]     unless seq[:atc_code].empty?
              xml.IT     seq[:it_code]      unless seq[:it_code].empty?
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
              seq[:packages].values.first[:swissmedic_number8] =~ /(\d{5})(\d{3})/
              xml.ORPH @orphans.include?($1.to_s) ? true : false
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
            xml.NBR_RECORD @products.length.to_s
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
            de_pac = obj[:de] # swiss index DE (base)
            fr_pac = obj[:fr] # swiss index FR
            bg_pac = nil      # BAG XML (additional data)
            if obj[:seq]
              bg_pac = obj[:seq][:packages][de_pac[:pharmacode]]
            end
            xml.ART('DT' => '') {
              xml.PHAR  de_pac[:pharmacode] unless de_pac[:pharmacode].empty?
              #xml.GRPCD
              #xml.CDS01
              #xml.CDS02
              if obj[:seq]
                xml.PRDNO obj[:seq][:product_key] unless obj[:seq][:product_key].empty?
              end
              if bg_pac
                xml.SMCAT bg_pac[:swissmedic_category] unless bg_pac[:swissmedic_category].empty?
                xml.SMNO  bg_pac[:swissmedic_number8]  unless bg_pac[:swissmedic_number8].empty?
              end
              #xml.HOSPCD
              #xml.CLINCD
              #xml.ARTTYP
              #xml.VAT
              if de_pac
                xml.SALECD de_pac[:status].empty? ? 'N' : de_pac[:status]
              end
              if bg_pac
                #xml.INSLIM
                xml.LIMPTS bg_pac[:limitation_points] unless bg_pac[:limitation_points].empty?
              end
              #xml.GRDFR
              if bg_pac
                if !bg_pac[:swissmedic_number8].empty? and
                   bg_pac[:swissmedic_number8].to_s =~ /(\d{5})(\d{3})/
                  xml.COOL 1 if @fridges.include?($1.to_s)
                end
              end
              #xml.TEMP
              unless de_pac[:ean].empty?
                flag = @flags[de_pac[:ean]]
                # as same flag
                xml.CDBG (flag ? 'Y' : 'N')
                xml.BG   (flag ? 'Y' : 'N')
              end
              #xml.EXP
              xml.QTY   de_pac[:additional_desc] unless de_pac[:additional_desc].empty?
              xml.DSCRD de_pac[:desc]            unless de_pac[:desc].empty?
              xml.DSCRF fr_pac[:desc]            unless fr_pac[:desc].empty?
              xml.SORTD de_pac[:desc].upcase     unless de_pac[:desc].empty?
              xml.SORTF fr_pac[:desc].upcase     unless fr_pac[:desc].empty?
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
              if de_pac[:status] == "I"
                xml.OUTSAL de_pac[:stat_date] unless de_pac[:stat_date].empty?
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
                xml.COMPNO de_pac[:company_ean] unless de_pac[:company_ean].empty?
                #xml.ROLE
                #xml.ARTNO1
                #xml.ARTNO2
                #xml.ARTNO3
              }
              xml.ARTBAR {
                xml.CDTYP  'E13'
                xml.BC     de_pac[:ean] unless de_pac[:ean].empty?
                xml.BCSTAT 'A' # P is alternative
                #xml.PHAR2
              }
              #xml.ARTCH {
                #xml.PHAR2
                #xml.CHTYPE
                #xml.LINENO
                #xml.NOUNITS
              #}
              if bg_pac
                bg_pac[:prices].each_pair do |key, price|
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
              if bg_pac
                bg_pac[:limitations].each do |lim|
                  xml.ARTLIM {
                    xml.LIMCD lim[:code] unless lim[:code].empty?
                  }
                end
              end
              #xml.ARTINS {
                #xml.VDAT
                #xml.INCD
                #xml.NINCD
              #}
            }
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
            @infos[lang].each_with_index do |info, i|
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
          %w[de fr].each do |lang|
            info_index = {}
            @infos[lang].each_with_index do |info, i|
              info_index[info[:monid]] = i
            end
            # prod
            @products.each do |seq|
              seq[:packages].values.each do |pac|
                if pac[:swissmedic_number8] =~ /(\d{5})(\d{3})/
                  number = $1.to_s
                  if i = info_index[number]
                    length += 1
                    xml.KP('DT' => '') {
                      xml.MONID @infos[lang][i][:monid]
                      xml.PRDNO seq[:product_key] unless seq[:product_key].empty?
                      # as orphans ?
                      xml.DEL   @orphans.include?(number) ? true : false
                    }
                  end
                end
              end
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
        row = ''
        de_pac = obj[:de]
        # Oddb2tdat.parse
        if obj[:de][:status] =~ /A|I/
          pac,num = nil, nil
          if obj[:seq]
            pac = obj[:seq][:packages][de_pac[:pharmacode]]
          end
          # :swissmedic_numbers
          if de_pac[:ean].length == 13
            num =  de_pac[:ean][4,8].intern # :swissmedic_number5
          elsif pac
            num = pac[:swissmedic_number8].intern
          end
          row << "%#{DAT_LEN[:RECA]}s"  % '11'
          row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = de_pac[:pharmacode] and phar.size > 3) # does not check expiration_date
                                            obj[:de][:status] == "I" ? '3' : '1'
                                          else
                                            '3'
                                          end
          row << "%0#{DAT_LEN[:PHAR]}d" % de_pac[:pharmacode].to_i
          row << "%-#{DAT_LEN[:ABEZ]}s" % (
                                            de_pac[:desc].to_s.gsub(/"/, '') + " " +
                                            (pac ? pac[:name_de].to_s : '') +
                                            de_pac[:additional_desc]
                                          ).to_s[0, DAT_LEN[:ABEZ]].gsub(/"/, '')
          row << "%#{DAT_LEN[:PRMO]}s"  % (pac ? format_price(pac[:prices][:exf_price][:price].to_s) : ('0' * DAT_LEN[:PRMO]))
          row << "%#{DAT_LEN[:PRPU]}s"  % (pac ? format_price(pac[:prices][:pub_price][:price].to_s) : ('0' * DAT_LEN[:PRPU]))
          row << "%#{DAT_LEN[:CKZL]}s"  % (pac ? '1' : '3') # sl_entry or not
          row << "%#{DAT_LEN[:CLAG]}s"  % if ((num && num.to_s =~ /(\d{5})(\d{3})/) and
                                              @fridges.include?($1.to_s))
                                            '1'
                                          else
                                            '0'
                                          end
          row << "%#{DAT_LEN[:CBGG]}s"  % if ((pac && pac[:narcosis_flag] == 'Y') or           # BAGXml
                                              (@flags[de_pac[:ean]]))                          # ywesee BM_update
                                            '3'
                                          else
                                            '0'
                                          end
          row << "%#{DAT_LEN[:CIKS]}s"  % if (pac && pac[:swissmedic_category] =~ /^[ABCDE]$/) # BAGXml
                                            pac[:swissmedic_category]
                                          elsif (@packs[num])                                  # Packungen.xls
                                            @packs[num][:swissmedic_category]
                                          else
                                            '0'
                                          end.gsub(/(\+|\s)/, '')
          row << "%0#{DAT_LEN[:ITHE]}d" % if (@packs[num])
                                            format_date(@packs[num][:ith_swissmedic])
                                          else
                                            ('0' * DAT_LEN[:ITHE])
                                          end.to_i
          row << "%0#{DAT_LEN[:CEAN]}d" % de_pac[:ean].to_i
          row << "%#{DAT_LEN[:CMWS]}s"  % '2' # pharma
          rows << row
        end
      end
      rows.join("\n")
    end
    def build_with_migel_dat
      reset = true
      prepare_articles(reset)
      rows = []
      @articles.each do |obj|
        row = ''
        de_pac = obj[:de]
        next if (!ean14 && de_pac[:ean].to_s.length != 13)
        # Oddb2tdat.parse_migel
        row << "%#{DAT_LEN[:RECA]}s"  % '11'
        row << "%#{DAT_LEN[:CMUT]}s"  % if (phar = de_pac[:pharmacode] and phar.size > 3)
                                          '1'
                                        else
                                          '3'
                                        end
        row << "%0#{DAT_LEN[:PHAR]}d" % de_pac[:pharmacode].to_i
        row << "%-#{DAT_LEN[:ABEZ]}s" % (
                                          de_pac[:desc].to_s.gsub(/"/, '') + " " +
                                          de_pac[:additional_desc]
                                        ).to_s[0, DAT_LEN[:ABEZ]].gsub(/"/, '')
        row << "%#{DAT_LEN[:PRMO]}s"  % ('0' * DAT_LEN[:PRMO])
        row << "%#{DAT_LEN[:PRPU]}s"  % ('0' * DAT_LEN[:PRPU])
        row << "%#{DAT_LEN[:CKZL]}s"  % '3' # sl_entry and lppv
        row << "%#{DAT_LEN[:CLAG]}s"  % '0'
        row << "%#{DAT_LEN[:CBGG]}s"  % '0'
        row << "%#{DAT_LEN[:CIKS]}s"  % ' ' # no category
        row << "%0#{DAT_LEN[:ITHE]}d" %  0
        row << "%0#{DAT_LEN[:CEAN]}d" % (de_pac[:ean] ? de_pac[:ean].to_i : 0)
        row << "%#{DAT_LEN[:CMWS]}s"  % '1' # nonpharma
        rows << row
      end
      rows.join("\n")
    end
  end
end
