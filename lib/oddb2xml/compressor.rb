# encoding: utf-8

require 'zlib'
require 'minitar'
require 'zip'

module Oddb2xml
 class Compressor
    include Archive::Tar
    attr_accessor :contents
    def initialize(prefix='oddb', options={})
      @options = options
      @options[:compress_ext] ||= 'tar.gz'
      @options[:format]       ||= :xml
      @compress_file = "#{prefix}_#{@options[:format].to_s}_" + Time.now.strftime("%d.%m.%Y_%H.%M.#{@options[:compress_ext]}")                                 
                                 #      @compress_file = File.join(WorkDir, "#{prefix}_#{@options[:format].to_s}_" +
                                 #Time.now.strftime("%d.%m.%Y_%H.%M.#{@options[:compress_ext]}"))
      @contents = []
      super()
    end
    def finalize!
      if @contents.empty? and @contents.size == 0
        return false
      end
      begin
        case @compress_file
        when /\.tar\.gz$/
          tgz = Zlib::GzipWriter.new(File.open(@compress_file, 'wb'))
          Minitar.pack(@contents, tgz)
        when /\.zip$/
          Zip::File.open(@compress_file, Zip::File::CREATE) do |zip|
            @contents.each do |file|
              filename = File.basename(file)
              zip.add(filename, file)
            end
          end
        end
        if File.exists? @compress_file and not defined?(Rspec)
          @contents.each do |file|
            FileUtils.rm(file)
          end
        end
        rescue Errno::ENOENT, StandardError => e
        return false
      end
      return true
    end
  end
end
