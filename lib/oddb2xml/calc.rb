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
    attr_accessor   :galenic_form, :unit, :pkg_size
    attr_reader     :name, :substances, :composition
    attr_reader     :count, :multi, :measure, :addition, :scale # s.a. commercial_form in oddb.org/src/model/part.rb
    def self.get_galenic_group(name, lang = 'de')
      # @@galenic_groups.find{ |key, value| value.descriptions[lang].eql?(name) }.first
      @@galenic_groups.values.collect { |galenic_group|
        return galenic_group if galenic_group.descriptions[lang].eql?(name)
      }
      @@galenic_groups[1]
    end

    def self.get_galenic_form(name, lang = 'de')
      # @@galenic_forms.find{ |key, value| value.descriptions[lang].eql?(name) }.first
      @@galenic_forms.values.collect { |galenic_form|
        return galenic_form if galenic_form.descriptions[lang].eql?(name)
        return galenic_form if galenic_form.descriptions[lang].eql?(name.sub(' / ', '/'))
      }
      @@galenic_forms[UnknownGalenicForm]
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
  private
    def capitalize(string)
      string.split(/\s+/u).collect { |word| word.capitalize }.join(' ')
    end

    def search_galenic_info

      @substances = nil
      @substances = @composition.split(/\s*,(?!\d|[^(]+\))\s*/u).collect { |name| capitalize(name) }.uniq if @composition

      name = @name.clone
      parts = name.split(/\s*,(?!\d|[^(]+\))\s*/u)
      unless name = parts.first[/[^\d]{3,}/]
       name = parts.last[/[^\d]{3,}/]
      end
      @galenic_form = Calc.get_galenic_form(parts[1]) if parts.size > 1
      name.strip! if name
      @name = name
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
    end
    def update_galenic_form(seq, comp, row, opts={})
      opts = {:create_only => false}.merge opts
      return if comp.galenic_form && !opts[:fix_galenic_form]
      if((german = seq.name_descr) && !german.empty?)
        _update_galenic_form(comp, :de, german)
      elsif(match = GALFORM_P.match(comp.source.to_s))
        _update_galenic_form(comp, :lt, match[:galform].strip)
      end
    end
    def _update_galenic_form(comp, lang, name)
      # remove counts and doses from the name - this is assuming name looks
      # (in the worst case) something like this: "10 Filmtabletten"
      # or: "Infusionsemulsion, 1875ml"
      parts = name.split(/\s*,(?!\d|[^(]+\))\s*/u)
      unless name = parts.first[/[^\d]{3,}/]
       name = parts.last[/[^\d]{3,}/]
      end
      name.strip! if name

      unless(gf = @app.galenic_form(name))
        ptr = Persistence::Pointer.new([:galenic_group, 1],
                                       [:galenic_form]).creator

        @app.update(ptr, {lang => name}, :swissmedic)
      end
      @app.update(comp.pointer, { :galenic_form => name }, :swissmedic)
    end

  end

end