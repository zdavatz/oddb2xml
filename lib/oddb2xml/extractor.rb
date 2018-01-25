# encoding: utf-8
require 'nokogiri'
require 'spreadsheet'
require 'stringio'
require 'rubyXL'
require 'csv'
require 'oddb2xml/xml_definitions'

module Oddb2xml
  module TxtExtractorMethods
    def initialize(str)
      Oddb2xml.log("TxtExtractorMethods #{str} #{str.to_s.size} bytes")
      @io = StringIO.new(str)
    end
    def to_hash
      data = {}
      while line = @io.gets
        next unless line =~ /\d{13}/
        ean13 = line.chomp.gsub("\"", '')
        data[ean13] = true
      end
      data
    end
  end
  class Extractor
    attr_accessor :xml
    def initialize(xml)
      Oddb2xml.log("Extractor #{xml } xml #{xml.size} bytes")
      @xml = xml
    end
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
        item[:data_origin]  = 'bag_xml'
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
          if pac.SwissmedicNo8 && pac.SwissmedicNo8.length < 8
            puts "BagXmlExtractor: Adding leading zeros for SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}"
            pac.SwissmedicNo8  = pac.SwissmedicNo8.rjust(8, '0')
          end
          unless pac.GTIN
            unless pac.SwissmedicNo8
              puts "BagXmlExtractor: Skipping as missing GTIN in SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}. Skipping"
            else
              ean12 = '7680' + pac.SwissmedicNo8
              pac.GTIN  = (ean12 + Oddb2xml.calc_checksum(ean12))
              puts "BagXmlExtractor: Setting missing GTIN  #{pac.GTIN} in SwissmedicNo8 #{pac.SwissmedicNo8}  BagDossierNo #{pac.BagDossierNo} PackId #{pac.PackId} #{item[:name_de]}."
            end
          end
          ean13 = pac.GTIN.to_s
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
          item[:packages][ean13] = {
            :ean13               => ean13,
            :swissmedic_category => (cat = pac.SwissmedicCategory) ? cat : '',
            :swissmedic_number8  => (num = pac.SwissmedicNo8)      ? num : '',
            :prices              => { :exf_price => exf, :pub_price => pub },
          }
          # related all limitations
          item[:packages][ean13][:limitations] = []
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
              id  = item[:packages][ean13][key].to_s
            end
            if id.empty? && item[:packages][ean13][ :swissmedic_number8]
              key = :swissmedic_number8
              id  = item[:packages][ean13][key].to_s
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
              item[:packages][ean13][:limitations] << limitation
            end if lims
          end
          # limitation points
          pts = pac.PointLimitations.PointLimitation.first # only first points
          item[:packages][ean13][:limitation_points] = pts ? pts.Points : ''
          data[ean13] = item
        end
      end
      data
    end
  end

  class RefdataExtractor < Extractor
    def initialize(xml, type)
      @type = (type == :pharma ? 'PHARMA' : 'NONPHARMA')
      super(xml)
    end
    def to_hash
      data = {}
      result = SwissRegArticleEntry.parse(@xml.sub(Strip_For_Sax_Machine, ''), :lazy => true)
      items = result.ARTICLE.ITEM
      items.each do |pac|
        ean13 = (gtin = pac.GTIN.to_s) ? gtin: '0'
        if ean13.size != 13
          puts "Refdata #{@type} ean13: Fixed incorrect length #{ean13.size} for #{ean13}"
          ean13 = ean13[1..-1]
        end
        item = {}
        item[:data_origin]     = 'refdata'
        item[:refdata]         = true
        item[:_type]           = (typ  = pac.ATYPE.downcase.to_sym)  ? typ: ''
        item[:ean13]           = ean13
        item[:pharmacode]      = (phar = pac.PHAR.to_s)   ? phar: '0'
        item[:last_change]     = (date = Time.parse(pac.DT).to_s)  ? date: ''  # Date and time of last data change
        item[:desc_de]         = (dscr = pac.NAME_DE)   ? dscr: ''
        item[:desc_fr]         = (dscr = pac.NAME_FR)   ? dscr: ''
        item[:atc_code]        = (code = pac.ATC)    ? code.to_s : ''
        item[:company_name] = (nam = pac.AUTH_HOLDER_NAME) ? nam: ''
        item[:company_ean]  = (gln = pac.AUTH_HOLDER_GLN)  ? gln: ''
        unless item[:pharmacode]
          item[:pharmacode] = phar
          unless data[item[:pharmacode]] # pharmacode => GTINs
            data[item[:ean13]] = []
          end
        end
        data[item[:ean13]] = item
      end
      data
    end
  end
  class SwissmedicExtractor < Extractor
    def initialize(filename, type)
      @filename = File.join(Downloads, File.basename(filename))
      @filename = File.join(SpecData, File.basename(filename)) if defined?(RSpec) and not File.exists?(@filename)
      @type  = type
      Oddb2xml.log("SwissmedicExtractor #{@filename} #{File.size(@filename)} bytes")
      return unless File.exists?(@filename)
      @sheet = RubyXL::Parser.parse(File.expand_path(@filename)).worksheets[0]
    end
    def to_arry
      data = []
      return data unless @sheet
      case @type
      when :orphan
        i = 1
        col_zulassung = 5
        raise "Could not find Zulassungsnummer in column #{col_zulassung} of #{@filename}" unless /Zulassungs.*nummer/.match(@sheet[3][col_zulassung].value)
        @sheet.each do |row|
          next unless row[col_zulassung]
          number = row[col_zulassung].value.to_i
          if number != 0
            data << sprintf("%05d", number)
          end
        end
      end
      cleanup_file
      # puts "found #{data.uniq.size} entities for type #{@type}"
      data.uniq
    end

    def to_hash # Packungen.xlsx COLUMNS_JULY_2015
      data = {}
      return data unless @sheet
      case @type
      when :package
        Oddb2xml.check_column_indices(@sheet)
        ith       = COLUMNS_JULY_2015.keys.index(:index_therapeuticus)
        i_5       = COLUMNS_JULY_2015.keys.index(:iksnr)
        seq_name  = COLUMNS_JULY_2015.keys.index(:name_base)
        i_3       = COLUMNS_JULY_2015.keys.index(:ikscd)
        p_1_2     = COLUMNS_JULY_2015.keys.index(:seqnr)
        cat       = COLUMNS_JULY_2015.keys.index(:ikscat)
        siz       = COLUMNS_JULY_2015.keys.index(:size)
        atc       = COLUMNS_JULY_2015.keys.index(:atc_class)
        list_code = COLUMNS_JULY_2015.keys.index(:production_science)
        eht       = COLUMNS_JULY_2015.keys.index(:unit)
        sub       = COLUMNS_JULY_2015.keys.index(:substances)
        comp      = COLUMNS_JULY_2015.keys.index(:composition)

        # production_science Heilmittelcode, possible values are
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
        @sheet.each_with_index do |row, i|

          next if (i <= 1)
          next unless row and row[i_5] and row[i_3]
          next unless row[i_5].value.to_i > 0 and row[i_3].value.to_i > 0
          no8 = sprintf('%05d',row[i_5].value.to_i) + sprintf('%03d',row[i_3].value.to_i)
          prodno = sprintf('%05d',row[i_5].value.to_i) + sprintf('%02d', row[p_1_2].value.to_i).to_s
          unless no8.empty?
            next if no8.to_i == 0
            ean_base12 = "7680#{no8}"
            data[no8] = {
              :ean13                => (ean_base12.ljust(12, '0') + Oddb2xml.calc_checksum(ean_base12)),
              :prodno               => prodno ? prodno : '',
              :ith_swissmedic       => row[ith] ? row[ith].value.to_s : '',
              :swissmedic_category  => row[cat].value.to_s,
              :atc_code             => row[atc] ? Oddb2xml.add_epha_changes_for_ATC(row[i_5].value.to_s, row[atc].value.to_s) : '',
              :list_code            => row[list_code] ? row[list_code].value.to_s : '',
              :package_size         => row[siz] ? row[siz].value.to_s : '',
              :einheit_swissmedic   => row[eht] ? row[eht].value.to_s : '',
              :substance_swissmedic => row[sub] ? row[sub].value.to_s : '',
              :composition_swissmedic => row[comp] ? row[comp].value.to_s : '',
              :sequence_name        => row[seq_name] ? row[seq_name].value.to_s : '',
              :is_tier              => (row[list_code] == 'Tierarzneimittel' ? true : false),
              :gen_production       => row[COLUMNS_JULY_2015.keys.index(:gen_production)].value.to_s,
              :insulin_category     => row[COLUMNS_JULY_2015.keys.index(:insulin_category)].value.to_s,
              :drug_index           => row[COLUMNS_JULY_2015.keys.index(:drug_index)].value.to_s,
              :data_origin          => 'swissmedic_package',
              :expiry_date          => row[COLUMNS_JULY_2015.keys.index(:expiry_date)].value.to_s,
              :company_name         => row[COLUMNS_JULY_2015.keys.index(:company)].value.to_s,
              :size                 => row[COLUMNS_JULY_2015.keys.index(:size)].value.to_s,
              :unit                 => row[COLUMNS_JULY_2015.keys.index(:unit)].value.to_s,
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

  end
  class MigelExtractor < Extractor
    def initialize(bin)
      Oddb2xml.log("MigelExtractor #{io} #{File.size(io)} bytes")
      book = Spreadsheet.open(io, 'rb')
      @sheet = book.worksheet(0)
    end
    def to_hash
      data = {}
      @sheet.each_with_index do |row, i|
        next if i.zero?
        phar = row[1]
        next if phar == 0
        ean13 = row[0]
        ean13 = phar unless ean13.to_s.length == 13
        data[ean] = {
          :refdata         => true,
          :ean13           => ean13,
          :pharmacode      => phar,
          :desc_de         => row[3],
          :desc_fr         => row[4],
          :quantity        => row[5], # quantity
          :company_name    => row[6],
          :company_ean     => row[7],
          :data_origin     => 'migel'
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
        item[:refdata] = true
        item[:data_origin] = 'swissmedic_info'
        item[:name]  = (name = pac.title) ? name : ''
        item[:owner] = (ownr = pac.authHolder) ? ownr : ''
        item[:style] =  Nokogiri::HTML.fragment(pac.style).to_html(:encoding => 'UTF-8')
        html = Nokogiri::HTML.fragment(pac.content.force_encoding('UTF-8'))
        item[:paragraph] = html
        numbers =  /(\d{5})[,\s]*(\d{5})?|(\d{5})[,\s]*(\d{5})?[,\s]*(\d{5})?/.match(html)
        if numbers
              [$1, $2, $3].compact.each do |n| # plural
                item[:monid] = n
                data[lang] << item
              end
        end
      end
      data
    end
  end

  class EphaExtractor < Extractor
    def initialize(str)
      Oddb2xml.log("EphaExtractor #{str.size} bytes")
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
          action[:data_origin] = 'epha'
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
            :data_origin   => 'medreg',
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
            :data_origin   => 'medreg',
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
    def initialize(dat, extended = false, artikelstamm = false)
      @@extended = extended
      @artikelstamm = artikelstamm
      FileUtils.makedirs(WorkDir)
      @@error_file ||= File.open(File.join(WorkDir, "duplicate_ean13_from_zur_rose.txt"), 'wb+:ISO-8859-14')
      @@items_without_ean13s ||= 0
      @@duplicated_ean13s ||= 0
      @@zur_rose_items ||= 0
      if dat
        if File.exists?(dat)
          @io = File.open(dat, 'rb:ISO-8859-14')
        else
          @io = StringIO.new(dat)
        end
        @io
      else
         nil
      end
    end
    def to_hash
      data = {}
      while line = @io.gets
        line = Oddb2xml.patch_some_utf8(line).chomp
        next if line =~ /(ad us\.* vet)|(\(vet\))/i
        if @@extended
          next unless line =~ /(\d{13})(\d{1})$/
        else
          next unless line =~ /(7680\d{9})(\d{1})$/
        end
        pharma_code = line[3..9]
        if $1.to_s == '0000000000000'
          @@items_without_ean13s += 1
          ean13 = '999999' + pharma_code.to_s # dummy ean13
        else
          ean13 = $1
        end
        next if @artikelstamm && /(0{13})(\d{1})$/.match(line)
        if data[ean13]
          @@error_file.puts "Duplicate ean13 #{ean13} in line \nact: #{line.chomp}\norg: #{data[ean13][:line]}"
          @@items_without_ean13s -= 1
          @@duplicated_ean13s += 1
          next
        end

        pexf = sprintf("%.2f", line[60,6].gsub(/(\d{2})$/, '.\1').to_f)
        ppub =  sprintf("%.2f", line[66,6].gsub(/(\d{2})$/, '.\1').to_f)
        next if  @artikelstamm && /^113/.match(line) && /^7680/.match(ean13)
        next if  @artikelstamm && /^113/.match(line) && ppub.eql?('0.0') && pexf.eql?('0.0')
        data[ean13] = {
          :data_origin   => 'zur_rose',
          :line   => line.chomp,
          :ean13 => ean13,
          :clag  => line[73],
          :vat   => line[96],
          :description => line[10..59].sub(/\s+$/, ''),
          :quantity => '',
          :pharmacode => pharma_code,
          :price => pexf,
          :pub_price => ppub,
          :type => :nonpharma,
          :cmut => line[2],
        }
        @@zur_rose_items += 1
      end if @io
      if defined?(@@extended) and @@extended
        @@error_file.puts get_error_msg
      end
      @@error_file.close
      @@error_file = nil
      data
    end
    at_exit do
      puts get_error_msg
    end if defined?(@@extended) and @@extended
private
    def get_error_msg
      if defined?(@@extended) and @@extended
        msg = "Added #{@@items_without_ean13s} via pharmacodes of #{@@zur_rose_items} items when extracting the transfer.dat from \"Zur Rose\""
        msg += "\n  found #{@@duplicated_ean13s} lines with duplicated ean13" if @@duplicated_ean13s > 0
        return msg
      end
      nil
    end
  end
end
