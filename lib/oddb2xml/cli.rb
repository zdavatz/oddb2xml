# encoding: utf-8

require 'thread'
require 'oddb2xml/downloader'
require 'oddb2xml/extractor'

module Oddb2xml
  class Cli
    SUBJECTS = %w[product article]
    LOCALES  = %w[DE FR] # EN does not exist

    SUBJECTS.each do |sbj|
      eval("attr_accessor :#{sbj}")
    end

    def initialize
      SUBJECTS.each do |sbj|
        self.send("#{sbj}=", {})
      end
      @mutex = Mutex.new
    end

    def run
      LOCALES.map do |lang|
        Thread.new do
          downloader = Oddb2xml::Downloader.new
          items_hash = downloader.download_by(lang)
          Oddb2xml::Extractor.new(items_hash) do |extractor|
            extractor.locale = lang
            SUBJECTS.each do |sbj|
              extractor.subject = sbj
              xml = extractor.extract
              @mutex.synchronize do
                self.send(sbj)["#{lang}"] = xml
              end
            end
          end
        end
      end.map(&:join)
      finalize
      report
    end

    private

    def finalize
      SUBJECTS.each do |sbj|
        content = self.send(sbj)
        File.open("oddb_#{sbj}.xml", 'w') do |fh|
          LOCALES.each do |lang|
            fh << content[lang]
          end
        end
      end
    end

    def report
      # pass
    end

  end
end

