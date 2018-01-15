# encoding: utf-8
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
  @atc_csv_origin = 'http://download.epha.ch/data/atc/atc.csv'
  @atc_csv_content = {}

  def Oddb2xml.convert_to_8859_1(line)
    begin
      # We want to ignore lines which are not really UTF-8 encoded
      return line.encode('ISO-8859-1')
    rescue => error
      ausgabe = ''
      0.upto(line.size-1).each do |idx|
        begin
          if line[idx].ord == 8211
            ausgabe += '-'
          else
            ausgabe += line[idx].encode('ISO-8859-1')
          end
        rescue => error
          puts "#{error}: in #{line} at #{idx}"
        end
      end
    end
    ausgabe.encode('ISO-8859-1')
  end

  def Oddb2xml.add_epha_changes_for_ATC(iksnr, atc_code, force_run: false)
    @atc_csv_content  =  {} if force_run
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
    return unless @options[:log]
    # TODO:: require 'pry'; binding.pry if msg.size > 1000
    $stdout.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}: #{msg[0..250]}"
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

  # please keep this constant in sync between (GEM) swissmedic-diff/lib/swissmedic-diff.rb and (GEM) oddb2xml/lib/oddb2xml/extractor.rb
  def Oddb2xml.check_column_indices(sheet)
    row = sheet[4] # Headers are found at row 4

    error_2015 = nil
    COLUMNS_JULY_2015.each{
      |key, value|
      header_name = row[COLUMNS_JULY_2015.keys.index(key)].value.to_s
      unless value.match(header_name)
        puts "#{__LINE__}: #{key} ->  #{COLUMNS_JULY_2015.keys.index(key)} #{value}\nbut was  #{header_name}" if $VERBOSE
        error_2015 = "Packungen.xlslx_has_unexpected_column_#{COLUMNS_JULY_2015.keys.index(key)}_#{key}_#{value.to_s}_but_was_#{header_name}"
        break
      end
    }
    raise "#{error_2015}" if error_2015
  end

  # please keep this constant in sync between (GEM) swissmedic-diff/lib/swissmedic-diff.rb and (GEM) oddb2xml/lib/oddb2xml/extractor.rb
  COLUMNS_JULY_2015 = {
      :iksnr => /Zulassungs-Nummer/i,                  # column-nr: 0
      :seqnr => /Dosisstärke-nummer/i,
      :name_base => /Präparatebezeichnung/i,
      :company => /Zulassungsinhaberin/i,
      :production_science => /Heilmittelcode/i,
      :index_therapeuticus => /IT-Nummer/i,            # column-nr: 5
      :atc_class => /ATC-Code/i,
      :registration_date => /Erstzulassungs-datum./i,
      :sequence_date => /Zul.datum Dosisstärke/i,
      :expiry_date => /Gültigkeitsdauer der Zulassung/i,
      :ikscd => /Packungscode/i,                 # column-nr: 10
      :size => /Packungsgrösse/i,
      :unit => /Einheit/i,
      :ikscat => /Abgabekategorie Packung/i,
      :ikscat_seq => /Abgabekategorie Dosisstärke/i,
      :ikscat_preparation => /Abgabekategorie Präparat/i, # column-nr: 15
      :substances => /Wirkstoff/i,
      :composition => /Zusammensetzung/i,
      :indication_registration => /Anwendungsgebiet Präparat/i,
      :indication_sequence => /Anwendungsgebiet Dosisstärke/i,
      :gen_production => /Gentechnisch hergestellte Wirkstoffe/i, # column-nr 20
      :insulin_category => /Kategorie bei Insulinen/i,
      :drug_index       => /Verz. bei betäubunsmittel-haltigen Präparaten/i,
  }

  def Oddb2xml.add_hash(string)
    doc = Nokogiri::XML.parse(string)
    nr = 0
    doc.root.elements.each do |node|
      nr += 1
      next if node.name.eql?('RESULT')
      node['SHA256'] = Digest::SHA256.hexdigest node.text
    end
    doc.to_xml
  end

  def Oddb2xml.verify_sha256(file)
    f = File.open(file)
    doc = Nokogiri::XML(f)
    nr = 0
    doc.root.elements.each do |node|
      nr += 1
      next if node.name.eql?('RESULT')
      sha256 = Digest::SHA256.hexdigest node.text
      unless node['SHA256'].eql?(sha256)
        puts "Verifiying #{node['SHA256']} != expectd #{sha256} against node #{node.text} failed"
        exit (3)
      end
    end
    return true
  end
end
