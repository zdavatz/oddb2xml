require "oddb2xml/util"
require "oddb2xml/parslet_compositions"
require "yaml"

module Oddb2xml
  # Calc is responsible for analysing the columns "Packungsgrösse" and "Einheit"
  #
  GalenicGroup = Struct.new("GalenicGroup", :oid, :descriptions)
  GalenicForm = Struct.new("GalenicForm", :oid, :descriptions, :galenic_group)

  class GalenicGroup
    def description(lang = "de")
      descriptions[lang]
    end
  end

  class GalenicForm
    def description(lang = "de")
      descriptions[lang]
    end
  end

  class Calc
    FLUIDFORMS = [
      "Ampulle(n)",
      "Beutel",
      "Bolus/Boli",
      "Bq",
      "Dose(n)",
      "Durchstechflasche(n)",
      "Einmaldosenbehälter",
      "Einzeldose(n)",
      "Fertigspritze",
      "Fertigspritze(n)",
      "Flasche(n)",
      "I.E.",
      "Infusionskonzentrat",
      "Infusionslösung",
      "Infusionsemulsion",
      "Inhalationen",
      "Inhalator",
      "Injektions-Set",
      "Injektions-Sets",
      "Injektor(en), vorgefüllt/Pen",
      "Klistier(e)",
      "MBq",
      "Pipetten",
      "Sachet(s)",
      "Spritze(n)",
      "Sprühstösse",
      "Stechampulle (Lyophilisat) und Ampulle (Solvens)",
      "Stechampulle",
      "Suspension",
      "Zylinderampulle(n)",
      "cartouches",
      "dose(s)",
      "flacon perforable",
      "sacchetto",
      "vorgefüllter Injektor"
    ]
    FESTE_FORMEN = [
      "Depotabs",
      "Dragée(s)",
      "Generator mit folgenden Aktivitäten:",
      "Filmtabletten",
      "Gerät",
      "Kapsel(n)",
      "Kautabletten",
      "Lutschtabletten",
      "Kugeln",
      "Ovulum",
      "Packung(en)",
      "Pflaster",
      "Schmelzfilme",
      "Set",
      "Strips",
      "Stück",
      "Suppositorien",
      "Tablette(n)",
      "Tüchlein",
      "Urethrastab",
      "Vaginalzäpfchen",
      "comprimé",
      "comprimé pelliculé",
      "comprimés",
      "comprimés à libération modifiée",
      "comprimés à croquer sécables",
      "imprägnierter Verband",
      "magensaftresistente Filmtabletten",
      "ovale Körper",
      "tube(s)"
    ]
    MEASUREMENTS = ["g", "kg", "l", "mg", "ml", "cm", "GBq"]
    OTHERS = ["Kombipackung", "emballage combiné"]
    UNKNOWN_GALENIC_FORM = 140
    UNKNOWN_GALENIC_GROUP = 1
    DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data"))
    @@galenic_groups = YAML.load_file(File.join(DATA_DIR, "gal_groups.yaml"))
    @@galenic_forms = YAML.load_file(File.join(DATA_DIR, "gal_forms.yaml"))
    @@new_galenic_forms = []
    @@names_without_galenic_forms = []
    @@rules_counter = {}
    attr_accessor :galenic_form, :unit, :pkg_size
    attr_reader :name, :substances, :composition, :compositions, :column_c
    attr_reader :selling_units, :count, :multi, :measure, :addition, :scale # s.a. commercial_form in oddb.org/src/model/part.rb
    def self.get_galenic_group(name, lang = "de")
      @@galenic_groups.values.collect { |galenic_group|
        return galenic_group if galenic_group.descriptions[lang].eql?(name)
      }
      @@galenic_groups[1]
    end

    def self.report_conversion
      lines = ["", "",
        "Report of used conversion rules",
        "-------------------------------",
        ""]
      @@rules_counter.each { |key, value|
        lines << "#{key}: #{value} occurrences"
      }
      lines << ""
      lines << ""
      lines
    end

    def self.get_galenic_form(name, lang = "de")
      @@galenic_forms.values.collect { |galenic_form|
        return galenic_form if galenic_form.descriptions[lang].eql?(name)
        if name && galenic_form.descriptions[lang].eql?(name.sub(" / ", "/"))
          return galenic_form
        end
      }
      @@galenic_forms[UNKNOWN_GALENIC_FORM]
    end

    def self.dump_new_galenic_forms
      if @@new_galenic_forms.size > 0
        "\n\n\nAdded the following galenic_forms\n" + @@new_galenic_forms.uniq.join("\n")
      else
        "\n\n\nNo new galenic forms added"
      end
    end

    def self.dump_names_without_galenic_forms
      if @@names_without_galenic_forms.size > 0
        "\n\n\nThe following products did not have a galenic form in column Präparateliste\n" + @@names_without_galenic_forms.sort.uniq.join("\n")
      else
        "\n\n\nColumn Präparateliste has everywhere a name\n"
      end
    end

    private

    def remove_duplicated_spaces(string)
      string ? string.to_s.gsub(/\s\s+/, " ") : nil
    end

    public

    def initialize(column_c = nil, size = nil, unit = nil, active_substance = nil, composition = nil)
      @column_c = column_c ? column_c.gsub(/\s\s+/, " ") : nil
      @name, gal_form = ParseGalenicForm.from_string(column_c)
      gal_form = gal_form.gsub(/\s\s+/, " ").sub(" / ", "/") if gal_form
      @galenic_form = search_galenic_info(gal_form)
      @pkg_size = remove_duplicated_spaces(size)
      @unit = unit
      @selling_units = getSellingUnits(@name, @pkg_size, @unit)
      @composition = composition
      @measure = unit if unit && !@measure
      if column_c
        unless @galenic_form
          parts = column_c.split(/\s+|,|-/)
          parts.each { |part|
            if (idx = searchExactGalform(part))
              @galenic_form = idx
              break
            end
          }
        end
      end
      if @measure && !@galenic_form
        @galenic_form ||= searchExactGalform(@measure)
        @galenic_form ||= searchExactGalform(@measure.sub("(n)", "n"))
      end
      handleUnknownGalform(gal_form)
      @measure = @galenic_form.description if @galenic_form && !@measure

      @compositions = if composition
        ParseUtil.parse_compositions(composition, active_substance)
      else
        []
      end
    end

    def galenic_group
      @@galenic_groups[@galenic_form.galenic_group]
    end

    # helper for generating csv
    def headers
      ["name", "pkg_size", "selling_units", "measure",
        # "count", "multi", "addition", "scale", "unit",
        "galenic_form",
        "galenic_group"]
    end

    def to_array
      [@name, @pkg_size, @selling_units, @measure,
        # @count, @multi, @addition, @scale, @unit,
        galenic_form ? galenic_form.description : "",
        galenic_group ? galenic_group.description : ""]
    end

    private

    def update_rule(rulename)
      @@rules_counter[rulename] ||= 0
      @@rules_counter[rulename] += 1
    end

    def getSellingUnits(part_from_name_c, pkg_size_l, einheit_m)
      # break_condition = (defined?(Pry) && false) # /5 x 2500 ml/.match(pkg_size_l))
      return pkgSizeToInt(pkg_size_l) unless part_from_name_c
      part_from_name_c = part_from_name_c.gsub(/[()]/, "_")
      MEASUREMENTS.each { |x|
        if einheit_m && /^#{x}$/i.match(einheit_m)
          puts "measurement in einheit_m #{einheit_m} matched: #{x}" if $VERBOSE
          update_rule("measurement einheit_m")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l, true)
        end
      }
      FESTE_FORMEN.each { |x|
        if part_from_name_c && (x.gsub(/[()]/, "_")).match(part_from_name_c)
          puts "feste_form in #{part_from_name_c} matched: #{x}" if $VERBOSE
          update_rule("feste_form name_C")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l)
        end
        if einheit_m && x.eql?(einheit_m)
          puts "feste_form in einheit_m #{einheit_m} matched: #{x}" if $VERBOSE
          update_rule("feste_form einheit_m")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l)
        end
      }
      FLUIDFORMS.each { |x|
        if part_from_name_c && x.match(part_from_name_c)
          puts "liquid_form in #{part_from_name_c} matched: #{x}" if $VERBOSE
          update_rule("liquid_form name_C")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l, true)
        end
        if part_from_name_c && x.match(part_from_name_c.split(" ")[0])
          puts "liquid_form in #{part_from_name_c} matched: #{x}" if $VERBOSE
          update_rule("liquid_form first_part")
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l, true)
        end
        if einheit_m && x.eql?(einheit_m)
          puts "liquid_form in einheit_m #{einheit_m} matched: #{x}" if $VERBOSE
          update_rule("liquid_form einheit_m")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l, MEASUREMENTS.find { |x| pkg_size_l.index(" #{x}") })
        end
      }
      MEASUREMENTS.each { |x|
        if pkg_size_l&.split(" ")&.index(x)
          puts "measurement in pkg_size_l #{pkg_size_l} matched: #{x}" if $VERBOSE
          update_rule("measurement pkg_size_l")
          @measure = x
          # binding.pry if break_condition
          return pkgSizeToInt(pkg_size_l, true)
        end
      }
      # binding.pry if break_condition
      puts "Could not find anything for name_C #{part_from_name_c} pkg_size_l: #{pkg_size_l} einheit_m #{einheit_m}" if $VERBOSE
      update_rule("unbekannt")
      "unbekannt"
    rescue RegexpError
      puts "RegexpError for M: #{einheit_m} pkg_size_l #{pkg_size_l} C: #{part_from_name_c}"
      update_rule("RegexpError")
      "error"
    end

    def pkgSizeToInt(pkg_size, skip_last_part = false)
      return pkg_size if pkg_size.is_a?(Integer)
      return 1 unless pkg_size
      parts = pkg_size.split(/\s*x\s*/i)
      parts = parts[0..-2] if skip_last_part && (parts.size > 1)
      last_multiplier = parts[-1].to_i > 0 ? parts[-1].to_i : 1
      if parts.size == 3
        parts[0].to_i * parts[1].to_i * last_multiplier
      elsif parts.size == 2
        parts[0].to_i * last_multiplier
      elsif parts.size == 1
        last_multiplier
      else
        1
      end
    end

    def searchExactGalform(name)
      return nil unless name
      if (idx = @@galenic_forms.values.find { |x| x.descriptions["de"] && x.descriptions["de"].downcase.eql?(name.downcase) }) ||
          (idx = @@galenic_forms.values.find { |x| x.descriptions["fr"] && x.descriptions["fr"].downcase.eql?(name.downcase) }) ||
          (idx = @@galenic_forms.values.find { |x| x.descriptions["en"] && x.descriptions["en"].downcase.eql?(name.downcase) })
        return idx
      end
      nil
    end

    def handleUnknownGalform(gal_form)
      return if @galenic_form
      if gal_form
        @galenic_form = GalenicForm.new(0, {"de" => remove_duplicated_spaces(gal_form.gsub(" +", " "))}, @@galenic_forms[UNKNOWN_GALENIC_FORM])
        @@new_galenic_forms << gal_form
      else
        @galenic_form = @@galenic_forms[UNKNOWN_GALENIC_FORM]
      end
    end

    def search_galenic_info(gal_form)
      if (idx = searchExactGalform(gal_form))
        return idx
      end
      if gal_form&.index(",")
        parts = gal_form.split(/\s+|,/)
        parts.each { |part|
          if (idx = searchExactGalform(part))
            return idx
          end
        }
      elsif gal_form
        if gal_form.eql?("capsule")
          idx = searchExactGalform("capsules")
          return idx
        end
        if (idx = searchExactGalform(gal_form))
          return idx
        end
      end
      nil
    end
  end
end
