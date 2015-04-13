# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

module ParseUtil
  SCALE_P = %r{pro\s+(?<scale>(?<qty>[\d.,]+)\s*(?<unit>[kcmuµn]?[glh]))}u
  ParseComposition   = Struct.new("ParseComposition",  :source, :label, :label_description, :substances, :galenic_form, :route_of_administration)
  ParseSubstance     = Struct.new("ParseSubstance",    :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose)
  def ParseUtil.capitalize(string)
    string.split(/\s+/u).collect { |word| word.capitalize }.join(' ')
  end

  def ParseUtil.dose_to_qty_unit(string, filler=nil)
    return nil unless string
    dose = string.split(/\b\s*(?![.,\d\-]|Mio\.?)/u, 2)
    if dose && (scale = SCALE_P.match(filler)) && dose[1] && !dose[1].include?('/')
      unit = dose[1] << '/'
      num = scale[:qty].to_f
      if num <= 1
        unit << scale[:unit]
      else
        unit << scale[:scale]
      end
      dose[1] = unit
    elsif dose and dose.size == 2
      unit = dose[1]
    end
    dose
  end

  def ParseUtil.parse_compositions(composition, active_agents_string = '')
    rep_1 = '----';   to_1 = '('
    rep_2 = '-----';  to_2 = ')'
    rep_3 = '------'; to_3 = ','
    active_agents = active_agents_string ? active_agents_string.downcase.split(/,\s+/) : []
    comps = []
    label_pattern = /^(?<label>A|I|B|II|C|III|D|IV|E|V|F|VI)(\):|\))\s*(?<description>[^:]+):\s+(?<content>.+)/
    label_pattern = /^(?<label>A|I|B|II|C|III|D|IV|E|V|F|VI)(\):|\))\s*(?<description>[^:]+):\s+(?<content>.+)(?<conserv>(conserv.:).+|)(?<residui>(residui:).+|)/
    label_pattern = /^(?<preparation>Praeparatio[^:]+|(?<label>A|I|B|II|C|III|D|IV|E|V|F|VI|)(\):|\))\s*(?<description>[^:]+)):\s+(?<content>.+)(?<conserv>(conserv.:).+|)(?<residui>(residui:).+|)/
    composition_text = composition.gsub(/\r\n?/u, "\n")
    puts "composition_text for #{name}: #{composition_text}" if composition_text.split(/\n/u).size > 1 and $VERBOSE
    lines = composition_text.split(/\n/u)
    idx = 0
    compositions = lines.select do |line|
      if match = label_pattern.match(line)
        label = match[:label]
        label_description = match[:description]
        content  = match[:content].strip.sub(/,$/, '')
      else
        label = nil
        label_description = nil
        content = line
      end
      idx += 1
      next if idx > 1 and /^(?<label>A|I|B|II|C|III|D|IV|E|V|F|VI)[)]\s*(et)/.match(line) # avoid lines like 'I) et II)'
      next if idx > 1 and /^Corresp\./i.match(line) # avoid lines like 'Corresp. mineralia: '
      substances = []
      filler = content.split(',')[-1].sub(/\.$/, '')
      filler_match = /^(?<name>[^,\d]+)\s*(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))))/.match(filler)
      # content.gsub(/(\d),(\d+)/, "\\1.\\2").split(/([^\(]+\([^)]+\)[^,]+|),/).each {
      content.gsub(/(\d),(\d+)/, "\\1.\\2").split(/,/).each {
        |component|
        next unless component.size > 0
        next if /^ratio:/i.match(component.strip)
        to_consider = component.strip.split(':')[-1].gsub(to_1, rep_1).gsub(to_2, rep_2).gsub(to_3, rep_3) # remove label
        # very ugly hack to ignore ,()
        ptrn1 = /^(?<name>.+)(\s+|$)(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))))/
        m =  /^(?<name>.+)(\s+|$)/.match(to_consider)
        m_with_dose = ptrn1.match(to_consider)
        m = m_with_dose if m_with_dose
        if m2 = /^(|[^:]+:\s)(E\s+\d+)$/.match(component.strip)
          to_add = ParseSubstance.new(m2[2], '', nil, nil, nil, nil, active_agents.index(m2[2].downcase) ? true : false)
          substances << to_add
        elsif m
          ptrn = /(?<name>.+)\s+(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))))(\s*(?:ut|corresp\.?)\s+(?<chemical>[^\d,]+)\s*(?<cdose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))(\s*[mv]\/[mv])?))?)/
          m_with_chemical = ptrn.match(to_consider)
          m = m_with_chemical if m_with_chemical
          name      = m[:name].strip.gsub(rep_3, to_3).gsub(rep_2, to_2).gsub(rep_1, to_1)
          chemical  = m_with_chemical ? m[:chemical] : nil
          cdose     = m_with_chemical ? m[:cdose] : nil
          dose      = m_with_dose     ? m[:dose].sub(/\.$/, '')  : nil
          if m_with_chemical and active_agents.index(m_with_chemical[:chemical].strip)
            is_active_agent = true
            name            = m[:chemical].strip.gsub(rep_3, to_3).gsub(rep_2, to_2).gsub(rep_1, to_1)
            dose            = m[:cdose]
            chemical        = m[:name].strip
            cdose           = m[:dose].sub(/\.$/, '')
          else
            if active_agent = active_agents.find{|x| name.index(x) } and name.index(' ex ')
              is_active_agent = true
              name = active_agent
              # binding.pry if /viscum/i.match(name)
            else
              is_active_agent =  active_agents.index(m[:name].strip) != nil
            end
          end
          unit = nil
          parts_in_parentesis = /([^()]+)\(([^()]+)\)/.match(component.strip)
          emulsion_pattern = /\s+pro($|\s+)|emulsion|solution/i
          next if parts_in_parentesis and emulsion_pattern.match(parts_in_parentesis[1])
          name = name.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
#          binding.pry if /toxoidum diphtheriae/i.match(line)
          # binding.pry if /globulina equina/i.match(name.to_s) or name.is_a?(MatchData)
          if not parts_in_parentesis
            name = name.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
          elsif parts_in_parentesis.size == 1
            name = parts_in_parentesis and parts_in_parentesis[1].to_s.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
          else
            if /\bex|\bet/.match(component.strip)
              name = name.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
            elsif /\(/.match(component.strip)
              puts "c #{component.strip} consider #{to_consider}"
              name = parts_in_parentesis[1].split(/\s/).collect{ |x| x.capitalize }.join(' ').strip + ' (' + parts_in_parentesis[2] +')'
            else
              name = name.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
            end
          end
          chemical = chemical.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip if chemical
          filler = nil if filler.downcase.index(name.downcase)
          qty,  unit  = ParseUtil.dose_to_qty_unit(dose, filler)
          cqty, cunit = ParseUtil.dose_to_qty_unit(cdose, filler)
          dose = "#{qty} #{unit}" if unit and unit.match(/\//)
          substances << ParseSubstance.new(name, qty, unit, chemical, cqty, cunit, is_active_agent, dose, cdose)
        end
      }
      comps << ParseComposition.new(line, label, label_description, substances) if substances.size > 0
    end
    comps
  end
end