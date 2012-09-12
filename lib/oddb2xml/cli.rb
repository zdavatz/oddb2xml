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
      @mutex = Mutex.new
      @items = {} # Preparations.xml in BAG
      @index = {} # swissINDEX
    end
    def run
      threads = []
      # bag_xml
      threads << Thread.new do
        downloader = BagXmlDownloader.new
        xml = downloader.download
        extractor = BagXmlExtractor.new(xml)
        @items = extractor.to_hash
      end
      LANGUAGES.map do |lang|
        # swissindex
        threads << Thread.new do
          downloader = SwissIndexDownloader.new
          xml = downloader.download_by(lang)
          extractor = SwissIndexExtractor.new(xml)
          index = extractor.to_hash
          @mutex.synchronize do
            @index["#{lang}"] = index
          end
        end
      end
      threads.map(&:join)
      build
      report
    end
    private
    def build
      SUBJECTS.each do |sbj|
        builder = Builder.new do |builder|
          builder.subject = sbj
          builder.index   = @index
          builder.items   = @items
        end
        xml = builder.to_xml
        File.open("oddb_#{sbj}.xml", 'w:utf-8') do |fh|
          fh << xml
        end
      end
    end
    def report
      # pass
    end
  end
end
