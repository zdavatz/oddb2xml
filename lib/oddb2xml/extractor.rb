# encoding: utf-8

require 'nokogiri'

module Oddb2xml
  class Extractor
    attr_accessor :xml
    def initialize(xml)
      @xml  = xml
      @data = {}
    end
  end
  class BagXmlExtractor < Extractor
    def to_hash
      #File.open('bagxml.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      doc = Nokogiri::XML(@xml)
      # pharmacode => registration
      doc.xpath('//Preparation').each do |prod|
        item = {}
        item[:prod_key]     = prod.attr('ProductCommercial').to_s
        item[:desc_de]      = (desc = prod.xpath('.//DescriptionDe')) ? desc.text : ''
        item[:desc_fr]      = (desc = prod.xpath('.//DescriptionFr')) ? desc.text : ''
        item[:name_de]      = (name = prod.xpath('.//NameDe'))        ? name.text : ''
        item[:name_fr]      = (name = prod.xpath('.//NameFr'))        ? name.text : ''
        item[:org_gen_code] = (code = prod.xpath('.//OrgGenCode'))    ? code.text : ''
        item[:act_code]     = (code = prod.xpath('.//AtcCode'))       ? code.text : ''
        item[:it_code]      = ''
        prod.xpath('.//ItCode').each do |it_code|
          if item[:it_code].to_s.empty?
            code = it_code.attr('Code').to_s
            item[:it_code] = (code =~ /(\d+)\.(\d+)\.(\d+)./) ? code : ''
          end
        end
        item[:substances]   = []
        prod.xpath('.//Substance').each_with_index do |sub, i|
          item[:substances] << {
            :index    => i.to_s,
            :quantity => (qtty = sub.xpath('.//Quantity'))     ? qtty.text : '',
            :unit     => (unit = sub.xpath('.//QuantityUnit')) ? unit.text : '',
          }
        end
        prod.xpath('.//Pack').each do |pack|
          if pharmacode = pack.attr('Pharmacode')
            @data[pharmacode.to_s] = item
          end
        end
      end
      @data
    end
  end
  class SwissIndexExtractor < Extractor
    def to_hash
      #File.open('swissindex.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      doc = Nokogiri::XML(@xml)
      doc.remove_namespaces!
      # pharmacode => package
      doc.xpath('//Envelope/Body/PHARMA/ITEM').each do |pack|
        item = {}
        item[:ean]        = (gtin = pack.xpath('.//GTIN'))   ? gtin.text : ''
        item[:pharmacode] = (phar = pack.xpath('.//PHAR'))   ? phar.text : ''
        item[:status]     = (stat = pack.xpath('.//STATUS')) ? stat.text : ''
        item[:lang]       = (lang = pack.xpath('.//LANG'))   ? lang.text : ''
        item[:desc]       = (dscr = pack.xpath('.//DSCR'))   ? dscr.text : ''
        item[:atc_code]   = (code = pack.xpath('.//ATC'))    ? code.text : ''
        if comp = pack.xpath('.//COMP')
          item[:company_name] = (nam = comp.xpath('.//NAME')) ? nam.text : ''
          item[:company_ean]  = (gln = comp.xpath('.//GLN'))  ? gln.text : ''
        end
        @data[item[:pharmacode]] = item
      end
      @data
    end
  end
end
