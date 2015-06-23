require 'open-uri'
module Oddb2xml
  def Oddb2xml.calc_checksum(str)
    str = str.strip
    sum = 0
    val =   str.split(//u)
    12.times do |idx|
      fct = ((idx%2)*2)+1
      sum += fct*val[idx].to_i
    end
    ((10-(sum%10))%10).to_s
  end

  unless defined?(RSpec)
    WorkDir       = Dir.pwd
    Downloads     = "#{Dir.pwd}/downloads"
  end
  @options = {}
  @atc_csv_origin = 'https://raw.githubusercontent.com/epha/robot/master/data/manual/swissmedic/atc.csv'
  @atc_csv_content = {}

  def Oddb2xml.add_epha_changes_for_ATC(iksnr, atc_code)
    if @atc_csv_content.size == 0
      open(@atc_csv_origin).readlines.each{
        |line|
          items = line.split(',')
          @atc_csv_content[[items[0], items[1]]] = items[2]
      }

    end
    new_value = @atc_csv_content[[iksnr.to_s, atc_code]]
    new_value ? new_value : atc_code
  end

  def Oddb2xml.log(msg)
    # return unless @options[:log]
    $stdout.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}: #{msg}"
    $stdout.flush
  end

  def Oddb2xml.save_options(options)
    @options = options
  end

  def Oddb2xml.skip_download?
    @options[:skip_download]
  end
  
  def Oddb2xml.skip_download(file)
    return false if defined?(VCR)
    dest = "#{Downloads}/#{File.basename(file)}"
    if File.exists?(dest)
      FileUtils.cp(dest, file, :verbose => false, :preserve => true) unless File.expand_path(file).eql?(dest)
      return true
    end
    false
  end
  
  def Oddb2xml.download_finished(file, remove_file = true)
    src  = "#{WorkDir}/#{File.basename(file)}"
    dest = "#{Downloads}/#{File.basename(file)}"
    FileUtils.makedirs(Downloads)
    #return unless File.exists?(file)
    return unless file and File.exists?(file)
    return if File.expand_path(file).eql?(dest)
    FileUtils.cp(src, dest, :verbose => false)
    Oddb2xml.log("download_finished saved as #{dest} #{File.size(dest)} bytes.")
  end                            
end
