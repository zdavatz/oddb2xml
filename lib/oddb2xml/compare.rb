# encoding: utf-8
require 'xmlsimple'

module Oddb2xml
  def self.log_timestamp(msg)
    full_msg = "#{Time.now.strftime("%H:%M:%S")}: #{msg}"
    puts full_msg
    STDOUT.flush
    full_msg
  end
  class StammXML
    V3_NAME_REG = /_([N,P])_/
    attr_accessor :components
    attr_reader :keys, :sub_key_names, :filename, :basename, :version, :hash
    def initialize(filename, components =  ['ITEMS'])
      raise "File #{filename} must exist" unless File.exist?(filename)
      @filename = filename
      @basename = File.basename(filename)
      @version =  V3_NAME_REG.match(filename) ? 3 : 5
      @components = components
      if @version == 5
        @hash = load_file(@filename)
      else
        raise "Unsupported version #{@version}"
      end
    end
    def self.get_component_key_name(component_name)
        return 'LIMNAMEBAG' if /LIMITATION/i.match(component_name)
        return 'PRODNO' if /PRODUCT/i.match(component_name)
        return 'GTIN' if /ITEM/i.match(component_name)
        raise "Cannot determine keyname for component #{component_name}"
    end
    def get_limitation_from_v5(item)
      get_item('PRODUCTS', item['PRODNO'].first.to_i)['LIMNAMEBAG'] ? ['true'] : nil
    end
    def get_field_from_v5_product(item, field_name)
      get_item('PRODUCTS', item['PRODNO'].first.to_i)[field_name]
    end
    def get_items(component_name)
      if @version == 3
        items = @hash[component_name]
      else
        items = @hash[component_name].first.values.first
      end
      items
    end
    def get_item(component_name, id)
      keyname = StammXML.get_component_key_name(component_name)
      get_items(component_name).find{|item| item[keyname].first.to_i == id}
    end
    def load_file(name)
      Oddb2xml.log_timestamp "Reading #{name} #{(File.size(name)/1024/1024).to_i} MB. This may take some time"
      XmlSimple.xml_in(IO.read(name))
    end
  end
  class CompareV5
    DEFAULTS = {
      :components => ["PRODUCTS", "LIMITATIONS", "ITEMS",],
      :fields_to_ignore => ['COMP', 'DOSAGE_FORMF', 'MEASUREF'],
      :fields_as_floats => [ 'PEXT', 'PEXF', 'PPUB' ],
      :min_diff_for_floats => 0.01,
    }
    def initialize(left, right, options = DEFAULTS.clone)
      @options = options
      @left = StammXML.new(left, @options[:components])
      @right = StammXML.new(right, @options[:components])
      @diff_stat = {}
      @occurrences = {}
      @report = []
    end
    def get_keys(items, key='GTIN')
      items.collect{|item| item[key].first.to_i }
    end
    def get_names(items)
       items.collect{|item| item.keys}.flatten.uniq.sort
    end
    def compare
      show_header("Start comparing #{@left.filename} with #{@right.filename}")
      (@left.components & @right.components).each do |name|
        begin
          puts "\n#{Time.now.strftime("%H:%M:%S")}: Comparing #{name} in #{@left.basename} with #{@right.basename}"
          key = StammXML.get_component_key_name(name)
          left_items = @left.get_items(name)
          next unless left_items
          right_items = @right.get_items(name)
          next unless right_items
          @diff_stat[name] = {}
          @occurrences[name] = {}
          @diff_stat[name][NR_COMPARED] = 0
          l_names = get_names(left_items)
          r_names = get_names(right_items)
          compare_names = l_names & r_names
          l_keys = get_keys(left_items, key)
          r_keys = get_keys(right_items, key)
          (l_keys & r_keys).each do |id|
            compare_details(name, compare_names, id)
          end
          key_results_details(name, compare_names, l_keys, r_keys)
        rescue => error
          puts "Execution failed with #{error}"
        end
      end
      show_header("Summary comparing #{@left.filename} with #{@right.filename}")
      puts "Ignored differences in #{@options[:fields_to_ignore]}. Signaled when differences in #{@options[:fields_as_floats]} were bigger than #{@options[:min_diff_for_floats]}"
      puts @report.join("\n")
      @diff_stat.each do |component, stats|
        puts "\nFor #{stats[NR_COMPARED]} #{component} we have the following number of differences per field"
        stats.each do |name, nr|
          next if name.eql?(NR_COMPARED)
          next if @options[:fields_to_ignore].index(name)
          puts "   #{name.ljust(20)} #{nr} of #{@occurrences[component][name]}"
        end
      end
      @diff_stat
    rescue => error
      puts "Execution failed with #{error}"
      raise error
    end
    private
    NR_COMPARED = 'NR_COMPARED'
    COUNT       = '_count'
    def show_header(header)
      text = Oddb2xml.log_timestamp(header)
      pad = 5
      puts
      puts '-'*(text.length+2*pad)
      puts ''.ljust(pad) + text
      puts '-'*(text.length+2*pad)
      puts
    end
    def compare_details(component_name, compare_names, id)
      l_item = @left.get_item(component_name, id)
      r_item = @right.get_item(component_name, id)
      found_one = false
      length = 32
      found = false
      detail_name = l_item['DSCR'] ? l_item['DSCR'].first[0..length-1].rjust(length) : ''.rjust(length)
      details = "Diff in #{id.to_s.ljust(15)} #{detail_name}"
      diff_name = component_name
      diff_name += 'S' unless /S$/.match(diff_name)
      @diff_stat[diff_name] ||= {}
      @occurrences[diff_name] ||= {}
      @diff_stat[diff_name][NR_COMPARED] ||= 0
      @diff_stat[diff_name][NR_COMPARED] += 1
      l_item.keys.each do |sub_key|
        next if @options[:fields_to_ignore].index(sub_key)
        @diff_stat[diff_name][sub_key] ||= 0
        @occurrences[diff_name][sub_key] ||= 0
        @occurrences[diff_name][sub_key] += 1
        r_value = r_item[sub_key]
        l_value = l_item[sub_key]
        if @options[:fields_as_floats].index(sub_key)
          l_float = l_value ? l_value.first.to_f : 0.0
          r_float = r_value ? r_value.first.to_f : 0.0
          next if (l_float - r_float).abs < @options[:min_diff_for_floats]
        end
        next if (r_value.is_a?(Array) && '--missing--'.eql?(r_value.first)) || (l_value.is_a?(Array) && '--missing--'.eql?(l_value.first))
                # TODO: get_field_from_v5_product
        next if r_value.to_s.eql?(l_value.to_s)
        next if r_value.to_s.upcase.eql?(l_value.to_s.upcase) && @options[:case_insensitive]
        details += " #{sub_key}: '#{l_value}' != '#{r_value}'"
        found = found_one = true
        @diff_stat[diff_name][sub_key] += 1
      end
      puts details.gsub(/[\[\]]/,'') if found
    end

    def show_keys(keys, batch_size = 20)
      0.upto(keys.size) do |idx|
        next unless idx % batch_size == 0
        puts '  ' + keys[idx..(idx + batch_size-1)].join(' ')
      end
    end
    def key_results_details(component_name, compare_names, l_keys, r_keys)
      component_name += 'S' unless /S$/.match(component_name)
      @report <<  "#{component_name}: Found #{l_keys.size} items only in #{@left.basename} #{r_keys.size} items only in #{@right.basename}, compared #{@diff_stat[component_name][NR_COMPARED]} items"
      keys = r_keys - l_keys
      head = "#{component_name}: #{(keys).size} keys only in #{@right.basename}"
      puts "#{head}: Keys were #{keys.size}"
      show_keys(keys)
      @report << head
      keys = l_keys - r_keys
      head = "#{component_name}: #{(keys).size} keys only in #{@left.basename}"
      puts "#{head}: Keys were #{keys.size}"
      show_keys(keys)
      @report << head
    end
  end
end
