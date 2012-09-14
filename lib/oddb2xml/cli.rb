# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'

module Oddb2xml
  class Cli
    SUBJECTS  = %w[product article]
    LANGUAGES = %w[DE FR] # EN does not exist
    def initialize
      #@mutex = Mutex.new
      @items = {} # Preparations.xml in BAG
      @index = {}
      LANGUAGES.each do |lang|
        @index[lang] = {} # swissINDEX
      end
    end
    def help
      puts <<EOS
#$0 ver.#{Oddb2xml::VERSION}
Usage:
  oddb2xml
EOS
    end
    def run
      # Sometimes nokogiri crashes with ruby in Threads.
      #threads = []
      # bag_xml
      #threads << Thread.new do
        downloader = BagXmlDownloader.new
        xml = downloader.download
        extractor = BagXmlExtractor.new(xml)
        @items = extractor.to_hash
      #end
      LANGUAGES.map do |lang|
        # swissindex
        #threads << Thread.new do
          downloader = SwissIndexDownloader.new
          xml = downloader.download_by(lang)
          extractor = SwissIndexExtractor.new(xml)
          index = extractor.to_hash
          #@mutex.synchronize do
            @index["#{lang}"] = index
          #end
        #end
      end
      #threads.map(&:join)
      build
      report
    end
    private
    def build
      files = {}
      SUBJECTS.each{ |sbj| files[sbj] = "oddb_#{sbj}.xml" }
      begin
        files.each_pair do |sbj, file|
          builder = Builder.new do |builder|
            builder.subject = sbj
            builder.index   = @index
            builder.items   = @items
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
    def report
      # pass
    end
  end
end
