# encoding: utf-8

require 'thread'
require 'oddb2xml/builder'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'

module Oddb2xml
  class Cli
    SUBJECTS = %w[product article]
    #LANGUAGES = %w[DE FR] # EN does not exist
    LANGUAGES = %w[DE]

    SUBJECTS.each do |sbj|
      eval("attr_accessor :#{sbj}")
    end

    def initialize
      SUBJECTS.each do |sbj|
        self.send("#{sbj}=", [])
      end
      @items      = []
      @swissindex = {}
    end

    def run
      threads = []
      # bag_xml
      threads << Thread.new do
        downloader = BagXmlDownloader.new
        xml = downloader.download
        extractor = BagXmlExtractor.new(xml)
        @items = extractor.to_a
      end
      LANGUAGES.map do |lang|
        # swissindex
        # use status(active/inactive)
        threads << Thread.new do
          downloader = SwissIndexDownloader.new
          xml = downloader.download_by(lang)
          extractor = SwissIndexExtractor.new(xml) do |e|
            e.language = lang
          end
          @swissindex["#{lang}"] = extractor.to_hash
        end
      end
      threads.map(&:join)
      build
      report
    end

    private

    def build
      SUBJECTS.each do |sbj|
        # merge
        @items.map do |item|
          #pharmacode = item[:pharmacode]
          #if @swissindex[pharmacode]
          #  item[:swissindex] = {
          #   :gtin   => @swissindex[pharmacode][:gtin],
          #   :gln     = @swissindex[pharmacode][:gln],
          #   :status => @swissindex[pharmacode][:status]
          #  }
          #end
          self.send(sbj) << item
        end
        builder = Builder.new do |builder|
          builder.subject = sbj
          builder.objects = self.send(sbj)
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
