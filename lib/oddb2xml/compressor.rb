# encoding: utf-8

require 'zlib'
require 'archive/tar/minitar'

module Oddb2xml
 class Compressor
    include Archive::Tar
    attr_accessor :contents
    def initialize(prefix='oddb', ext='tar.gz')
      @compressed_file = "#{prefix}_xml_" + Time.now.strftime("%d.%m.%Y_%H.%M.#{ext}")
      @contents = []
      super()
    end
    def finalize!
      unless @contents.select{ |file| File.exists?(file) }.length == 2
        return false
      end
      begin
        tgz = Zlib::GzipWriter.new(File.open(@compressed_file, 'wb'))
        Minitar.pack(@contents, tgz)
        if File.exists? @compressed_file
          @contents.each do |file|
            File.unlink file
          end
        end
      rescue => error
        puts error
        if File.exists? @compressed_file
          File.unlink @compressed_file
        end
        return false
      end
      return true
    end
  end
end
