# encoding: utf-8

require 'nokogiri'

module Oddb2xml
  class Extractor
    attr_accessor :xml
    def initialize(xml)
      @xml = xml
    end
  end
  class BagXmlExtractor < Extractor
    def to_hash
      #File.open('../bagxml.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      # pharmacode => registration
      data = {}
      doc = Nokogiri::XML(@xml)
      doc.xpath('//Preparation').each do |reg|
        item = {}
        item[:product_key]  = reg.attr('ProductCommercial').to_s
        item[:desc_de]      = (desc = reg.at_xpath('.//DescriptionDe')) ? desc.text : ''
        item[:desc_fr]      = (desc = reg.at_xpath('.//DescriptionFr')) ? desc.text : ''
        item[:name_de]      = (name = reg.at_xpath('.//NameDe'))        ? name.text : ''
        item[:name_fr]      = (name = reg.at_xpath('.//NameFr'))        ? name.text : ''
        item[:org_gen_code] = (code = reg.at_xpath('.//OrgGenCode'))    ? code.text : ''
        item[:atc_code]     = (code = reg.at_xpath('.//AtcCode'))       ? code.text : ''
        item[:it_code]      = ''
        reg.xpath('.//ItCode').each do |it_code|
          if item[:it_code].to_s.empty?
            code = it_code.attr('Code').to_s
            item[:it_code] = (code =~ /(\d+)\.(\d+)\.(\d+)./) ? code : ''
          end
        end
        item[:substances] = []
        reg.xpath('.//Substance').each_with_index do |sub, i|
          item[:substances] << {
            :index    => i.to_s,
            :quantity => (qtty = sub.at_xpath('.//Quantity'))     ? qtty.text : '',
            :unit     => (unit = sub.at_xpath('.//QuantityUnit')) ? unit.text : '',
          }
        end
        item[:pharmacodes] = []
        reg.xpath('.//Pack').each do |pac|
          if code = pac.attr('Pharmacode')
            item[:pharmacodes] << code.to_s
            data[code] = item # same data
          end
        end
      end
      data
    end
  end
  class SwissIndexExtractor < Extractor
    def to_hash
      #File.open('../swissindex.xml', 'r:ASCII-8BIT') do |f|
      #  @xml = f.read
      #end
      # pharmacode => package
      data = {}
      doc = Nokogiri::XML(@xml)
      doc.remove_namespaces!
      doc.xpath('//Envelope/Body/PHARMA/ITEM').each do |pac|
        item = {}
        item[:ean]        = (gtin = pac.at_xpath('.//GTIN'))   ? gtin.text : ''
        item[:pharmacode] = (phar = pac.at_xpath('.//PHAR'))   ? phar.text : ''
        item[:status]     = (stat = pac.at_xpath('.//STATUS')) ? stat.text : ''
        item[:stat_date]  = (date = pac.at_xpath('.//SDATE'))  ? date.text : ''
        item[:lang]       = (lang = pac.at_xpath('.//LANG'))   ? lang.text : ''
        item[:desc]       = (dscr = pac.at_xpath('.//DSCR'))   ? dscr.text : ''
        item[:atc_code]   = (code = pac.at_xpath('.//ATC'))    ? code.text : ''
        if comp = pac.xpath('.//COMP')
          item[:company_name] = (nam = comp.at_xpath('.//NAME')) ? nam.text : ''
          item[:company_ean]  = (gln = comp.at_xpath('.//GLN'))  ? gln.text : ''
        end
        if code = item[:pharmacode]
          data[code] = item
        end
      end
      data
    end
  end
end
