# encoding: utf-8

require 'nokogiri'

module Oddb2xml
  class Extractor
    attr_accessor :xml, :language
    def initialize(xml)
      @xml = xml
      if block_given?
        yield self
      end
    end
  end
  class BagXmlExtractor < Extractor
    def to_a
      items = []
      # debug
      #File.open('bagxml.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      doc = Nokogiri::XML(@xml)
      doc.xpath('//Preparation').to_a.each do |reg|
        item = {}
        item[:PRDNO]  = reg.attr('ProductCommercial')
        item[:DSCRD]  = reg.at_xpath('.//DescriptionDe').text
        item[:DSCRF]  = reg.at_xpath('.//DescriptionFr').text
        item[:BNAMD]  = reg.at_xpath('.//NameDe').text
        item[:BNAMF]  = reg.at_xpath('.//NameFr').text
        item[:ADNAMD] = '' # pac.at_xpath('.//DescriptionDe').text
        item[:ADNAMF] = '' # pac.at_xpath('.//DescriptionFr').text
        item[:SIZE]   = '' # pac.at_xpath('.//') swissindex ?
        item[:ADINFD] = '' # reg.at_xpath('.//CommentDe').text
        item[:ADINFF] = '' # reg.at_xpath('.//CommentFr').text
        item[:GENCD]  = reg.at_xpath('.//OrgGenCode').text
        item[:GENGRP] = ''
        item[:ATC]    = reg.at_xpath('.//AtcCode').text
        item[:IT]     = ''
        item[:ITBAG]  = ''
        item[:KONO]   = ''
        item[:TRADE]  = '' # swissindex actives state iH aH or Ex
        item[:PRTNO]  = '' # gtin? of swissindex
        item[:MONO]   = ''
        item[:CDGALD] = ''
        item[:CDGALF] = ''
        item[:FORMD]  = ''
        item[:FORMF]  = ''
        item[:DOSE]   = ''
        item[:DOSEU]  = ''
        item[:DRGFD]  = ''
        item[:DRGFF]  = ''
        item[:ORPH]   = ''
        item[:BIOPHA] = ''
        item[:BIOSIM] = ''
        item[:BFS]    = ''
        item[:BLOOD]  = ''
        item[:MSCD]   = '' # always empty
        item[:DEL]    = ''
        item[:CPT]    = {  # packages ?
          :CPTLNO   => '', # line ?
          :CNAMED   => '',
          :CNAMEF   => '',
          :IDXIND   => '', # ?
          :DDDD     => '', # substances of XMLPublication is multi values ...
          :DDDU     => '',
          :DDDA     => '', # ?
          :IDXIA    => '',
          :IXREL    => '',
          :GALF     => '', # need swissmedic data ?
          :DRGGRPCD => '', # what is special group ?
          :PRBSUIT  => '', # currently empty
          :CSOLV    => '', # currently empty
          :SOLVQ    => '', # currently empty
          :SOLVQU   => '', # currently empty
          :PHVAL    => '', # currently empty
          :LSPNSOL  => '', # currently empty
          :APDURSOL => '', # currently empty
          :EXCIP    => '', # ?
          :EXCIPQ   => '',
          :EXCIPCD  => '', # currently empty
          :EXCIPCF  => '', # currently empty
          :PQTY     => '',
          :PQTYU    => '',
          :SIZEMM   => '', # longest size in substances ?
          :WEIGHT   => '',
          :LOOKD    => '', # arrearance ?
          :LOOKF    => '',
          :IMG2     => '', # image ?
          :CPTCMP   => [], # substances ?
          :CPTIX    => [], # dose not exist interactions ...
          :CPTROA   => [], # ?
        }
        reg.at_xpath('.//Substances').to_a.each_with_index do |sub, i|
          item[:CPT][:CPTCMP] << {
            :LINE  => i.to_s, # index of substances ?
            :SUBNO => '',     # what is substances table ?
            :OTY   => sub.at_xpath('.//Quantity').text,
            :OTYU  => sub.at_xpath('.//QuantityUnit').text,
            :WHK   => '', # ?
          }
        end
        item[:PRDICD] = { # currently empty
        }
        items << item
      end
      items << {
        :RESULT => {
          :OK_ERROR   => 'OK', # data access ?
          :NBR_RECORD => doc.xpath('//Preparation').to_a.length,
          :ERROR_CODE => '',  # does not exist code definition
          :MESSAGE    => '',  # dose not exist messace definition
        }
      }
      items
    end
  end
  class SwissIndexExtractor < Extractor
    def to_hash
      #File.open('swissindex.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      {}
    end
  end
end
