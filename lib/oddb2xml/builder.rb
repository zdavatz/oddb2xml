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
    attr_accessor :subject, :index, :items, :orphans, :fridges,
                  :tag_suffix
    def initialize
      @subject    = nil
      @index      = {}
      @items      = {}
      @orphans    = []
      @fridges    = []
      @tag_suffix = nil
      if block_given?
        yield self
      end
    end
    def to_xml(subject=nil)
      if subject
        self.send('build_' + subject)
      elsif @subject
        self.send('build_' + @subject)
      end
    end
    private
    def build_substance
      @substances = []
      @items.values.uniq.each do |seq|
        seq[:substances].each do |sub|
          @substances << sub[:name]
        end
      end
      @substances.uniq!
      @substances.sort!
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
    def build_product
      # merge company info from swissINDEX
      objects = []
      objects = @items.values.uniq.map do |seq|
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
          objects.each do |seq|
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
              seq[:packages].values.first[:swissmedic_number] =~ /(\d{5})(\d{3})/
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
                #xml.CPTIX {
                  #xml.IXNO
                  #xml.GRP
                  #xml.RLV
                #}
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
            xml.NBR_RECORD objects.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
    def build_article
      objects = [] # base is 'DE'
      @index['DE'].each_pair do |pharmacode, index|
        object = {
          :de => index,
          :fr => @index['FR'][pharmacode],
        }
        if seq = @items[pharmacode]
          object[:seq] = seq
        end
        objects << object
      end
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
          objects.each do |obj|
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
                xml.SMNO  bg_pac[:swissmedic_number]   unless bg_pac[:swissmedic_number].empty?
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
                if !bg_pac[:swissmedic_number].empty? and
                   bg_pac[:swissmedic_number].to_s =~ /(\d{5})(\d{3})/
                  xml.COOL 1 if @fridges.include?($1.to_s)
                end
              end
              #xml.TEMP
              #xml.CDBG
              #xml.BG
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
            xml.NBR_RECORD objects.length.to_s
            xml.ERROR_CODE ''
            xml.MESSAGE    ''
          }
        }
      end
      _builder.to_xml
    end
  end
end
