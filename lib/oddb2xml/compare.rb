# encoding: utf-8
require 'xmlsimple'

module Oddb2xml
  class CompareV5
    DEFAULTS = {
      :components => ["PRODUCTS", "LIMITATIONS", "ITEMS",],
      :fields_to_ignore => ['COMP', 'DOSAGE_FORMF', 'MEASUREF'],
      :fields_as_floats => [ 'PEXT', 'PEXF', 'PPUB' ],
      :min_diff_for_floats => 0.01,
    }
    def initialize(left, right)
      raise "File #{left} must exist" unless File.exist?(left)
      raise "File #{right} must exist" unless File.exist?(right)
      @left = left
      @right = right
      @l_base = File.basename(@left)
      @r_base = File.basename(@right)
      @diff_stat = {}
      @report = []
    end
    def compare(options = DEFAULTS)
      show_header("Start comparing #{@left} with #{@righ}t")
      @options = options
      @l_hash = load_file(@left)
      @r_hash = load_file(@right)
      if @l_hash['DATA_QUALITY'].eql?('3') ||  @r_hash['DATA_QUALITY'].eql?('3')
        components = ['ITEMS']
      else
        components = @options[:components]
      end
      components.each do |name|
        begin
          @diff_stat[name] = {}
          @diff_stat[name][NR_COMPARED] = 0
          puts "\nComparing #{name} in #{@l_base} with #{@r_base}"
          offset = 0
          offset = 1 if name.eql?('ITEMS')
          l_name = r_name = name
          if @r_hash['DATA_QUALITY'].eql?('3')
            r_name  = 'ITEM'
            r_names = @r_hash[r_name].collect{|item| item.keys}.flatten.uniq
            r_keys  = @r_hash[r_name].collect{|item| item['GTIN'].first.to_i }
          else
            r_keys  = @r_hash[r_name].first.values.first.collect{|item| item.values[offset].first.to_i}
            r_names = @r_hash[r_name].first.values.first.collect{|item| item.keys.first}.uniq
          end
          if @l_hash['DATA_QUALITY'].eql?('3')
            l_name  = 'ITEM'
            l_names = @l_hash[l_name].collect{|item| item.keys}.flatten.uniq
            l_keys  = @l_hash[l_name].collect{|item| item['GTIN'].first.to_i }
          else
            l_keys  = @l_hash[name].first.values.first.collect{|item| item.values[offset].first.to_i}
            l_names = @l_hash[l_name].first.values.first.collect{|item| item.keys.first}.uniq
          end
          compare_names = l_names & r_names
          compare_details(l_name, r_name, l_keys, r_keys, offset)
          key_results_details(l_name, l_keys, r_keys, compare_names)
        rescue => error
          puts "Execution failed with #{error}"
          binding.pry  if defined?(RSpec)
        end
      end
      show_header("Summary comparing #{@left} with #{@right}")
      puts "Ignored differences in #{@options[:fields_to_ignore]}. Signaled when differences in #{@options[:fields_as_floats]} were bigger than #{@options[:min_diff_for_floats]}"
      puts @report.join("\n")
      @diff_stat.each do |component, stats|
        puts "\nFor #{stats[NR_COMPARED]} #{component} we have the following number of differences per field"
        stats.each do |name, nr|
          next if name.eql?(NR_COMPARED)
          puts "   #{name.ljust(20)} #{nr}"
        end
      end
      @diff_stat
    rescue => error
      puts "Execution failed with #{error}"
      binding.pry if defined?(RSpec)
    end
    private
    NR_COMPARED = 'NR_COMPARED'
    def show_header(header)
      pad = 5
      puts
      puts '-'*(header.length+2*pad)
      puts ''.ljust(pad) + header
      puts '-'*(header.length+2*pad)
      puts
    end
    def compare_details(l_name, r_name, l_keys, r_keys, offset)
      found_one = false
      length = 32
      (l_keys & r_keys).each do |key|
        if @l_hash['DATA_QUALITY'].eql?('3')
          right = @r_hash[r_name].find{|item| item['GTIN'].first.to_i == key}
        else
          right = @r_hash[r_name].first.values.first.find{|item| item.values[offset].first.to_i == key}
        end
        if @l_hash['DATA_QUALITY'].eql?('3')
          left = @l_hash[l_name].find{|item| item['GTIN'].first.to_i == key}
        else
          left =  @l_hash[l_name].first.values.first.find{|item| item.values[offset].first.to_i == key}
        end
        found = false
        detail_name = left['DSCR'] ? left['DSCR'].first[0..length-1].rjust(length) : ''.rjust(length)
        details = "Diff in #{key.to_s.ljust(15)} #{detail_name}"
        diff_name = l_name
        diff_name += 'S' unless /S$/.match(diff_name)
        @diff_stat[diff_name] ||= {}
        @diff_stat[diff_name][NR_COMPARED] ||= 0
        @diff_stat[diff_name][NR_COMPARED] += 1
        left.keys.each do |sub_key|
          @diff_stat[diff_name][sub_key] ||= 0
          next if @options[:fields_to_ignore].index(sub_key)
          if @options[:fields_as_floats].index(sub_key)
            l_float = left[sub_key] ? left[sub_key].first.to_f : 0.0
            r_float = right[sub_key] ? right[sub_key].first.to_f : 0.0
            next if (l_float - r_float).abs < @options[:min_diff_for_floats]
          end
          next if (right[sub_key].is_a?(Array) && '--missing--'.eql?(right[sub_key].first)) || (left[sub_key].is_a?(Array) && '--missing--'.eql?(left[sub_key].first))
          next if right[sub_key].to_s.eql?(left[sub_key].to_s)
          next if right[sub_key].to_s.upcase.eql?(left[sub_key].to_s.upcase) && @options[:case_insensitive]
          details += " #{sub_key}: '#{left[sub_key]}' != '#{right[sub_key]}'"
          found = found_one = true
          @diff_stat[diff_name][sub_key] += 1
        end
        puts details.gsub(/[\[\]]/,'') if found
      end
    end
    def key_results_details(key_name, l_keys, r_keys, names)
      key_name += 'S' unless /S$/.match(key_name)
      @report <<  "#{key_name}: Found #{l_keys.size} items only in #{@l_base} #{r_keys.size} items only in #{@r_base}, compared #{@diff_stat[key_name][NR_COMPARED]} items"
      keys = r_keys - l_keys
      head = "#{key_name}: #{(keys).size} keys only in #{@r_base}"
      puts "#{head}: Keys were #{keys}"
      @report << head
      keys = l_keys - r_keys
      head = "#{key_name}: #{(keys).size} keys only in #{@l_base}"
      puts "#{head}: Keys were #{keys}"
      @report << head
    end
    def load_file(name)
      puts "Reading #{name} #{(File.size(name)/1024/1024).to_i} MB. This may take some time"
      left = XmlSimple.xml_in(IO.read(name))
    end
  end
end
