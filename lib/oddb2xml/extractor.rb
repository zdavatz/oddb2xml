# encoding: utf-8

require 'nokogiri'
require 'spreadsheet'
require 'stringio'

module Oddb2xml
  module TxtExtractorMethods
    def initialize(str)
      @io = StringIO.new(str)
    end
    def to_hash
      data = {}
      while line = @io.gets
        next unless line =~ /\d{13}/
        ean = line.chomp.gsub("\"", '')
        data[ean] = true
      end
      data
    end
  end
  class Extractor
    attr_accessor :xml
    def initialize(xml)
      @xml = xml
    end
  end
  class BMUpdateExtractor < Extractor
    include TxtExtractorMethods
  end
  class LppvExtractor < Extractor
    include TxtExtractorMethods
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
        item[:swissmedic_number5] = (num5 = seq.at_xpath('.//SwissmedicNo5')) ? (num5.text.rjust(5,'0')) : ''
        item[:org_gen_code] = (orgc = seq.at_xpath('.//OrgGenCode'))    ? orgc.text : ''
        item[:deductible]   = (ddbl = seq.at_xpath('.//FlagSB20'))      ? ddbl.text : ''
        item[:atc_code]     = (atcc = seq.at_xpath('.//AtcCode'))       ? atcc.text : ''
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
              :swissmedic_number8  => (num = pac.at_xpath('.//SwissmedicNo8'))      ? num.text.rjust(8, '0') : '',
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
            # related all limitations
            item[:packages][phar][:limitations] = []
            limitations = Hash.new{|h,k| h[k] = [] }
            # in seq
            limitations[:seq] = (lims = seq.xpath('.//Limitations/Limitation')) ? lims.to_a : nil
            # in it-codes
            limitations[:itc] = (lims = seq.xpath('.//ItCodes/ItCode/Limitations/Limitation')) ? lims.to_a : nil
            # in pac
            limitations[:pac] = (lims = pac.xpath('.//Limitations/Limitation')) ? lims.to_a : nil
            limitations.each_pair do |lim_key, lims|
              key = ''
              id  = ''
              case lim_key
              when :seq, :itc
                key = :swissmedic_number5
                id  = item[key].to_s
              when :pac
                key = :swissmedic_number8
                id  = item[:packages][phar][key].to_s
              end
              if id.empty? or id == '0'
                key = :pharmacode
                id  = phar.to_s
              end
              lims.each do |lim|
                limitation = {
                  :it      => item[:it_code],
                  :key     => key,
                  :id      => id,
                  :code    => (lic = lim.at_xpath('.//LimitationCode'))   ? lic.text : '',
                  :type    => (lit = lim.at_xpath('.//LimitationType'))   ? lit.text : '',
                  :value   => (liv = lim.at_xpath('.//LimitationValue'))  ? liv.text : '',
                  :niv     => (niv = lim.at_xpath('.//LimitationNiveau')) ? niv.text : '',
                  :desc_de => (dsc = lim.at_xpath('.//DescriptionDe'))    ? dsc.text : '',
                  :desc_fr => (dsc = lim.at_xpath('.//DescriptionFr'))    ? dsc.text : '',
                  :vdate   => (dat = lim.at_xpath('.//ValidFromDate'))    ? dat.text : '',
                }
                deleted = false
                if upto = ((thr = lim.at_xpath('.//ValidThruDate')) ? thr.text : nil) and
                   upto =~ /\d{2}\.\d{2}\.\d{2}/
                  begin
                    deleted = true if Date.strptime(upto, '%d.%m.%y') >= Date.today
                  rescue ArgumentError
                  end
                end
                limitation[:del] = deleted
                item[:packages][phar][:limitations] << limitation
              end
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
        item[:_type]           = @type.downcase.intern
        item[:ean]             = (gtin = pac.at_xpath('.//GTIN'))   ? gtin.text : ''
        item[:pharmacode]      = (phar = pac.at_xpath('.//PHAR'))   ? phar.text : ''
        item[:status]          = (stat = pac.at_xpath('.//STATUS')) ? stat.text : ''
        item[:stat_date]       = (date = pac.at_xpath('.//SDATE'))  ? date.text : ''
        item[:lang]            = (lang = pac.at_xpath('.//LANG'))   ? lang.text : ''
        item[:desc]            = (dscr = pac.at_xpath('.//DSCR'))   ? dscr.text : ''
        item[:atc_code]        = (code = pac.at_xpath('.//ATC'))    ? code.text.to_s : ''
        # as quantity text
        item[:additional_desc] = (dscr = pac.at_xpath('.//ADDSCR')) ? dscr.text : ''
        if comp = pac.xpath('.//COMP')
          item[:company_name] = (nam = comp.at_xpath('.//NAME')) ? nam.text : ''
          item[:company_ean]  = (gln = comp.at_xpath('.//GLN'))  ? gln.text : ''
        end
        unless item[:pharmacode].empty?
          if item[:pharmacode].length != 7 # restore zero at the beginnig
            item[:pharmacode] = ("%07i" % item[:pharmacode])
          end
          unless data[item[:pharmacode]] # pharmacode => GTINs
            data[item[:pharmacode]] = []
          end
          data[item[:pharmacode]] << item
        end
      end
      data
    end
  end
  class SwissmedicExtractor < Extractor
    def initialize(bin, type)
      io = StringIO.new(bin)
      book = Spreadsheet.open(io, 'rb')
      @sheet = book.worksheet(0)
      @type  = type
    end
    def to_arry
      data = []
      case @type
      when :orphan
        i = 1
        @sheet.each do |row|
          if number = extract_number(row, i)
            data << number.to_s
          end
        end
      when :fridge
        i,c = 1,7
        @sheet.each do |row|
          if number = extract_number(row, i) and row[c] and row[c].to_s == 'x'
            data << row[i].to_s
          end
        end
      end
      data.uniq
    end
    def to_hash # Packungen.xls
      data = {}
      case @type
      when :package
        typ = 6 # Heilmittelcode
        i_5,i_3   = 0,10 # :swissmedic_numbers
        p_5,p_1_2 = 0,1  # :prodno
        cat       = 13   # :swissmedic_category
        ith       = 4    # :ith_swissmedic IT-Code (swissmedic-diff)
        atc       = 5    # :atc_code
        siz       = 11   # :package_size
        eht       = 12   # :einheit_swissmedic
        sub       = 14   # :substance_swissmedic
        @sheet.each_with_index do |row, i|
          next if (i== 0)
          no8 = extract_number(row, i_5).to_s + extract_number(row, i_3, /^\d{3}$/).to_s
          unless no8.empty?
            ean_base12 = "7680#{no8}"
            data[no8.intern] = {
              :ean                  => (ean_base12.ljust(12, '0') + calc_checksum(ean_base12)),
              :prodno               => row[p_5].to_s + row[p_1_2].to_i.to_s,
              :ith_swissmedic       => row[ith].to_s,
              :swissmedic_category  => row[cat].to_s,
              :atc_code             => row[atc].to_s,
              :package_size         => row[siz].to_s,
              :einheit_swissmedic   => row[eht].to_s,
              :substance_swissmedic => row[sub].to_s,
              :is_tier              => (row[typ] == 'Tierarzneimittel' ? true : false),
            }
          end
        end
      end
      data
    end
    private
    def extract_number(row, i, ptrn=/^\d{5}$/)
      begin
        return nil unless row[i]
        row[i] = row[i].to_i if row[i].is_a? Float
        number = row[i].to_s.gsub(/[^0-9]/, '')
        number = number.rjust(5, '0') if ptrn == /^\d{5}$/
        if number =~ ptrn
          return number
        else
          nil
        end
      rescue NoMethodError
        nil
      end
    end
    def calc_checksum(str)
      str = str.strip
      sum = 0
      val =   str.split(//u)
      12.times do |idx|
        fct = ((idx%2)*2)+1
        sum += fct*val[idx].to_i
      end
      ((10-(sum%10))%10).to_s
    end
  end
  class MigelExtractor < Extractor
    def initialize(bin)
      io = StringIO.new(bin)
      book = Spreadsheet.open(io, 'rb')
      @sheet = book.worksheet(0)
    end
    def to_hash
      data = {}
      @sheet.each_with_index do |row, i|
        next if i.zero?
        phar = row[1].to_s
        data[phar] = {
          :ean             => row[0].to_i.to_s,
          :pharmacode      => phar,
          :desc_de         => row[3],
          :desc_fr         => row[4],
          :additional_desc => row[5], # quantity
          :company_name    => row[6],
          :company_ean     => row[7].to_i.to_s,
        }
      end
      data
    end
  end
  class SwissmedicInfoExtractor < Extractor
    def to_hash
      data = Hash.new{|h,k| h[k] = [] }
      doc = Nokogiri::XML(@xml)
      doc.xpath("//medicalInformations/medicalInformation[@type='fi']").each do |fi|
        lang = fi.attr('lang').to_s
        next unless lang =~ /de|fr/
        item = {}
        item[:name]  = (name = fi.at_xpath('.//title')) ? name.text : ''
        item[:owner] = (ownr = fi.at_xpath('.//authHolder')) ? ownr.text : ''
        if content = fi.at_xpath('.//content').children.detect{|child| child.cdata? }
          html = Nokogiri::HTML(content.to_s)
          # all HTML contents without MonTitle and ownerCompany
          item[:paragraph] =  "<title><p>#{item[:name]}</p></title>" +
             ((paragraph = html.xpath("///div[@class='paragraph']")) ? paragraph.to_s : '')
          if text = html.xpath("///div[@id='Section7750']/p").text
            # 1 ~ 3 swissmedic number
            if text =~ /(\d{5})[,\s]*(\d{5})?|(\d{5})[,\s]*(\d{5})?[,\s]*(\d{5})?/
              [$1, $2, $3].compact.each do |n|
                item[:monid] = n
                data[lang] << item
              end
            end
          end
        end
      end
      data
    end
  end
  class EphaExtractor < Extractor
    def initialize(str)
      @io = StringIO.new(str)
    end
    def to_arry
      data = []
      ixno = 0
      while line = @io.gets
        next if line =~ /^ATC1;Name1;ATC2;Name2;/
        row = line.chomp.gsub("\"", '').split(';')
        ixno += 1
        action = {}
        action[:ixno]      = ixno
        action[:title]     = row[4]
        action[:atc1]      = row[0]
        action[:atc2]      = row[2]
        action[:mechanism] = row[5]
        action[:effect]    = row[6]
        action[:measures]  = row[7]
        action[:grad]      = row[8]
        data << action
      end
      data
    end
  end
  class MedregbmExtractor < Extractor
    def initialize(str, type)
      @io   = StringIO.new(str)
      @type = type
    end
    def to_arry
      data = []
      case @type
      when :company
        while line = @io.gets
          row = line.chomp.split("\t")
          next if row[0] =~ /^GLN/
          data << {
            :gln           => row[0].to_s.gsub(/[^0-9]/, ''), #=> GLN Betrieb
            :name_1        => row[1].to_s,                    #=> Betriebsname 1
            :name_2        => row[2].to_s,                    #=> Betriebsname 2
            :address       => row[3].to_s,                    #=> Strasse
            :number        => row[4].to_s,                    #=> Nummer
            :post          => row[5].to_s,                    #=> PLZ
            :place         => row[6].to_s,                    #=> Ort
            :region        => row[7].to_s,                    #=> Bewilligungskanton
            :country       => row[8].to_s,                    #=> Land
            :type          => row[9].to_s,                    #=> Betriebstyp
            :authorization => row[10].to_s,                   #=> BTM Berechtigung
          }
        end
      when :person
        while line = @io.gets
          row = line.chomp.split("\t")
          next if row[0] =~ /^GLN/
          data << {
            :gln           => row[0].to_s.gsub(/[^0-9]/, ''), #=> GLN Person
            :last_name     => row[1].to_s,                    #=> Name
            :first_name    => row[2].to_s,                    #=> Vorname
            :post          => row[3].to_s,                    #=> PLZ
            :place         => row[4].to_s,                    #=> Ort
            :region        => row[5].to_s,                    #=> Bewilligungskanton
            :country       => row[6].to_s,                    #=> Land
            :license       => row[7].to_s,                    #=> Bewilligung Selbstdispensation
            :certificate   => row[8].to_s,                    #=> Diplom
            :authorization => row[9].to_s,                    #=> BTM Berechtigung
          }
        end
      end
      data
    end
  end
end
