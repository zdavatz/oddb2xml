# encoding: utf-8

require 'nokogiri'

module Oddb2xml
  class Builder
    attr_accessor :subject, :objects
    def initialize
      @subject = nil
      @objects = []
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
      # debug
      return @objects.to_s

      builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
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
      builder.to_xml
    end

    def build_article
      builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
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
      builder.to_xml
    end
  end
end
