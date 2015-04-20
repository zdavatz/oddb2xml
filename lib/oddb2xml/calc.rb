# encoding: utf-8

require 'oddb2xml/util'
require 'oddb2xml/parslet_compositions'
require 'yaml'

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
    FluidForms = [
      'Ampulle(n)',
      'Beutel',
      'Bolus/Boli',
      'Bq',
      'Dose(n)',
      'Durchstechflasche(n)',
      'Einmaldosenbehälter',
      'Einzeldose(n)',
      'Fertigspritze',
      'Fertigspritze(n)',
      'Flasche(n)',
      'I.E.',
      'Infusionskonzentrat',
      'Infusionslösung',
      'Infusionsemulsion',
      'Inhalationen',
      'Inhalator',
      'Injektions-Set',
      'Injektions-Sets',
      'Injektor(en), vorgefüllt/Pen',
      'Klistier(e)',
      'MBq',
      'Pipetten',
      'Sachet(s)',
      'Spritze(n)',
      'Sprühstösse',
      'Stechampulle (Lyophilisat) und Ampulle (Solvens)',
      'Stechampulle',
      'Suspension',
      'Zylinderampulle(n)',
      'cartouches',
      'dose(s)',
      'flacon perforable',
      'sacchetto',
      'vorgefüllter Injektor',
      ]
    FesteFormen = [
      'Depotabs',
      'Dragée(s)',
      'Generator mit folgenden Aktivitäten:',
      'Filmtabletten',
      'Gerät',
      'Kapsel(n)',
      'Kautabletten',
      'Lutschtabletten',
      'Kugeln',
      'Ovulum',
      'Packung(en)',
      'Pflaster',
      'Schmelzfilme',
      'Set',
      'Strips',
      'Stück',
      'Suppositorien',
      'Tablette(n)',
      'Tüchlein',
      'Urethrastab',
      'Vaginalzäpfchen',
      'comprimé',
      'comprimé pelliculé',
      'comprimés',
      'comprimés à libération modifiée',
      'comprimés à croquer sécables',
      'imprägnierter Verband',
      'magensaftresistente Filmtabletten',
      'ovale Körper',
      'tube(s)',
    ]
    Measurements = [ 'g', 'kg', 'l', 'mg', 'ml', 'cm', 'GBq']
    Others = ['Kombipackung', 'emballage combiné' ]
    UnknownGalenicForm = 140
    UnknownGalenicGroup = 1
    Data_dir = File.expand_path(File.join(File.dirname(__FILE__),'..','..', 'data'))
    @@galenic_groups  = YAML.load_file(File.join(Data_dir, 'gal_groups.yaml'))
    @@galenic_forms   = YAML.load_file(File.join(Data_dir, 'gal_forms.yaml'))
    @@new_galenic_forms = []
    @@names_without_galenic_forms = []
    @@rules_counter = {}
    attr_accessor   :galenic_form, :unit, :pkg_size
    attr_reader     :name, :substances, :composition, :compositions
    attr_reader     :selling_units, :count, :multi, :measure, :addition, :scale # s.a. commercial_form in oddb.org/src/model/part.rb
    def self.get_galenic_group(name, lang = 'de')
      @@galenic_groups.values.collect { |galenic_group|
        return galenic_group if galenic_group.descriptions[lang].eql?(name)
      }
      @@galenic_groups[1]
    end

    def self.report_conversion
      lines = [ '', '',
                'Report of used conversion rules',
                '-------------------------------',
                ''
                ]
      @@rules_counter.each{
        | key, value|
          lines << "#{key}: #{value} occurrences"
      }
      lines << ''
      lines << ''
      lines
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
        "\n\n\nAdded the following galenic_forms\n"+ @@new_galenic_forms.uniq.join("\n")
      else
        "\n\n\nNo new galenic forms added"
      end
    end
    def self.dump_names_without_galenic_forms
      if @@names_without_galenic_forms.size > 0
        "\n\n\nThe following products did not have a galenic form in column Präparateliste\n"+ @@names_without_galenic_forms.sort.uniq.join("\n")
      else
        "\n\n\nColumn Präparateliste has everywhere a name\n"
      end
    end
private
    def remove_duplicated_spaces(string)
      string ? string.to_s.gsub(/\s\s+/, ' ') : nil
    end
