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
  
  def Oddb2xml.download_finished(file, remove_file = true)
    dest = "#{Backup}/#{File.basename(file)}"
    if @options[:skip_download]
      FileUtils.makedirs(Backup)
      FileUtils.cp(file, dest, :verbose => false)
    end
    begin
      File.unlink(file) if File.exists?(file) and remove_file
    rescue Errno::EACCES # Permission Denied on Windows      
    end
  end                            
end
