# encoding: utf-8
require 'xmlsimple'

module Oddb2xml
  class CompareV5
    def initialize(left, right)
      raise "File #{left} must exist" unless File.exist?(left)
      raise "File #{right} must exist" unless File.exist?(right)
      @left = left
      @right = right
      @l_base = File.basename(@left)
      @r_base = File.basename(@right)
    end
    def compare(options = {})
      @l_hash = load_file(@left)
      @r_hash = load_file(@right)
      ["PRODUCTS", 
        "LIMITATIONS",
        "ITEMS",
       ].each do |name|
        begin
          puts "\nComparing #{name} in #{@l_base} with #{@r_base}"
          offset = 0
          offset = 1 if name.eql?('ITEMS')
          r_keys = @r_hash[name].first.values.first.collect{|item| item.values[offset].first.to_i}
          l_keys = @l_hash[name].first.values.first.collect{|item| item.values[offset].first.to_i}

          key_name = @r_hash[name].first.keys.first
          # TODO: Check all keys
          l_names = @l_hash[name].first.values.first.collect{|item| item.keys.first}.uniq
          r_names = @r_hash[name].first.values.first.collect{|item| item.keys.first}.uniq
          raise "Compare errro" unless l_names.to_s.eql?(r_names.to_s)
          key_results(key_name, l_keys, r_keys, l_names)
          compare_details(name, l_keys, r_keys, offset)
        rescue => error
          puts "Execution failed with #{error}"
          binding.pry  if defined?(RSpec)
        end
      end
      puts "Ignored differences in #{SUBKEYS_TO_IGNORE}"
      true
    rescue => error
      puts "Execution failed with #{error}"
      binding.pry if defined?(RSpec)
    end
    private
    SUBKEYS_TO_IGNORE = ['COMP', 'DOSAGE_FORMF', 'MEASUREF']
    def compare_details(name, l_keys, r_keys, offset)
      found_one = false
      (l_keys & r_keys).each do |key|
        right = @r_hash[name].first.values.first.find{|item| item.values[offset].first.to_i == key}
        left =  @l_hash[name].first.values.first.find{|item| item.values[offset].first.to_i == key}
        found = false
        details = "Diff in #{key}"
        left.keys.each do |sub_key|
          next if SUBKEYS_TO_IGNORE.index(sub_key)
          next if (right[sub_key].is_a?(Array) && '--missing--'.eql?(right[sub_key].first)) || (left[sub_key].is_a?(Array) && '--missing--'.eql?(left[sub_key].first))
          next if right[sub_key].to_s.eql?(left[sub_key].to_s)
          details += " #{sub_key}: '#{left[sub_key]}' != '#{right[sub_key]}'"
          found = found_one = true
        end
        puts details.gsub(/[\[\]]/,'') if found
      end
    end
    def key_results(key_name, l_keys, r_keys, names)    
        puts "#{key_name}: Found #{l_keys.size} items in #{@l_base}"
        puts "#{key_name}: Found #{r_keys.size} items in #{@r_base}"
        puts "#{key_name}: Found #{(l_keys&r_keys).size} items in both files"
        puts "#{key_name}: Keys only in #{@l_base} are: #{r_keys - l_keys}"
        puts "#{key_name}: Keys only in #{@r_base} are: #{l_keys - r_keys}"
    end
    def load_file(name)
      puts "Reading #{name} #{(File.size(name)/1024/1024).to_i} MB. This may take some time"
      left = XmlSimple.xml_in(IO.read(name))
    end
    def compare_count(pattern)
      lines = []
      lines << "comparing count for #{pattern}"
      lines <<  "-------------------------------"
      cmd = 'grep -c '+ pattern +  ' '+ ALT
      nr_old = `#{cmd}`.strip.to_i
      cmd = 'grep -c '+ pattern +  ' '+ NEU
      nr_new = `#{cmd}`.strip.to_i
      lines <<  "PHARMATYPE N: #{nr_old} alte #{nr_new} neue"
      diff = (nr_old- nr_new).abs
      if diff > 100
        lines << "Viel zu verschiedene Einträge (#{diff}) für #{pattern}"
        lines << ""
        puts lines
      else
        puts "Comparing #{pattern} looks good. Found #{diff} differences. #{nr_old} #{nr_new}"
      end
    end

    def check_via_xsd
      `xmllint --noout --schema Elexis_Artikelstamm_v5.xsd #{NEU}`
    end

    def compare_gtin
      system('grep "<GTIN>" ' + ALT + ' | sort > gtin_alt.sorted')
      system('grep "<GTIN>" ' + NEU + ' | sort > gtin_neu.sorted')
      lines_alt = File.readlines('gtin_alt.sorted')
      gtins_alt = []
      lines_alt.each { |line| gtins_alt <</\d+/.match(line)[0] }
      lines_neu = File.readlines('gtin_neu.sorted')
      gtins_neu = []
      lines_neu.each { |line| gtins_neu <</\d+/.match(line)[0] }
      gtins_neu.size
      puts "Found #{(gtins_neu - gtins_alt).size} different gtins"
      File.open('gtin_diffs.txt', 'w+') { |f| f.puts (gtins_neu - gtins_alt).join("\n") }
      File.open('gtin_neu_only.txt', 'w+') do |f|
        (gtins_neu - gtins_alt).each do |gtin_neu|
          f.puts gtin_neu
        end
      end
      # 4029679330030
      File.open('gtin_alt_only.txt', 'w+') do |f|
        (gtins_alt - gtins_neu).each do |gtin_alt|
          f.puts gtin_alt
        end
      end
      puts "Found #{(gtins_alt - gtins_neu).size} GTINS only in #{ALT}. GTINS listed in gtin_alt_only.txt"
      puts "Found #{(gtins_neu - gtins_alt).size} GTINS only in #{NEU}. GTINS listed in gtin_neu_only.txt"
    end
  end
end
