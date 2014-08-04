# encoding: utf-8

require 'nokogiri'
require 'spreadsheet'
require 'stringio'
require 'rubyXL'
require 'csv'
require 'oddb2xml/xml_definitions'

module Oddb2xml
  Strip_For_Sax_Machine = '<?xml version="1.0" encoding="utf-8"?>'+"\n"
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
    def correct_code(pharmacode, length=7)
      if pharmacode.length != length # restore zero at the beginnig
        ("%0#{length}i" % pharmacode.to_i)
      else
        pharmacode
      end
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
      result = PreparationsEntry.parse(@xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      result.Preparations.Preparation.each do |seq|
        item = {}
        item[:refdata]      = true
        item[:product_key]  = seq.ProductCommercial
        item[:desc_de]      = (desc = seq.DescriptionDe) ? desc : ''
        item[:desc_fr]      = (desc = seq.DescriptionFr) ? desc : ''
        item[:name_de]      = (name = seq.NameDe)        ? name : ''
        item[:name_fr]      = (name = seq.NameFr)        ? name : ''
        item[:swissmedic_number5] = (num5 = seq.SwissmedicNo5) ? (num5.rjust(5,'0')) : ''
        item[:org_gen_code] = (orgc = seq.OrgGenCode)    ? orgc : ''
        item[:deductible]   = (ddbl = seq.FlagSB20)      ? ddbl : ''
        item[:atc_code]     = (atcc = seq.AtcCode)       ? atcc : ''
        item[:comment_de]   = (info = seq.CommentDe)     ? info : ''
        item[:comment_fr]   = (info = seq.CommentFr)     ? info : ''
        item[:it_code]      = ''
        seq.ItCodes.ItCode.each do |itc|
          if item[:it_code].to_s.empty?
            it_code = itc.Code.to_s
            item[:it_code] = (it_code =~ /(\d+)\.(\d+)\.(\d+)./) ? it_code : ''
          end
        end
        item[:substances] = []
        seq.Substances.Substance.each_with_index do |sub, i|
          item[:substances] << {
            :index    => i.to_s,
            :name     => (name = sub.DescriptionLa) ? name : '',
            :quantity => (qtty = sub.Quantity)      ? qtty : '',
            :unit     => (unit = sub.QuantityUnit)  ? unit : '',
          }
        end
        item[:pharmacodes] = []
        item[:packages]    = {} # pharmacode => package
        seq.Packs.Pack.each do |pac|
          phar = pac.Pharmacode
          phar = correct_code(phar.to_s, 7)
          ean = pac.GTIN
          search_key = phar.to_i != 0 ? phar : ean
          # as common key with swissINDEX
          item[:pharmacodes] << phar
          # packages
          exf = {:price => '', :valid_date => '', :price_code => ''}
          if pac.Prices and pac.Prices.ExFactoryPrice
            exf[:price]      =  pac.Prices.ExFactoryPrice.Price         if pac.Prices.ExFactoryPrice.Price
            exf[:valid_date] =  pac.Prices.ExFactoryPrice.ValidFromDate if pac.Prices.ExFactoryPrice.ValidFromDate
            exf[:price_code] =  pac.Prices.ExFactoryPrice.PriceTypeCode if pac.Prices.ExFactoryPrice.PriceTypeCode
          end
          pub = {:price => '', :valid_date => '', :price_code => ''}
          if pac.Prices and pac.Prices.PublicPrice
            pub[:price]      =  pac.Prices.PublicPrice.Price         if pac.Prices.PublicPrice.Price
            pub[:valid_date] =  pac.Prices.PublicPrice.ValidFromDate if pac.Prices.PublicPrice.ValidFromDate
            pub[:price_code] =  pac.Prices.PublicPrice.PriceTypeCode if pac.Prices.PublicPrice.PriceTypeCode
          end
          item[:packages][search_key] = {
            :pharmacode          => phar,
            :ean                 => (ean) ? ean : '',
            :swissmedic_category => (cat = pac.SwissmedicCategory) ? cat : '',
            :swissmedic_number8  => (num = pac.SwissmedicNo8)      ? num.rjust(8, '0') : '',
            :narcosis_flag       => (flg = pac.FlagNarcosis)       ? flg : '',
            :prices              => { :exf_price => exf, :pub_price => pub },
          }
          # related all limitations
          item[:packages][search_key][:limitations] = []
          limitations = Hash.new{|h,k| h[k] = [] }
          if seq.Limitations
            limitations[:seq] = seq.Limitations.Limitation.collect { |x| x }
          else
            limitations[:seq] = nil
          end
          # in it-codes
          if seq and seq.ItCodes and seq.ItCodes.ItCode
            limitations[:itc] = []
            seq.ItCodes.ItCode.each { |x|  limitations[:itc] += x.Limitations.Limitation if x.Limitations.Limitation}
          else
            limitations[:itc] =nil
          end
          # in pac
          if pac and pac.Limitations
            limitations[:pac] = (lims = pac.Limitations.Limitation) ? lims.to_a : nil
          else
            limitations[:pac] = nil
          end
          limitations.each_pair do |lim_key, lims|
            key = ''
            id  = ''
            case lim_key
            when :seq, :itc
              key = :swissmedic_number5
              id  = item[key].to_s
            when :pac
              key = :swissmedic_number8
              id  = item[:packages][search_key][key].to_s
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
                :code    => (lic = lim.LimitationCode)   ? lic : '',
                :type    => (lit = lim.LimitationType)   ? lit : '',
                :value   => (liv = lim.LimitationValue)  ? liv : '',
                :niv     => (niv = lim.LimitationNiveau) ? niv : '',
                :desc_de => (dsc = lim.DescriptionDe)    ? dsc : '',
                :desc_fr => (dsc = lim.DescriptionFr)    ? dsc : '',
                :vdate   => (dat = lim.ValidFromDate)    ? dat : '',
              }
              deleted = false
              if upto = ((thr = lim.ValidThruDate) ? thr : nil) and
                  upto =~ /\d{2}\.\d{2}\.\d{2}/
                begin
                  deleted = true if Date.strptime(upto, '%d.%m.%y') >= Date.today
                rescue ArgumentError
                end
              end
              limitation[:del] = deleted
              item[:packages][search_key][:limitations] << limitation
            end if lims
          end
          # limitation points
          pts = pac.PointLimitations.PointLimitation.first # only first points
          item[:packages][search_key][:limitation_points] = pts ? pts.Points : ''
          data[search_key] = item
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
      result = PharmaEntry.parse(@xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      items = result.PHARMA.ITEM
      items.each do |pac|
        item = {}
        item[:refdata]         = true
        item[:_type]           = @type.downcase.intern
        item[:ean]             = (gtin = pac.GTIN)   ? gtin: ''
        item[:pharmacode]      = (phar = pac.PHAR)   ? phar: ''
        item[:stat_date]       = (date = pac.SDATE)  ? date: ''
        item[:lang]            = (lang = pac.LANG)   ? lang: ''
        item[:desc]            = (dscr = pac.DSCR)   ? dscr: ''
        item[:atc_code]        = (code = pac.ATC)    ? code.to_s : ''
        # as quantity text
        item[:additional_desc] = (dscr = pac.ADDSCR) ? dscr: ''
        if comp = pac.COMP
          item[:company_name] = (nam = comp.NAME) ? nam: ''
          item[:company_ean]  = (gln = comp.GLN)  ? gln: ''
        end
        unless item[:pharmacode].empty?
          item[:pharmacode] = correct_code(item[:pharmacode].to_s, 7)
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
    def initialize(filename, type)
      @filename = File.join(Downloads, File.basename(filename))
      @filename = File.join(SpecData, File.basename(filename)) if defined?(RSpec) and not File.exists?(@filename)
      @type  = type
      return unless File.exists?(@filename)
      @sheet = RubyXL::Parser.parse(File.expand_path(@filename)).worksheets[0]
    end
    def to_arry
      data = []
      return data unless @sheet
      case @type
      when :orphan
        i = 1
        @sheet.each do |row|
          number = row[1].value.to_i
          if number != 0
            data << sprintf("%05d", number)
          end
        end
      when :fridge
        i,c = 1,7
        @sheet.each do |row|
          if row[i] and number = row[i].value and row[c] and row[c].value.to_s.downcase == 'x'
            data << sprintf("%05d", number)
          end
        end
      end
      cleanup_file
      data.uniq
    end
    def to_hash # Packungen.xls
      data = {}
      return data unless @sheet
      case @type
      when :package
        typ = 6 # Heilmittelcode
        i_5,i_3   = 0,10 # :swissmedic_numbers
        p_5,p_1_2 = 0,1  # :prodno
        cat       = 13   # :swissmedic_category
        ith       = 4    # :ith_swissmedic IT-Code (swissmedic-diff)
        atc       = 5    # :atc_code
        list_code = 6    #  Heilmittelcode, possible values are
        # Allergene
        # Anthroposophika
        # ayurvedische Arzneimittel
        # Bakterien- und Hefepräparate
        # Biotechnologika
        # Blutprodukte
        # Generator
        # Heilmittelcode
        # Homöopathika
        # Impfstoffe
        # Phytotherapeutika
        # Radiopharmazeutika
        # Synthetika human
        # tibetische Arzneimittel
        # Tierarzneimittel
        # Transplantat: Gewebeprodukt
        siz       = 11   # :package_size
        eht       = 12   # :einheit_swissmedic
        sub       = 14   # :substance_swissmedic
        @sheet.each_with_index do |row, i|

          next if (i <= 1)
          next unless row[i_5] and row[i_3]
          no8 = sprintf('%05d',row[i_5].value.to_i) + sprintf('%03d',row[i_3].value.to_i)
          prodno = sprintf('%05d',row[i_5].value.to_i) + row[p_1_2].value.to_i.to_s
          unless no8.empty?
            next if no8.to_i == 0
            ean_base12 = "7680#{no8}"
            data[no8.intern] = {
              :ean                  => (ean_base12.ljust(12, '0') + calc_checksum(ean_base12)),
              :prodno               => prodno ? prodno : '',
              :ith_swissmedic       => row[ith] ? row[ith].value.to_s : '',
              :swissmedic_category  => row[cat].value.to_s,
              :atc_code             => row[atc] ? row[atc].value.to_s : '',
              :list_code            => row[list_code] ? row[list_code].value.to_s : '',
              :package_size         => row[siz] ? row[siz].value.to_s : '',
              :einheit_swissmedic   => row[eht] ? row[eht].value.to_s : '',
              :substance_swissmedic => row[sub] ? row[sub].value.to_s : '',
              :is_tier              => (row[typ] == 'Tierarzneimittel' ? true : false),
            }
          end
        end
      end
      cleanup_file
      data
    end
    private
    def cleanup_file
      begin
        File.unlink(@filename) if File.exists?(@filename)
        rescue Errno::EACCES # Permission Denied on Windows      
      end unless defined?(RSpec)
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
        phar = correct_code(row[1].to_s.gsub(/[^0-9]/, ''), 7)
        data[phar] = {
          :refdata         => true,
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
      return data unless @xml.size > 0
      result = MedicalInformationsContent.parse(@xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      result.medicalInformation.each do |pac|
        lang = pac.lang.to_s
        next unless lang =~ /de|fr/
        item = {}
        item[:refdata] = true,
        item[:name]  = (name = pac.title) ? name : ''
        item[:owner] = (ownr = pac.authHolder) ? ownr : ''
        if content = /cdata/.match(pac.content)
          html = Nokogiri::HTML(content.to_s)
          # all HTML contents without MonTitle and ownerCompany
          item[:paragraph] =  "<title><p>#{item[:name]}</p></title>" +
             ((paragraph = html.xpath("///div[@class='paragraph']")) ? paragraph.to_s : '')
          if text = html.xpath("///div[@id='Section7750']/p").text
            # 1 ~ 3 swissmedic number
            if text =~ /(\d{5})[,\s]*(\d{5})?|(\d{5})[,\s]*(\d{5})?[,\s]*(\d{5})?/
              [$1, $2, $3].compact.each do |n| # plural
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
      inhalt = @io.read
      inhalt.split("\n").each do |line|
        ixno += 1
        next if /ATC1.*Name1.*ATC2.*Name2/.match(line)
        #line = '"'+line unless /^"/.match(line)
        begin
          row = CSV.parse_line(line.gsub('""','"'))
          action = {}
          next unless row.size > 8
          action[:ixno]      = ixno
          action[:title]     = row[4]
          action[:atc1]      = row[0]
          action[:atc2]      = row[2]
          action[:mechanism] = row[5]
          action[:effect]    = row[6]
          action[:measures]  = row[7]
          action[:grad]      = row[8]
          data << action
        rescue CSV::MalformedCSVError
          puts "CSV::MalformedCSVError in line #{ixno}: #{line}"
        end
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
  class ZurroseExtractor < Extractor
    # see http://dev.ywesee.com/Bbmb/TransferDat
    def initialize(dat, extended = false)
      @@extended = extended
      @@error_file ||= File.open(File.join(WorkDir, "duplicate_ean13_from_zur_rose.txt"), 'w+')
      @@items_without_ean13s ||= 0
      @@duplicated_ean13s ||= 0
      @@zur_rose_items ||= 0
      @io = StringIO.new(dat) if dat
    end
    def to_hash
      data = {}
      while line = @io.gets
        line = line.chomp
        next if line =~ /(ad us\.* vet)|(\(vet\))/i
        if @@extended
          next unless line =~ /(\d{13})(\d{1})$/
        else
          next unless line =~ /(7680\d{9})(\d{1})$/
        end
        pharma_code = line[3..9]
        if $1.to_s == '0000000000000'
          @@items_without_ean13s += 1
          ean13 = '000000' + pharma_code # dummy ean13
        else
          ean13 = $1.to_s
        end
        if data[ean13]
          @@error_file.puts "Duplicate ean13 #{ean13} in line \nact: #{line.chomp}\norg: #{data[ean13][:line]}"
          @@items_without_ean13s -= 1
          @@duplicated_ean13s += 1
          next
        end

        data[ean13] = {
          :line   => line.chomp,
          :ean   => ean13,
          :vat   => line[96],
          :description => line[10..59], # .sub(/\s+$/, ''),
          :additional_desc => '',
          :pharmacode => pharma_code,
          :price => sprintf("%.2f", line[60,6].gsub(/(\d{2})$/, '.\1').to_f),
          :pub_price => sprintf("%.2f", line[66,6].gsub(/(\d{2})$/, '.\1').to_f),
          :type => :nonpharma,
          :cmut => line[2],
        }
        @@zur_rose_items += 1
      end if @io
      data
    end
    at_exit do
      if defined?(@@extended) and @@extended
        msg = "Added #{@@items_without_ean13s} via pharmacodes of #{@@zur_rose_items} items when extracting the transfer.dat from \"Zur Rose\""
        msg += "\n  found #{@@duplicated_ean13s} lines with duplicated ean13" if @@duplicated_ean13s > 0
        puts msg
        @@error_file.puts msg
      end
    end
  end
end
