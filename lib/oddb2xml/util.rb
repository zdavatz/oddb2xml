module Oddb2xml
  Backup = "#{Dir.pwd}/data/download"
  @options = {}
  
  def Oddb2xml.save_options(options)
    @options = options
  end
  
  def Oddb2xml.skip_download(file)
    dest = "#{Backup}/#{File.basename(file)}"
    return false unless @options[:skip_download]
    if File.exists?(dest)
      FileUtils.cp(dest, file, :verbose => false, :preserve => true)
      return true
    end
    false
  end
  
  def Oddb2xml.download_finished(file)
    dest = "#{Backup}/#{File.basename(file)}"
    FileUtils.makedirs(Backup)
    FileUtils.cp(file, dest, :verbose => false)
    begin
      File.unlink(file) if File.exists?(file)
    rescue Errno::EACCES # Permission Denied on Windows      
    end
  end                            
end
