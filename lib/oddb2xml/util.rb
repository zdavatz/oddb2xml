module Oddb2xml
  unless defined?(RSpec)
    WorkDir       = Dir.pwd
    Downloads     = "#{Dir.pwd}/downloads"
  end
  @options = {}

  def Oddb2xml.log(msg)
    return unless @options[:log]
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
    FileUtils.mv(src, dest, :verbose => false)
    Oddb2xml.log("download_finished saved as #{dest}")
  end                            
end
