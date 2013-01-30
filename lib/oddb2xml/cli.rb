# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'
require 'oddb2xml/compressor'

module Oddb2xml
  class Cli
    SUBJECTS  = %w[product article]
    ADDITIONS = %w[substance limitation interaction code]
    OPTIONALS = %w[fi fi_product]
    LANGUAGES = %w[DE FR] # EN does not exist
    def initialize(args)
      @options = args
      @mutex = Mutex.new
      @items = {} # Items from Preparations.xml in BAG
      @index = {} # Base index from swissINDEX
      @flags = {} # narcotics flag from ywesee
      @infos = {} # [option] FI from SwissmedicInfo
      @packs = {} # [option] Packungen from Swissmedic for dat
      @actions = [] # [addition] interactions from epha
      @orphans = [] # [addition] Orphaned drugs from Swissmedic xls
      @fridges = [] # [addition] ReFridge drugs from Swissmedic xls
      LANGUAGES.each do |lang|
        @index[lang] = {}
      end
    end
    def run
      threads = []
      # swissmedic-info
      if @options[:format] != :dat
        if @options[:fi]
          threads << Thread.new do
            downloader = SwissmedicInfoDownloader.new
            xml = downloader.download
            @mutex.synchronize do
              hsh = SwissmedicInfoExtractor.new(xml).to_hash
              @infos = hsh
            end
          end
        end
        # swissmedic - orphan, fridge
        [:orphans, :fridges].each do |type|
          threads << Thread.new do
            downloader = SwissmedicDownloader.new(type)
            bin = downloader.download
            self.instance_variable_set("@#{type.to_s}", SwissmedicExtractor.new(bin, type).to_arry)
          end
        end
        # epha
        threads << Thread.new do
          downloader = EphaDownloader.new
          str = downloader.download
          @mutex.synchronize do
            @actions = EphaExtractor.new(str).to_arry
          end
        end
      else # dat
        # swissmedic - package
        threads << Thread.new do
          downloader = SwissmedicDownloader.new(:packages)
          bin = downloader.download
          @mutex.synchronize do
            @packs = SwissmedicExtractor.new(bin, :packages).to_hash
          end
        end
      end
      # ywesee
      threads << Thread.new do
        downloader = YweseeBMDownloader.new
        str = downloader.download
        @mutex.synchronize do
          @flags = YweseeBMExtractor.new(str).to_hash
        end
      end
      # bag
      threads << Thread.new do
        downloader = BagXmlDownloader.new(@options)
        xml = downloader.download
        @mutex.synchronize do
          hsh = BagXmlExtractor.new(xml).to_hash
          @items = hsh
        end
      end
      @_message = false
      LANGUAGES.each do |lang|
        # swissindex
        types.each do |type|
          threads << Thread.new do
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
      begin
        files.each_pair do |sbj, file|
          builder = Builder.new do |builder|
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
            builder.items   = @items
            builder.flags   = @flags
            # additions
            %w[actions orphans fridges].each do |addition|
              builder.send("#{addition}=".intern, self.instance_variable_get("@#{addition}"))
            end
            # optionals
            builder.infos = @infos
            builder.packs = @packs
            builder.tag_suffix = @options[:tag_suffix]
          end
          output = ''
          if @options[:format] == :dat
            types.each do |type|
              index = {}
              LANGUAGES.each do |lang|
                index[lang] = @index[lang][type]
              end
              builder.index = index
              _sbj = (type == :pharma ? :dat : :with_migel_dat)
              builder.subject = _sbj
              if type == :nonpharma
                output << "\n"
                builder.ean14 = @options[:ean14]
              end
              output << builder.to_dat
            end
          else
            output = builder.to_xml
          end
          File.open(file, 'w:utf-8'){ |fh| fh << output }
        end
      rescue Interrupt
        files.values.each do |file|
          if File.exist? file
            File.unlink file
          end
        end
        raise Interrupt
      end
    end
    def compress
      compressor = Compressor.new(prefix, @options)
      files.values.each do |file|
        if File.exists?(file)
          compressor.contents << file
        end
      end
      compressor.finalize!
    end
    def files
      unless @_files
        @_files = {}
        if @options[:format] == :dat
          @_files[:dat] = "#{prefix}.dat"
          if @options[:nonpharma] # into one file
            @_files[:dat] = "#{prefix}_with_migel.dat"
          end
        else # xml
          ##
          # building order
          #   1. addtions
          #   2. subjects
          #   3. optionals
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
      LANGUAGES.each do |lang|
        lines << lang
        types.each do |type|
          key = (type == :nonpharma ? 'NonPharma' : 'Pharma')
          if @index[lang][type]
            lines << sprintf(
              "\t#{key} products: %i", @index[lang][type].values.length)
          end
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
