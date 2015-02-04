# encoding: utf-8

require 'oddb2xml/util'
require 'yaml'
# require 'pry'

module Oddb2xml
 # Calc is responsible for analysing the columns "Packungsgrösse" and "Einheit"
 #
  GalenicGroup  = Struct.new("GalenicGroup", :oid, :descriptions)
  GalenicForm   = Struct.new("GalenicForm",  :oid, :descriptions, :galenic_group)

  class GalenicGroup
    def description(lang = 'de')
      descriptions[lang]
    end
  end

  class GalenicForm
    def description(lang = 'de')
      descriptions[lang]
    end
  end

  class Calc
    UnknownGalenicForm = 140
    UnknownGalenicGroup = 1
    Data_dir = File.expand_path(File.join(File.dirname(__FILE__),'..','..', 'data'))
    @@galenic_groups  = YAML.load_file(File.join(Data_dir, 'gal_groups.yaml'))
    @@galenic_forms   = YAML.load_file(File.join(Data_dir, 'gal_forms.yaml'))
    @@new_galenic_forms = []
    @@names_without_galenic_forms = []
    attr_accessor   :galenic_form, :unit, :pkg_size
    attr_reader     :name, :substances, :composition
    attr_reader     :selling_units, :count, :multi, :measure, :addition, :scale # s.a. commercial_form in oddb.org/src/model/part.rb
    def self.get_galenic_group(name, lang = 'de')
      @@galenic_groups.values.collect { |galenic_group|
        return galenic_group if galenic_group.descriptions[lang].eql?(name)
      }
      @@galenic_groups[1]
    end

    def self.get_galenic_form(name, lang = 'de')
      @@galenic_forms.values.collect { |galenic_form|
        return galenic_form if galenic_form.descriptions[lang].eql?(name)
        if name and galenic_form.descriptions[lang].eql?(name.sub(' / ', '/'))
          return galenic_form
        end
      }
      @@galenic_forms[UnknownGalenicForm]
    end

    def self.dump_new_galenic_forms
      if @@new_galenic_forms.size > 0
        "\nAdded the following galenic_forms\n"+ @@new_galenic_forms.uniq.join("\n")
      else
        "\nNo new galenic forms added"
      end
    end
    def self.dump_names_without_galenic_forms
      if @@names_without_galenic_forms.size > 0
        "\nThe following products did not have a galenic form in column Präparateliste\n"+ @@names_without_galenic_forms.sort.uniq.join("\n")
      else
        "\nColumn Präparateliste has everywhere a name\n"
      end
    end

    def initialize(name = nil, size = nil, unit = nil, composition= nil)
      @name = name
      @pkg_size = size
      @unit = unit
      # @pkg_size, @galenic_group, @galenic_form =
      search_galenic_info
      @composition = composition
      @galenic_form  ||= @@galenic_forms[UnknownGalenicForm]
    end
    def galenic_group
      @@galenic_groups[@galenic_form.galenic_group]
    end

    # helper for generating csv
    def headers
      ["name", "pkg_size", "count", "multi", "measure", "addition", "scale", "unit", "galenic_form", "galenic_group"]
    end
    def to_array
      [ @name, @pkg_size, @count, @multi, @measure, @addition, @scale, @unit,
        galenic_form  ? galenic_form.description  : '' ,
        galenic_group ? galenic_group.description : '' ]
    end
  private
    def capitalize(string)
      string.split(/\s+/u).collect { |word| word.capitalize }.join(' ')
    end

    def search_galenic_info

      @substances = nil
      @substances = @composition.split(/\s*,(?!\d|[^(]+\))\s*/u).collect { |name| capitalize(name) }.uniq if @composition

      name = @name.clone
      parts = name.split(',')
      if parts.size == 1
        @@names_without_galenic_forms << name
      else
        form_name = parts[-1].strip
        @galenic_form = Calc.get_galenic_form(form_name)
        # puts "oid #{UnknownGalenicForm} #{@galenic_form.oid} for #{name}"
        if @galenic_form.oid == UnknownGalenicForm
          @galenic_form =  GalenicForm.new(0, {'de' => form_name}, @@galenic_forms[UnknownGalenicForm] )
          @@new_galenic_forms << form_name
        end
      end
      @name = name.strip
      res = @pkg_size ? @pkg_size.split(/x/i) : []
      if res.size >= 1
        @count = res[0].to_i
      else
        @count = 1
      end
      if res.size >= 2
        @multi = res[1].to_i
      else
        @multi = 1
      end
      if res.size >= 3
        @measure = res[2].to_i.to_s + ' ' + (@unit ? @unit : '')
      else
        @measure = 0
      end
      @addition = 0
      @scale = 1
      @selling_units = @count * @multi
    end
  end
end