public
    def initialize(name = nil, size = nil, unit = nil, active_substance = nil, composition= nil)
      @name = remove_duplicated_spaces(name)
      @pkg_size = remove_duplicated_spaces(size)
      @unit = unit
      # @pkg_size, @galenic_group, @galenic_form =
      search_galenic_info
      @composition = composition
      @measure = unit if unit and not @measure
      @measure = @galenic_form.description if @galenic_form and not @measure
      @galenic_form  ||= @@galenic_forms[UnknownGalenicForm]

      unless composition
        @compositions = []
      else
        @compositions = ParseUtil.parse_compositions(composition, active_substance)
      end
    end

    def galenic_group
      @@galenic_groups[@galenic_form.galenic_group]
    end

    # helper for generating csv
    def headers
      [ "name", "pkg_size", "selling_units", "measure",
        # "count", "multi", "addition", "scale", "unit",
        "galenic_form",
        "galenic_group"
        ]
    end
    def to_array
      [ @name, @pkg_size, @selling_units, @measure,
        # @count, @multi, @addition, @scale, @unit,
        galenic_form  ? galenic_form.description  : '' ,
        galenic_group ? galenic_group.description : ''
        ]
    end
    def galenic_form__xxx
      @galenic_form.description
    end
  private

    def update_rule(rulename)
      @@rules_counter[rulename] ||= 0
      @@rules_counter[rulename] += 1
    end

    def get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
      begin
        return pkg_size_to_int(pkg_size_L) unless part_from_name_C
        part_from_name_C = part_from_name_C.gsub(/[()]/, '_')
        Measurements.each{ |x|
                          if einheit_M and /^#{x}$/i.match(einheit_M)
                            puts "measurement in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('measurement einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                        }
        FesteFormen.each{ |x|
                          if part_from_name_C and (x.gsub(/[()]/, '_')).match(part_from_name_C)
                            puts "feste_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('feste_form name_C')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L)
                          end
                          if einheit_M and x.eql?(einheit_M)
                            puts "feste_form in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('feste_form einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L)
                          end
                        }
        FluidForms.each{ |x|
                          if part_from_name_C and x.match(part_from_name_C)
                            puts "liquid_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form name_C')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                          if part_from_name_C and x.match(part_from_name_C.split(' ')[0])
                            puts "liquid_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form first_part')
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                          if einheit_M and x.eql?(einheit_M)
                            puts "liquid_form in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, false)
                          end
                        }
        Measurements.each{ |x|
                          if pkg_size_L and pkg_size_L.split(' ').index(x)
                            puts "measurement in pkg_size_L #{pkg_size_L} matched: #{x}" if $VERBOSE
                            update_rule('measurement pkg_size_L')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                        }
        puts "Could not find anything for name_C #{part_from_name_C} pkg_size_L: #{pkg_size_L} einheit_M #{einheit_M}" if $VERBOSE
        update_rule('unbekannt')
        return 'unbekannt'
      rescue RegexpError => e
        puts "RegexpError for M: #{einheit_M} pkg_size_L #{pkg_size_L} C: #{part_from_name_C}"
        update_rule('RegexpError')
        return 'error'
      end
    end

    def pkg_size_to_int(pkg_size, skip_last_part = false)
      return pkg_size if pkg_size.is_a?(Fixnum)
      return 1 unless pkg_size
      parts = pkg_size.split(/\s*x\s*/i)
      parts = parts[0..-2] if skip_last_part and parts.size > 1
      last_multiplier = parts[-1].to_i > 0 ? parts[-1].to_i : 1
      if parts.size == 3
        return parts[0].to_i * parts[1].to_i * last_multiplier
      elsif parts.size == 2
        return parts[0].to_i * last_multiplier
      elsif parts.size == 1
        return last_multiplier
      else
        return 1
      end
    end
    # Parse a string for a numerical value and unit, e.g. 1.5 ml
    def self.check_for_value_and_units(what)
      if m = /^([\d.]+)\s*(\D+)/.match(what)
        # return [m[1], m[2] ]
        return m[0].to_s
      else
        nil
      end
    end
    def search_galenic_info
      @substances = nil
      @substances = @composition.split(/\s*,(?!\d|[^(]+\))\s*/u).collect { |name| ParseUtil.capitalize(name) }.uniq if @composition

      name = @name ? @name.clone : ''
      parts = name.split(',')
      form_name = nil
      if parts.size == 0
      elsif parts.size == 1
        @@names_without_galenic_forms << name
      else
        parts[1..-1].each{
          |part|
          form_name = part.strip
          @galenic_form = Calc.get_galenic_form(form_name)
          # puts "oid #{UnknownGalenicForm} #{@galenic_form.oid} for #{name}"
          break unless @galenic_form.oid == UnknownGalenicForm
          if @galenic_form.oid == UnknownGalenicForm
            @galenic_form =  GalenicForm.new(0, {'de' => remove_duplicated_spaces(form_name.gsub(' +', ' '))}, @@galenic_forms[UnknownGalenicForm] )
            @@new_galenic_forms << form_name
          end
        }
      end
      @name = name.strip
      if @pkg_size.is_a?(Fixnum)
        @count = @pkg_size
        res = [@pkg_size]
      else
        res = @pkg_size ? @pkg_size.split(/x/i) : []
        if res.size >= 1
          @count = res[0].to_i
        else
          @count = 1
        end
      end
      # check whether we find numerical and units
      if res.size >= 2
        if (result = Calc.check_for_value_and_units(res[1].strip)) != nil
          @multi = result[1].to_f
        else
          @multi = res[1].to_i
        end
      else
        @multi = 1
      end
      @addition = 0
      @scale = 1
      @selling_units = get_selling_units(form_name, @pkg_size, @unit)
    end
  end
end