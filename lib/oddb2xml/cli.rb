# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'
require 'oddb2xml/compressor'

module Oddb2xml
  class Cli
    SUBJECTS  = %w[product article]
    LANGUAGES = %w[DE FR] # EN does not exist
    def initialize(args)
      @options = args
      @mutex = Mutex.new
      @items = {} # Items from Preparations.xml in BAG
      @index = {} # Base index from swissINDEX
      @orphans = [] # Orphaned drugs from Swissmedic xls
      @fridges = [] # ReFridge drugs from Swissmedic xls
      LANGUAGES.each do |lang|
        @index[lang] = {}
      end
    end
    def run
      threads = []
      # swissmedic
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
        @items = BagXmlExtractor.new(xml).to_hash
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
      report
    end
    private
    def build
      files = {}
      prefix = (@options[:tag_suffix] || 'oddb').gsub(/^_|_$/, '').downcase
      SUBJECTS.each{ |sbj| files[sbj] = "#{prefix}_#{sbj}.xml" }
      begin
        files.each_pair do |sbj, file|
          builder = Builder.new do |builder|
            index = {}
            LANGUAGES.each do |lang|
              index[lang] = {} unless index[lang]
              types.each do |type|
                index[lang].merge!(@index[lang][type])
              end
            end
            builder.subject    = sbj
            builder.index      = index
            builder.items      = @items
            builder.orphans    = @orphans
            builder.fridges    = @fridges
            builder.tag_suffix = @options[:tag_suffix]
          end
          if file =~ /(product)/
            xml = builder.to_xml('substance')
            File.open(file.gsub($1, 'substance'), 'w:utf-8'){ |fh| fh << xml }
          end
          xml = builder.to_xml
          File.open(file, 'w:utf-8'){ |fh| fh << xml }
        end
        if @options[:compress_ext]
          compressor = Compressor.new(prefix, @options[:compress_ext])
          files.values.each do |file|
            if file =~ /(product)/
              compressor.contents << file.gsub($1, 'substance')
            end
            compressor.contents << file
          end
          compressor.finalize!
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
    def report
      lines = []
      LANGUAGES.each do |lang|
        lines << lang
        types.each do |type|
          key = (type == :nonpharma ? 'NonPharma' : 'Pharma')
          lines << sprintf("\t#{key} products: %i", @index[lang][type].values.length)
        end
      end
      puts lines.join("\n")
    end
    def types # swissindex
      if @options[:nonpharma]
        [:pharma, :nonpharma]
      else
        [:pharma]
      end
    end
  end
end
