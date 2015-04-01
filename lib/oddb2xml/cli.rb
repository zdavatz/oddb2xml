# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'
require 'oddb2xml/compressor'
require 'oddb2xml/options'
require 'oddb2xml/util'
require 'rubyXL'
require 'date' # for today

module Oddb2xml
  
  class Cli
    SUBJECTS  = %w[product article]
    ADDITIONS = %w[substance limitation interaction code]
    OPTIONALS = %w[fi fi_product]
    LANGUAGES = %w[DE FR] # EN does not exist
    def initialize(args)
      @options = args
      Oddb2xml.save_options(@options)
      @mutex = Mutex.new
      # product
      @items = {} # Items from Preparations.xml in BAG
      @index = {} # Base index from swissINDEX
      @flags = {} # narcotics flag files repo
      @lppvs = {} # lppv.txt from files repo
      @infos = {} # [option] FI from SwissmedicInfo
      @packs = {} # [option] Packungen from Swissmedic for dat
      @infos_zur_rose  = {} # [addition] infos_zur_rose and other infos from zurrose transfer.txt
      @migel   = {} # [addition] additional Non Pharma products from files repo
      @actions = [] # [addition] interactions from epha
      @orphans = [] # [addition] Orphaned drugs from Swissmedic xls
      @fridges = [] # [addition] ReFridge drugs from Swissmedic xls
      # addres
      @companies = [] # betrieb
      @people    = [] # medizinalperson
      LANGUAGES.each do |lang|
        @index[lang] = {}
      end
      @_message = false
    end
    def run
      threads = []
      if @options[:calc] and not @options[:extended]
        threads << download(:package) # swissmedic
      elsif @options[:address]
        [:company, :person].each do |type|
          threads << download(type) # medregbm.admin
        end
      else
        if @options[:format] != :dat
          if @options[:fi]
            threads << download(:fachinfo) # swissmedic-info
          end
          [:orphan, :fridge].each do |type|
            threads << download(type) # swissmedic
          end
          threads << download(:interaction) # epha
        end
        if @options[:nonpharma]
          threads << download(:migel) # oddb2xml_files
        end
        threads << download(:zurrose)
        threads << download(:package) # swissmedic
        threads << download(:bm_update) # oddb2xml_files
        threads << download(:lppv) # oddb2xml_files
        threads << download(:bag) # bag.e-mediat
        LANGUAGES.each do |lang|
          types.each do |type|
            threads << download(:index, type, lang) # swissindex
          end
        end
      end
      begin
        threads.map(&:join)
      rescue SystemExit
        @mutex.synchronize do
          if @_message
            puts "(Aborted)"
            puts "Please install SSLv3 CA certificates on your machine."
            puts "You can check with `ruby -ropenssl -e 'p OpenSSL::X509::DEFAULT_CERT_FILE'`."
            puts "See README."
          end
        end
        exit
      end
      build
      compress if @options[:compress_ext]
      report
    end
    private
    def build
      Oddb2xml.log("Start build")
      begin
        # require 'pry'; binding.pry
        @_files = {"calc"=>"oddb_calc.xml"} if @options[:calc] and not @options[:extended]
        files.each_pair do |sbj, file|
          builder = Builder.new(@options) do |builder|
            if @options[:calc] and not @options[:extended]
              builder.packs = @packs
              builder.subject = sbj
            elsif @options[:address]
              builder.subject   = sbj
              builder.companies = @companies
              builder.people    = @people
            else # product
              if @options[:format] != :dat
                index = {}
                LANGUAGES.each do |lang|
                  index[lang] = {} unless index[lang]
                  types.each do |type|
                    index[lang].merge!(@index[lang][type]) if @index[lang][type]
                  end
                end
                builder.index = index
                builder.subject = sbj
              end
              # common sources
              builder.items = @items
              builder.flags = @flags
              builder.lppvs = @lppvs
              # optional sources
              builder.infos = @infos
              builder.packs = @packs
              # additional sources
              %w[actions orphans fridges migel infos_zur_rose].each do |addition|
                builder.send("#{addition}=".intern, self.instance_variable_get("@#{addition}"))
              end
            end
            builder.tag_suffix = @options[:tag_suffix]
          end
          output = ''
          if !@options[:address] and (@options[:format] == :dat)
            types.each do |type|
              index = {}
              LANGUAGES.each do |lang|
                index[lang] = @index[lang][type]
              end
              _sbj = (type == :pharma ? :dat : :with_migel_dat)
              builder.index   = index
              builder.subject = _sbj
              builder.ean14   = @options[:ean14]
              if type == :nonpharma
                output << "\n"
              end
              output << builder.to_dat
            end
          else
            output = builder.to_xml
          end
          File.open(File.join(WorkDir, file), 'w:utf-8'){ |fh| fh << output }
          if @options[:calc]
            FileUtils.cp(File.join(WorkDir, file), File.join(WorkDir, file.sub('.xml', '_'+Time.now.strftime("%d.%m.%Y_%H.%M")+'.xml')), :verbose => false)
          end
        end
      rescue Interrupt
        files.values.each do |file|
          if File.exist? file
            File.unlink(file) # we don't save it as it might be only partly downloaded
          end
        end
        raise Interrupt
      end
    end
    def download(what, type=nil, lang=nil)
      case what
      when :company, :person
        var = (what == :company ? 'companies' : 'people')
        Thread.new do
          downloader = MedregbmDownloader.new(what)
          str = downloader.download
          self.instance_variable_set(
            "@#{var}".intern,
            MedregbmExtractor.new(str, what).to_arry
          )
        end
      when :fachinfo
        Thread.new do
          downloader = SwissmedicInfoDownloader.new
          xml = downloader.download
          @mutex.synchronize do
            hsh = SwissmedicInfoExtractor.new(xml).to_hash
            @infos = hsh
            Oddb2xml.log("SwissmedicInfoExtractor added #{@infos.size} fachinfo")
          end
        end
      when :orphan, :fridge
        var = what.to_s + 's'
        Thread.new do
          downloader = SwissmedicDownloader.new(what)
          bin = downloader.download
          self.instance_variable_set(
            "@#{var}".intern,
            SwissmedicExtractor.new(bin, what).to_arry
          )
