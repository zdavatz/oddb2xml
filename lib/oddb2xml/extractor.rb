# encoding: utf-8

require 'nokogiri'
require 'spreadsheet'

module Oddb2xml
  class Extractor
    attr_accessor :xml
    def initialize(xml)
      @xml = xml
    end
  end
  class BagXmlExtractor < Extractor
    def to_hash
      data = {}
      doc = Nokogiri::XML(@xml)
      doc.xpath('//Preparation').each do |seq|
        item = {}
        item[:product_key]  = seq.attr('ProductCommercial').to_s
        item[:desc_de]      = (desc = seq.at_xpath('.//DescriptionDe')) ? desc.text : ''
        item[:desc_fr]      = (desc = seq.at_xpath('.//DescriptionFr')) ? desc.text : ''
        item[:name_de]      = (name = seq.at_xpath('.//NameDe'))        ? name.text : ''
        item[:name_fr]      = (name = seq.at_xpath('.//NameFr'))        ? name.text : ''
        item[:org_gen_code] = (orgc = seq.at_xpath('.//OrgGenCode'))    ? orgc.text : ''
        item[:deductible]   = (ddbl = seq.at_xpath('.//FlagSB20'))      ? ddbl.text : ''
        item[:atc_code]     = (orgc = seq.at_xpath('.//AtcCode'))       ? orgc.text : ''
        item[:comment_de]   = (info = seq.at_xpath('.//CommentDe'))     ? info.text : ''
        item[:comment_fr]   = (info = seq.at_xpath('.//CommentFr'))     ? info.text : ''
        item[:it_code]      = ''
        seq.xpath('.//ItCode').each do |itc|
          if item[:it_code].to_s.empty?
            it_code = itc.attr('Code').to_s
            item[:it_code] = (it_code =~ /(\d+)\.(\d+)\.(\d+)./) ? it_code : ''
          end
        end
        item[:substances] = []
        seq.xpath('.//Substance').each_with_index do |sub, i|
          item[:substances] << {
            :index    => i.to_s,
            :name     => (name = sub.at_xpath('.//DescriptionLa')) ? name.text : '',
            :quantity => (qtty = sub.at_xpath('.//Quantity'))      ? qtty.text : '',
            :unit     => (unit = sub.at_xpath('.//QuantityUnit'))  ? unit.text : '',
          }
        end
        item[:pharmacodes] = []
        item[:packages]    = {} # pharmacode => package
        seq.xpath('.//Pack').each do |pac|
          if phar = pac.attr('Pharmacode')
            phar = phar.to_s
            # as common key with swissINDEX
            item[:pharmacodes] << phar
            # packages
            item[:packages][phar] = {
              :pharmacode          => phar,
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
            # limitation
            item[:packages][phar][:limitations] = []
            pac.xpath('.//Limitation').each do |lim|
              item[:packages][phar][:limitations] << {
                :code => (lic = lim.at_xpath('.//LimitationCode')) ? lic.text : '',
                :type => (lit = lim.at_xpath('.//LimitationType')) ? lit.text : '',
              }
            end
            # limitation points
            pts = pac.at_xpath('.//PointLimitations/PointLimitation/Points') # only first points
            item[:packages][phar][:limitation_points] = pts ? pts.text : ''
            # pharmacode => seq (same data)
            data[phar] = item
          end
        end
      end
      data
    end
  end
  class SwissIndexExtractor < Extractor
    def initialize(xml, type)
      @type = (type == :pharma ? 'PHARMA' : 'NONPHARMA')
      super(xml)
    end
    def to_hash
      data = {}
      doc = Nokogiri::XML(@xml)
      doc.remove_namespaces!
      doc.xpath("//Envelope/Body/#{@type}/ITEM").each do |pac|
        item = {}
        item[:ean]             = (gtin = pac.at_xpath('.//GTIN'))   ? gtin.text : ''
        item[:pharmacode]      = (phar = pac.at_xpath('.//PHAR'))   ? phar.text : ''
        item[:status]          = (stat = pac.at_xpath('.//STATUS')) ? stat.text : ''
        item[:stat_date]       = (date = pac.at_xpath('.//SDATE'))  ? date.text : ''
        item[:lang]            = (lang = pac.at_xpath('.//LANG'))   ? lang.text : ''
        item[:desc]            = (dscr = pac.at_xpath('.//DSCR'))   ? dscr.text : ''
        item[:atc_code]        = (code = pac.at_xpath('.//ATC'))    ? code.text : ''
        # as quantity text
        item[:additional_desc] = (dscr = pac.at_xpath('.//ADDSCR')) ? dscr.text : ''
        if comp = pac.xpath('.//COMP')
          item[:company_name] = (nam = comp.at_xpath('.//NAME')) ? nam.text : ''
          item[:company_ean]  = (gln = comp.at_xpath('.//GLN'))  ? gln.text : ''
        end
        unless item[:pharmacode].empty?
          data[item[:pharmacode]] = item
        end
      end
      data
    end
  end
  class SwissmedicExtractor < Extractor
    def initialize(io, type)
      book = Spreadsheet.open(io)
      @sheet = book.worksheet(0)
      @type  = type
    end
    def to_arry
      data = []
      case @type
      when :orphans
        i = 1
        @sheet.each do |row|
          if number = extract_number(row, i)
            data << number
          end
        end
      when :fridges
        i,c = 1,7
        @sheet.each do |row|
          if number = extract_number(row, i) and row[c] and row[c].to_s == 'x'
            data << row[i].to_i.to_s
          end
        end
      end
      data.uniq
    end
    private
    def extract_number(row, i)
      begin
        if (row[i] and number = row[i].to_i.to_s and number =~ /^\d{5}$/)
          return number
        else
          nil
        end
      rescue NoMethodError
        nil
      end
    end
  end
end
