# encoding: utf-8

require 'zlib'
require 'archive/tar/minitar'
require 'zip/zip'

module Oddb2xml
 class Compressor
    include Archive::Tar
    attr_accessor :contents
    def initialize(prefix='oddb', ext='tar.gz')
      @compress_file = "#{prefix}_xml_" + Time.now.strftime("%d.%m.%Y_%H.%M.#{ext}")
      @contents      = []
      super()
    end
    def finalize!
      unless @contents.select{ |file| File.exists?(file) }.length == 3
        return false
      end
      begin
        case @compress_file
        when /\.tar\.gz$/
          tgz = Zlib::GzipWriter.new(File.open(@compress_file, 'wb'))
          Minitar.pack(@contents, tgz)
        when /\.zip$/
          Zip::ZipFile.open(@compress_file, Zip::ZipFile::CREATE) do |zip|
            @contents.each do |file|
              filename = File.basename(file)
              zip.add(filename, file)
            end
          end
        end
        if File.exists? @compress_file
          @contents.each do |file|
            File.unlink file
          end
        end
      rescue => error
        puts error
        if File.exists? @compress_file
          File.unlink @compress_file
        end
        return false
      end
      return true
    end
  end
end
