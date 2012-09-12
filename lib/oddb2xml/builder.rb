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
      _objects = merge_objects
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.PRODUCT(
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'     => 'http://www.e-mediat.ch/index',
          'CREATION_DATETIME' => '',
          'PROD_DATE'         => '',
          'VALID_DATE'        => ''
        ) {
          xml.PRD('DT' => '') {
            #@objects.each do |product|
            xml.PRDNO
            xml.DSCRD
            xml.DSCRF
            xml.BNAMD
            xml.BNAMF
            xml.ADNAMD
            xml.ADNAMF
            xml.SIZE
            xml.ADINFD
            xml.ADINFF
            xml.GENCD
            xml.GENGRP
            xml.ATC
            xml.IT
            xml.ITBAG
            xml.KONO
            xml.TRADE
            xml.PRTNO
            xml.MONO
            xml.CDGALD
            xml.CDGALF
            xml.FORMD
            xml.FORMF
            xml.DOSE
            xml.DOSEU
            xml.DEL
            xml.CPT {
              xml.CPTLNO
              xml.IDXIND
              xml.DDDD
              xml.DDDU
              xml.DDDA
              xml.IXREL
              xml.GALF
              xml.EXCIP
              xml.EXCIPQ
              xml.PQTY
              xml.PQTYU
              xml.SIZEMM
              xml.WEIGHT
              xml.LOOKD
              xml.LOOKF
              xml.IMG2
              xml.CPTCMP {
                xml.LINE
                xml.SUBNO
                xml.QTY
                xml.WHK
              }
              # ...
              xml.CPTIX {
                xml.IXNO
                xml.GRP
                xml.RLV
              }
              # ...
            }
          }
          # ...
          xml.RESULT {
            xml.OK_ERROR
            xml.NBR_RECORD
            xml.ERROR_CODE
            xml.MESSAGE
          }
        }
      end
      _builder.to_xml
    end
    def build_article
      _objects = merge_objects
      _builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.PRODUCT(
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns'     => 'http://www.e-mediat.ch/index',
          'CREATION_DATETIME' => '',
          'PROD_DATE'         => '',
          'VALID_DATE'        => ''
        ) {
        }
      end
      _builder.to_xml
    end
    def merge_objects
      puts
      puts @subject
      puts "swissindex[de]: #{@index['DE'].keys.length}"
      #puts "swissindex[de]: #{@index['FR'].keys.length}"
      puts "bag xml       : #{@items.keys.length}"
    end
  end
end
