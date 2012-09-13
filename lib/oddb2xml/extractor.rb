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
      # pharmacode => sequence
      data = {}
      doc = Nokogiri::XML(@xml)
      doc.xpath('//Preparation').each do |seq|
        item = {}
        item[:product_key]  = seq.attr('ProductCommercial').to_s
        item[:desc_de]      = (desc = seq.at_xpath('.//DescriptionDe')) ? desc.text : ''
        item[:desc_fr]      = (desc = seq.at_xpath('.//DescriptionFr')) ? desc.text : ''
        item[:name_de]      = (name = seq.at_xpath('.//NameDe'))        ? name.text : ''
        item[:name_fr]      = (name = seq.at_xpath('.//NameFr'))        ? name.text : ''
        item[:org_gen_code] = (code = seq.at_xpath('.//OrgGenCode'))    ? code.text : ''
        item[:atc_code]     = (code = seq.at_xpath('.//AtcCode'))       ? code.text : ''
        item[:comment_de]   = (info = seq.at_xpath('.//CommentDe'))     ? info.text : ''
        item[:comment_fr]   = (info = seq.at_xpath('.//CommentFr'))     ? info.text : ''
        item[:it_code]      = ''
        seq.xpath('.//ItCode').each do |it_code|
          if item[:it_code].to_s.empty?
            code = it_code.attr('Code').to_s
            item[:it_code] = (code =~ /(\d+)\.(\d+)\.(\d+)./) ? code : ''
          end
        end
        item[:substances] = []
        seq.xpath('.//Substance').each_with_index do |sub, i|
          item[:substances] << {
            :index    => i.to_s,
            :quantity => (qtty = sub.at_xpath('.//Quantity'))     ? qtty.text : '',
            :unit     => (unit = sub.at_xpath('.//QuantityUnit')) ? unit.text : '',
          }
        end
        item[:pharmacodes] = []
        item[:packages]    = {} # pharmacode => package
        seq.xpath('.//Pack').each do |pac|
          if code = pac.attr('Pharmacode')
            code = code.to_s
            # as common key with swissINDEX
            item[:pharmacodes] << code
            # packages
            item[:packages][code] = {
              :pharmacode          => code,
              :swissmedic_category => (cat = pac.at_xpath('.//SwissmedicCategory')) ? cat.text : '',
              :swissmedic_number   => (num = pac.at_xpath('.//SwissmedicNo8'))      ? num.text : '',
              :narcosis_flag       => (flg = pac.at_xpath('.//FlagNarcosis'))       ? flg.text : '',
              :prices              => {
                :exf_price => {
                  :price      => (exf = pac.at_xpath('.//ExFactoryPrice/Price'))         ? exf.text : '',
                  :valid_date => (exf = pac.at_xpath('.//ExFactoryPrice/ValidFromDate')) ? exf.text : '',
                  :price_code => (exf = pac.at_xpath('.//ExFactoryPrice/PriceTypeCode')) ? exf.text : '',
                },
                :pub_price => {
                  :price      => (pub = pac.at_xpath('.//PublicPrice/Price'))         ? pub.text : '',
                  :valid_date => (pub = pac.at_xpath('.//PublicPrice/ValidFromDate')) ? pub.text : '',
                  :price_code => (pub = pac.at_xpath('.//PublicPrice/PriceTypeCode')) ? pub.text : '',
                }
              }
            }
            # limitation points
            points = pac.at_xpath('.//PointLimitations/PointLimitation/Points') # only first points
            item[:packages][code][:limitation_points] = points ? points.text : ''
            # pharmacode => seq (same data)
            data[code] = item
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