#          Oddb2xml.log("SwissmedicExtractor added #{self.instance_variable_get("@#{var}".intern).size} #{var}. File #{bin} was #{File.size(bin)} bytes")
        end
      when :interaction
        Thread.new do
          downloader = EphaDownloader.new
          str = downloader.download
          @mutex.synchronize do
            @actions = EphaExtractor.new(str).to_arry
            Oddb2xml.log("EphaExtractor added #{@actions.size} interactions")
          end
        end
      when :migel
        Thread.new do
          downloader = MigelDownloader.new
          bin = downloader.download
          @mutex.synchronize do
            @migel = MigelExtractor.new(bin).to_hash
            Oddb2xml.log("MigelExtractor added #{@migel.size} migel items")
          end
        end
      when :package
        Thread.new do
          downloader = SwissmedicDownloader.new(:package, @options)
          bin = downloader.download
          @mutex.synchronize do
            @packs = SwissmedicExtractor.new(bin, :package).to_hash
            Oddb2xml.log("SwissmedicExtractor added #{@packs.size} packs from #{bin}")
            @packs
          end
        end
      when :bm_update
        Thread.new do
          downloader = BMUpdateDownloader.new
          str = downloader.download
          @mutex.synchronize do
            @flags = BMUpdateExtractor.new(str).to_hash
            Oddb2xml.log("BMUpdateExtractor added #{@flags.size} flags")
          end
        end
      when :lppv
        Thread.new do
          downloader = LppvDownloader.new
          str = downloader.download
          @mutex.synchronize do
            @lppvs = LppvExtractor.new(str).to_hash
            Oddb2xml.log("LppvExtractor added #{@lppvs.size} lppvs")
          end
        end
      when :bag
        Thread.new do
          downloader = BagXmlDownloader.new(@options)
          xml = downloader.download
          @mutex.synchronize do
            hsh = BagXmlExtractor.new(xml).to_hash
            @items = hsh
            Oddb2xml.log("BagXmlDownloader added #{@items.size} items")
          end
        end
      when :zurrose
        Thread.new do
          downloader = ZurroseDownloader.new(@options, @options[:transfer_dat])
          xml = downloader.download
          Oddb2xml.log("zurrose xml #{xml.size} bytes")
          @mutex.synchronize do
            hsh = ZurroseExtractor.new(xml, @options[:extended]).to_hash
            @infos_zur_rose = hsh
            Oddb2xml.log("zurrose added #{@infos_zur_rose.size} items from xml with #{xml.size} bytes")
          end
        end
      when :index
        Thread.new do
          downloader = SwissIndexDownloader.new(@options, type, lang)
          begin
            xml = downloader.download
          rescue SystemExit
            @mutex.synchronize do
              unless @_message # hook only one exit
                @_message = true
                exit
              end
            end
          end
          @mutex.synchronize do
            hsh = SwissIndexExtractor.new(xml, type).to_hash
            @index[lang][type] = hsh
          end
        end
      end
    end
    def compress
      compressor = Compressor.new(prefix, @options)
      files.values.each do |file|
        work_file = File.join(WorkDir, file)
        if File.exists?(work_file)
          compressor.contents << work_file
        end
      end
      compressor.finalize!
    end
    def files
      unless @_files
        @_files = {}
        @_files[:calc] = "oddb_calc.xml" if @options[:calc]
        if @options[:address]
          @_files[:company] = "#{prefix}_betrieb.xml"
          @_files[:person]  = "#{prefix}_medizinalperson.xml"
        elsif @options[:format] == :dat
          @_files[:dat] = "#{prefix}.dat"
          if @options[:nonpharma] # into one file
            @_files[:dat] = "#{prefix}_with_migel.dat"
          end
        else # xml
          ##
          # building order
          #   1. additions
          #   2. subjects
          #   3. optional SUBJECTS
          _files = (ADDITIONS + SUBJECTS)
          _files += OPTIONALS if @options[:fi]
          _files.each do|sbj|
            @_files[sbj] = "#{prefix}_#{sbj.to_s}.xml"
          end
        end
      end
      @_files
    end
    def prefix
      @_prefix ||= (@options[:tag_suffix] || 'oddb').gsub(/^_|_$/, '').downcase
    end
    def report
      lines = []
      if @options[:calc]
        lines << Calc.dump_new_galenic_forms
        lines << Calc.dump_names_without_galenic_forms
        lines << Calc.report_conversion
      end
      unless @options[:address]
        LANGUAGES.each do |lang|
          lines << lang
          types.each do |type|
            if @index[lang][type]
              indices = @index[lang][type].values.flatten.length
              if type == :nonpharma
                migel_xls  = @migel.values.compact.select{|m| !m[:pharmacode].empty? }.map{|m| m[:pharmacode] }
                nonpharmas = @index[lang][type].keys
                indices += (migel_xls - nonpharmas).length # ignore duplicates, null
                lines << sprintf("\tNonPharma products: %i", indices)
              else
                lines << sprintf("\tPharma products: %i", indices)
              end
            end
          end
        end
        if @options[:extended]
          lines << sprintf("\tInformation items zur Rose: %i", @infos_zur_rose.length)
        end
      else
        {
          'Betrieb' => :@companies,
          'Person'  => :@people
        }.each do |type, var|
          lines << sprintf(
            "#{type} addresses: %i", self.instance_variable_get(var).length)
        end
      end
      puts lines.join("\n")
    end
    def types # swissindex
      @_types ||=
        if @options[:nonpharma]
          [:pharma, :nonpharma]
        else
          [:pharma]
        end
    end
  end
end
