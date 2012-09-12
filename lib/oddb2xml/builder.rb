# encoding: utf-8

require 'nokogiri'

module Oddb2xml
  class Builder
    attr_accessor :subject, :index, :items
    def initialize
      @subject = nil
      @index   = {}
      @items   = {}
      if block_given?
        yield self
      end
    end
    def to_xml
      if @subject
        self.send('build_' + @subject)
      end
    end
    private
    def build_product
      # merge company info from swissINDEX
      objects = []
      objects = @items.values.uniq.map do |reg|
        %w[de fr].each do |lang|
          key = "company_name_#{lang}".intern
          reg[key] = ''
          if pharmacode = reg[:pharmacodes].first
            indices = @index[lang.upcase]
            if index = indices[pharmacode]
              reg[key] = index[:company_name]
            end
          end
        end
        reg
      end
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.PRODUCT(
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'     => 'http://www.e-mediat.ch/index',
          'CREATION_DATETIME' => '',
          'PROD_DATE'         => '',
          'VALID_DATE'        => ''
        ) {
          objects.each do |reg|
            xml.PRD('DT' => '') {
              xml.PRDNO  reg[:product_key]     unless reg[:product_key].empty?
              xml.DSCRD  reg[:desc_de]         unless reg[:desc_de].empty?
              xml.DSCRF  reg[:desc_fr]         unless reg[:desc_fr].empty?
              xml.BNAMD  reg[:name_de]         unless reg[:name_de].empty?
              xml.BNAMF  reg[:name_fr]         unless reg[:name_fr].empty?
              xml.ADNAMD reg[:company_name_de] unless reg[:company_name_de].empty?
              xml.ADNAMF reg[:company_name_fr] unless reg[:company_name_fr].empty?
              #xml.ADINFD
              #xml.ADINFF
              #xml.SIZE
              xml.GENCD  reg[:org_gen_code] unless reg[:org_gen_code].empty?
              #xml.GENGRP
              xml.ATC    reg[:atc_code]     unless reg[:atc_code].empty?
              xml.IT     reg[:it_code]      unless reg[:it_code].empty?
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
              #xml.DEL
              xml.CPT {
                #xml.CPTLNO
                #xml.IDXIND
                #xml.DDDD
                #xml.DDDU
                #xml.DDDA
                #xml.IXREL
                #xml.GALF
                #xml.EXCIP
                #xml.EXCIPQ
                #xml.PQTY
                #xml.PQTYU
                #xml.SIZEMM
                #xml.WEIGHT
                #xml.LOOKD
                #xml.LOOKF
                #xml.IMG2
                reg[:substances].each do |sub|
                  xml.CPTCMP {
                    xml.LINE  sub[:index]
                    #xml.SUBNO
                    xml.QTY   sub[:quantity] unless sub[:quantity].empty?
                    xml.QTYU  sub[:unit]     unless sub[:unit].empty?
                    #xml.WHK
                  }
                end
                #xml.CPTIX {
                #  xml.IXNO
                #  xml.GRP
                #  xml.RLV
                #}
              }
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
        if reg = @items[pharmacode]
          object[:reg] = reg
        end
        objects << object
      end
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.ARTICLE(
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'     => 'http://www.e-mediat.ch/index',
          'CREATION_DATETIME' => '',
          'PROD_DATE'         => '',
          'VALID_DATE'        => ''
        ) {
          objects.each do |obj|
            xml.ART('DT' => '') {
              pac = obj[:de]
              xml.PHAR  pac[:pharmacode] unless pac[:pharmacode].empty?
              #xml.GRPCD
              #xml.CDS01
              #xml.CDS02
              if obj[:reg]
                xml.PRDNO obj[:reg][:product_key] unless obj[:reg][:product_key].empty?
              end
              #xml.SMCAT
              #xml.SMNO
              #xml.HOSPCD
              #xml.CLINCD
              #xml.ARTTYP
              #xml.VAT
              #xml.SALECD
              #xml.INSLIM
              #xml.LIMPTS
              #xml.GRDFR
              #xml.COOL
              #xml.TEMP
              #xml.CDBG
              #xml.DSCRF
              #xml.SORTD
              #xml.SORTF
              #xml.QTYUD
              #xml.QTYUF
              #xml.IMG
              #xml.IMG2
              #xml.PCKTYPD
              #xml.PCKTYPF
              #xml.MULT
              if obj[:reg]
                xml.SYN1D obj[:reg][:name_de] unless obj[:reg][:name_de].empty?
                xml.SYN1F obj[:reg][:name_fr] unless obj[:reg][:name_fr].empty?
              end
              #xml.SLOPLUS
              #xml.NOPCS
              #xml.HSCD
              #xml.MINI
              #xml.DEPCD
              #xml.DEPOT
              #xml.BAGSL
              #xml.BAGSLC
              #xml.LOACD
              if pac[:status] == "I"
                xml.OUTSAL pac[:stat_date] unless pac[:stat_date].empty?
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
              #xml.ARTCOMP {
                #xml.COMPNO
                #xml.ROLE
                #xml.ARTNO1
                #xml.ARTNO2
                #xml.ARTNO3
              #}
              xml.ARTBAR {
                xml.CDTYP   'E13'
                xml.BC      pac[:ean] unless pac[:ean].empty?
                #xml.BCSTAT
                #xml.PHAR2
              }
              #xml.ARTCH {
                #xml.PHAR2
                #xml.CHTYPE
                #xml.LINENO
                #xml.NOUNITS
              #}
              #xml.ARTPRI {
                #xml.VDAT
                #xml.PTYP
                #xml.PRICE
              #}
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
                #xml.LIMCD
              #}
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
