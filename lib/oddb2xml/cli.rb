# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'
require 'oddb2xml/compressor'

module Oddb2xml
  class Cli
    SUBJECTS  = %w[product article]
    ADDITIONS = %w[substance limitation]
    OPTIONALS = %w[fi]
    LANGUAGES = %w[DE FR] # EN does not exist
    def initialize(args)
      @options = args
      @mutex = Mutex.new
      @items = {} # Items from Preparations.xml in BAG
      @index = {} # Base index from swissINDEX
      @infos = {} # FI from SwissmedicInfo
      @orphans = [] # Orphaned drugs from Swissmedic xls
      @fridges = [] # ReFridge drugs from Swissmedic xls
      LANGUAGES.each do |lang|
        @index[lang] = {}
      end
    end
    def run
      threads = []
      # swissmedic
      threads << Thread.new do
        downloader = SwissmedicInfoDownloader.new
        xml = downloader.download
        @mutex.synchronize do
          hsh = SwissmedicInfoExtractor.new(xml).to_hash
          @infos = hsh
        end
      end
      [:orphans, :fridges].each do |type|
        threads << Thread.new do
          downloader = SwissmedicDownloader.new
          io = downloader.download_by(type)
          self.instance_variable_set("@#{type.to_s}", SwissmedicExtractor.new(io, type).to_arry)
        end
      end
      # bag
      threads << Thread.new do
        downloader = BagXmlDownloader.new
        xml = downloader.download
        @mutex.synchronize do
          hsh = BagXmlExtractor.new(xml).to_hash
          @items = hsh
        end
      end
      LANGUAGES.each do |lang|
        # swissindex
        types.each do |type|
          threads << Thread.new do
            downloader = SwissIndexDownloader.new(type)
            xml = downloader.download_by(lang)
            @mutex.synchronize do
              hsh = SwissIndexExtractor.new(xml, type).to_hash
              @index[lang][type] = hsh
            end
          end
        end
      end
      threads.map(&:join)
      build
      compress if @options[:compress_ext]
      report
    end
    private
    def build
      begin
        files.each_pair do |sbj, file|
          builder = Builder.new do |builder|
            index = {}
            LANGUAGES.each do |lang|
              index[lang] = {} unless index[lang]
              types.each do |type|
                index[lang].merge!(@index[lang][type]) if @index[lang][type]
              end
            end
            builder.subject = sbj
            builder.index   = index
            builder.items   = @items
            # additions
            builder.orphans = @orphans
            builder.fridges = @fridges
            # optionals
            builder.infos = @infos
            builder.tag_suffix = @options[:tag_suffix]
          end
          xml = builder.to_xml
          File.open(file, 'w:utf-8'){ |fh| fh << xml }
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
      compressor = Compressor.new(prefix, @options[:compress_ext])
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
        _files = (ADDITIONS + SUBJECTS)
        _files += OPTIONALS if @options[:fi]
        _files.each do|sbj|
          @_files[sbj] = "#{prefix}_#{sbj.to_s}.xml"
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
