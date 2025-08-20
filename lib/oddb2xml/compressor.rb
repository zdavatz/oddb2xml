require "zlib"
require "minitar"
require "zip"

module Oddb2xml
  class Compressor
    include Archive::Tar
    attr_accessor :contents
    def initialize(prefix = "oddb", options = {})
      @options = options
      @options[:compress_ext] ||= "tar.gz"
      @options[:format] ||= :xml
      @compress_file = "#{prefix}_#{@options[:format]}_" + Time.now.strftime("%d.%m.%Y_%H.%M.#{@options[:compress_ext]}")
      #      @compress_file = File.join(WORK_DIR, "#{prefix}_#{@options[:format].to_s}_" +
      # Time.now.strftime("%d.%m.%Y_%H.%M.#{@options[:compress_ext]}"))
      @contents = []
      super()
    end

    def finalize!
      if @contents.empty? && (@contents.size == 0)
        return false
      end
      begin
        case @compress_file
        when /\.tar\.gz$/
          tgz = Zlib::GzipWriter.new(File.open(@compress_file, "wb"))
          Minitar.pack(@contents, tgz)
        when /\.zip$/
          Zip::File.open(@compress_file, create: true) do |zip|
            @contents.each do |file|
              filename = File.basename(file)
              zip.add(filename, file)
            end
          end
        end
        if File.exist? @compress_file
          puts "#{__LINE__}: @compress_file"
          @contents.each do |file|
            @tmpfile = file
            puts "#{__LINE__}: @tmpfile"
            FileUtils.rm(file, verbose: true) if file && File.exist?(file)
          end
        end
      rescue Errno::ENOENT
        puts "Unable to compress #{@compress_file}"
        raise RuntimeError
      end
      true
    end
  end
end
