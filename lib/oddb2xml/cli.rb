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
    attr_reader :options
    SUBJECTS  = %w[product article]
    ADDITIONS = %w[substance limitation interaction code]
    OPTIONALS = %w[fi fi_product]
    def initialize(args)
      @options = args
      Oddb2xml.save_options(@options)
      @mutex = Mutex.new
      # product
      @items = {} # Items from Preparations.xml in BAG, using GTINs as key
      @refdata_types = {} # Base index from refdata
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
      @_message = false
    end
    def run
      threads = []
      files2rm = Dir.glob(File.join(Downloads, '*'))
      FileUtils.rm_f(files2rm, :verbose => @options[:log]) if files2rm.size > 0 and not Oddb2xml.skip_download?
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
        types.each do |type|
          threads << download(:refdata, type) # refdata
        end
      end
      begin
        # threads.map(&:join) # TODO
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
      puts "#{File.basename(__FILE__)}:#{__LINE__}: @refdata_types.keys #{@refdata_types.keys}"
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
                refdata = {}
                types.each do |type|
                  refdata.merge!(@refdata_types[type]) if @refdata_types[type]
                end
                builder.refdata = refdata
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
              refdata1 = {}
              _sbj = (type == :pharma ? :dat : :with_migel_dat)
              builder.refdata = @refdata_types[type]
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
    def download(what, type=nil)
      case what
      when :company, :person
        var = (what == :company ? 'companies' : 'people')
        begin # instead of Thread.new do
          downloader = MedregbmDownloader.new(what)
          str = downloader.download
          Oddb2xml.log("SwissmedicInfoDownloader #{what} str #{str.size} bytes")
          self.instance_variable_set(
            "@#{var}".intern,
            items = MedregbmExtractor.new(str, what).to_arry
          )
          Oddb2xml.log("MedregbmExtractor #{what} added #{items.size} fachinfo")
          items
        end
      when :fachinfo
        begin # instead of Thread.new do
          downloader = SwissmedicInfoDownloader.new
          xml = downloader.download
          Oddb2xml.log("SwissmedicInfoDownloader #{var} xml #{xml.size} bytes")
          @mutex.synchronize do
            hsh = SwissmedicInfoExtractor.new(xml).to_hash
            @infos = hsh
            Oddb2xml.log("SwissmedicInfoExtractor added #{@infos.size} fachinfo")
            @infos
          end
        end
      when :orphan, :fridge
        var = what.to_s + 's'
        begin # instead of Thread.new do
          downloader = SwissmedicDownloader.new(what)
          bin = downloader.download
          Oddb2xml.log("SwissmedicDownloader #{var} bin #{bin.size} bytes")
          self.instance_variable_set(
            "@#{var}".intern,
            items = SwissmedicExtractor.new(bin, what).to_arry
          )
          Oddb2xml.log("SwissmedicExtractor added #{items.size} #{var}. File #{bin} was #{File.size(bin)} bytes")
          items
        end
      when :interaction
        begin # instead of Thread.new do
          downloader = EphaDownloader.new
          str = downloader.download
          Oddb2xml.log("EphaDownloader str #{str.size} bytes")
          @mutex.synchronize do
            @actions = EphaExtractor.new(str).to_arry
            Oddb2xml.log("EphaExtractor added #{@actions.size} interactions")
            @actions
          end
        end
      when :migel
        begin # instead of Thread.new do
          downloader = MigelDownloader.new
          bin = downloader.download
          Oddb2xml.log("MigelDownloader bin #{bin.size} bytes")
          @mutex.synchronize do
            @migel = MigelExtractor.new(bin).to_hash
            Oddb2xml.log("MigelExtractor added #{@migel.size} migel items")
            @migel
          end
        end
      when :package
        begin # instead of Thread.new do
          downloader = SwissmedicDownloader.new(:package, @options)
          bin = downloader.download
          Oddb2xml.log("SwissmedicDownloader bin #{bin.size} bytes")
          @mutex.synchronize do
            @packs = SwissmedicExtractor.new(bin, :package).to_hash
            Oddb2xml.log("SwissmedicExtractor added #{@packs.size} packs from #{bin}")
            @packs
          end
        end
      when :bm_update
        begin # instead of Thread.new do
          downloader = BMUpdateDownloader.new
          str = downloader.download
          Oddb2xml.log("BMUpdateDownloader str #{str.size} bytes")
          @mutex.synchronize do
            @flags = BMUpdateExtractor.new(str).to_hash
            Oddb2xml.log("BMUpdateExtractor added #{@flags.size} flags")
            @flags
          end
        end
      when :lppv
        begin # instead of Thread.new do
          downloader = LppvDownloader.new
          str = downloader.download
          Oddb2xml.log("LppvDownloader str #{str.size} bytes")
          @mutex.synchronize do
            @lppvs = LppvExtractor.new(str).to_hash
            Oddb2xml.log("LppvExtractor added #{@lppvs.size} lppvs")
            @lppvs
          end
        end
      when :bag
        begin # instead of Thread.new do
          downloader = BagXmlDownloader.new(@options)
          xml = downloader.download
          Oddb2xml.log("BagXmlDownloader xml #{xml.size} bytes")
          @mutex.synchronize do
            hsh = BagXmlExtractor.new(xml).to_hash
            @items = hsh
            Oddb2xml.log("BagXmlExtractor added #{@items.size} items.")
            @items
          end
        end
      when :zurrose
        begin # instead of Thread.new do
          downloader = ZurroseDownloader.new(@options, @options[:transfer_dat])
          xml = downloader.download
          Oddb2xml.log("ZurroseDownloader xml #{xml.size} bytes")
          @mutex.synchronize do
            hsh = ZurroseExtractor.new(xml, @options[:extended]).to_hash
            Oddb2xml.log("ZurroseExtractor added #{hsh.size} items from xml with #{xml.size} bytes")
            @infos_zur_rose = hsh
          end
        end
      when :refdata
        begin # instead of Thread.new do
          downloader = RefdataDownloader.new(@options, type)
          begin
            xml = downloader.download
            Oddb2xml.log("RefdataDownloader #{type} xml #{xml.size} bytes")
            xml
          rescue SystemExit
            @mutex.synchronize do
              unless @_message # hook only one exit
                @_message = true
                exit
              end
            end
          end
          @mutex.synchronize do
            hsh = RefdataExtractor.new(xml, type).to_hash
            @refdata_types[type] = hsh
            Oddb2xml.log("RefdataExtractor #{type} added #{hsh.size} keys now #{@refdata_types.keys} items from xml with #{xml.size} bytes")
            @refdata_types[type]
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
        lines << ParseComposition.report
      end
      unless @options[:address]
        types.each do |type|
          if @refdata_types[type]
            indices = @refdata_types[type].values.flatten.length
            if type == :nonpharma
              migel_xls  = @migel.values.compact.select{|m| !m[:pharmacode].empty? }.map{|m| m[:pharmacode] }
              nonpharmas = @refdata_types[type].keys
              indices += (migel_xls - nonpharmas).length # ignore duplicates, null
              lines << sprintf("\tNonPharma products: %i", indices)
            else
              lines << sprintf("\tPharma products: %i", indices)
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
    def types # RefData
      @_types ||=
        if @options[:nonpharma]
          [:pharma, :nonpharma]
        else
          [:pharma]
        end
    end
  end
end
