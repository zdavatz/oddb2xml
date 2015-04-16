# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
require 'parslet/convenience'
include Parslet
VERBOSE_MESSAGES = true

class DoseParser < Parslet::Parser

  # Single character rules
  rule(:lparen)     { str('(') }
  rule(:rparen)     { str(')') }
  rule(:comma)      { str(',') }

  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }

  # Things
  rule(:digit) { match('[0-9]') }
  rule(:digits) { digit.repeat(1) }
  rule(:number) {
    (
      str('-').maybe >> (
        str('0') | (match('[1-9]') >> match('[0-9\']').repeat)
      ) >> (
            match(['.,']) >> digit.repeat(1)
      ).maybe >> (
        match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
      ).maybe
    )
  }
  rule(:radio_isotop) { match['a-zA-Z'].repeat(1) >> lparen >> digits >> str('-') >> match['a-zA-Z'].repeat(1-3) >> rparen >>
                        ((space? >> match['a-zA-Z']).repeat(1)).repeat(0)
                        } # e.g. Xenonum (133-Xe) or yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt
  rule(:identifier) { (match['a-zA-Zéàèèçïöäüâ'] | digit >> str('-'))  >> match['0-9a-zA-Z\-éàèèçïöäüâ\'\/\.'].repeat(0) }
  # handle stuff like acidum 9,11-linolicum specially. it must contain at least one a-z
  rule(:umlaut) { match(['éàèèçïöäüâ']) }
  rule(:identifier_with_comma) { match['0-9,\-'].repeat(0) >> (match['a-zA-Z']|umlaut)  >> (match(['_,']).maybe >> (match['0-9a-zA-Z\-\'\/'] | umlaut)).repeat(0) }
  rule(:one_word) { identifier_with_comma }
  rule(:in_parent) { lparen >> one_word.repeat(1) >> rparen }
  rule(:words_nested) { one_word.repeat(1) >> in_parent.maybe >> space? >> one_word.repeat(0) }
  # dose
  rule(:dose_unit)      { (
                           str('% V/V') |
                           str('µg') |
                           str('guttae') |
                           str('mg/ml') |
                           str('MBq') |
                           str('mg') |
                           str('Mg') |
                           str('kJ') |
                           str('g') |
                           str('l') |
                           str('µl') |
                           str('ml') |
                           str('mmol') |
                           str('U.I.') |
                           str('U.') |
                           str('Mia. U.') |
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> str('-') >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { (qty_range | dose_qty) >> space? >> dose_unit }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { (qty_unit | dose_qty |dose_unit) >> space?
                        }
  root :dose

end

class IntLit   < Struct.new(:int)
  def eval; int.to_i; end
end
class QtyLit   < Struct.new(:qty)
  def eval; qty.to_i; end
end

class DoseTransformer < Parslet::Transform
  rule(:int => simple(:int))        { IntLit.new(int) }
  rule(:number => simple(:nb)) {
    nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
  }
  rule(
    :qty_range    => simple(:qty_range),
    :unit   => simple(:unit))  {
      ParseDose.new(qty_range, unit)
    }
  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
      ParseDose.new(qty, unit)
    }
  rule(
    :unit    => simple(:unit))  { ParseDose.new(nil, unit) }
  rule(
    :qty    => simple(:qty))  { ParseDose.new(qty, nil) }
end


class SubstanceParser < DoseParser

  rule(:operator)   { match('[+]') >> space? }

  # Grammar parts
  rule(:farbstoff) { ((str('antiox.:') | str('color.:') | str('conserv.:'))  >> space).maybe >>
                     (str('E').as(:farbstoff) >>
                      space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) >>
                      space? >> dose.maybe >> space?

                   } # Match Wirkstoffe like E 270
  # rule(:name_simple_part) { ((identifier_with_comma) >> space?).repeat(1) }
  rule(:name_simple_part) { ((identifier_with_comma | identifier) >> space?).repeat(1) }
  rule(:substance_in_parenthesis) { (name_complex_part >>  space?).repeat(1) >> (comma >> (name_simple_part >> space?).repeat(0)).repeat(0) }
  rule(:name_complex_part) { identifier |
                            space? >> lparen >> substance_in_parenthesis >> space? >> rparen >> digit.repeat(0,1) >> str('-like:').maybe      # Match name_with_parenthesis like  (D-Antigen)
                           }
  rule(:der) { (str('DER:')  >> space >> (digit >> match['\.-']).maybe >> digit >> str(':') >> digit).as(:der) } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1
  rule(:forbidden_in_substance_name) {
                           str(', corresp.') |
                           str('corresp.') |
                            str('et ') |
                            str('ut ') |
                            str('aqua q.s. ad') |
                            (digits.repeat(1) >> space >> str(':')) | # match 50 %
                            str('ad globulos') |
#                            str('ana') |
#                            str('partes') |
                            str('ad pulverem') |
                            str('ad suspensionem') |
                            str('q.s. ad solutionem') |
                            str('ad solutionem') |
                            str('ad emulsionem') |
                            str('excipiens')
    }
  rule(:name_without_parenthesis) { ((str('(') | forbidden_in_substance_name).absent? >> (str('> 1000') | str('> 500') | one_word) >> space?).repeat(1) }

  rule(:name_with_parenthesis) {
    ((str('(') | forbidden_in_substance_name).absent? >> (one_word|digit) >> space?).repeat(1) >> # match typus 1 s, too
    str('(') >> one_word >> str(')') >> space?
  }
  rule(:name_with_parenthesis_neu) {
    (str('(').absent? >> any).repeat(1) >> str('(') >>
    (str(')').absent? >> any).repeat(1) >>
     str(')')
  }
  rule(:substance_name) { der | name_with_parenthesis | name_without_parenthesis }
  rule(:substance_name) { name_with_parenthesis | name_without_parenthesis }
  rule(:simple_substance) { (substance_name.as(:substance_name) >> (space? >> dose.as(:dose)).maybe)}

  rule(:ad_pulverem_pro) {
                     str('excipiens ad pulverem pro').as(:excipiens) >> space >> dose.as(:dose_pro).maybe
    }
  rule(:ad_pulverem) {
                     str('excipiens ad pulverem corresp. suspensio reconstituta') >> space? >> dose.as(:dose_pro) |
                     str('excipiens ad pulverem') |
                     str('ad pulverem') |
                     str('excipiens ad globulos')
  }
# excipiens ad emulsionem pro 1 g
  rule(:ad_solutionem) {
#                        str('ana partes') >> space >> dose.as(:dose_corresp) >> space? |
                        str('q.s. ad solutionem') |
#                        ((str('ad solutionem') | str('ana partes ad') | str('aqua q.s. ad') | str('excipiens ad')) >>
                        ((str('ad solutionem') | str('aqua q.s. ad') | str('excipiens ad')) >>
                         space  >> match(['a-z']).repeat(1) >> space >>
                          (str('pro') >>  space >> dose.as(:dose_corresp)).maybe >>
                          ( (str(', corresp.') | str('corresp.')) >> space >>
                            (
                             dose.as(:dose_corresp) |
                             simple_substance.as(:substance_corresp)
                            )
                          ).maybe >>
                        space?
                        )
    }
  rule(:substance_corresp) {
                    simple_substance >> space? >> ( str('corresp.') | str(', corresp.')) >> space >> simple_substance.as(:substance_corresp)
    }

  rule(:aqua) { (str('aqua q.s. ad suspensionem pro') | str('aqua ad iniectabilia q.s. ad solutionem pro')).as(:substance_name) >>
                space?  >> dose.as(:dose).maybe
              }
  rule(:substance_ut) {
                    simple_substance.as(:substance_ut) >> space? >> str('ut ') >> space? >> simple_substance >> space?
    }

  rule(:substance) {  ((one_word >> space?).repeat(1).as(:description) >> str(':') >> space).maybe >>
                      simple_substance
                   }
  rule(:substance_more_info) { # e.g. "acari allergeni extractum 5000 U.:
      ((identifier|digits) >> space?).repeat(1).as(:more_info) >> space? >> (str('U.:') | str(':')) >> space?
    }
  rule(:substance_more_info) { str('substance_more_info deactivated') }

  rule(:substance_lead) {
                      str('conserv.:').as(:conserv) >> space? |
                      str('color.:').as(:color) >> space? |
                      str('arom.:').as(:arom) >> space? |
                      str('residui:').as(:residui) >> space? |
                      substance_more_info
    }
  rule(:substance) { farbstoff |
                     ((der.absent? >> substance_lead).maybe  >> space? >>
                    ( aqua |
                      substance_ut |
                      substance_name >> space >> ad_solutionem |
                      ad_solutionem.as(:excipiens) |
                      substance_corresp |
                      str('conserv.:').as(:conserv).maybe >> space? >>
                      str('residui:').as(:residui).maybe >> space? >>
                      simple_substance  |
                      ad_pulverem_pro.as(:excipiens) |
                      ad_pulverem.as(:excipiens) |
                      str('excipiens pro compresso')
                    ) )
                   }
  # rule(:substance) { substance_name >> space? >> ad_solutionem }
  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:praeparatio){ ((one_word >> space?).repeat(1).as(:description) >> str(':') >> space).maybe >>
# rule(:praeparatio){ substance_more_info.maybe >>
                      (identifier >> space?).repeat(1).as(:substance_name) >>
                      number.as(:qty) >> space >> str('U.:') >> space? >>
                      ((identifier >> space?).repeat(1).as(:more_info) >> space?).maybe
                    }

  rule(:substance_separator) { (comma | str('et ')) >> space? }
  rule(:one_substance)       { (praeparatio | histamin | substance) }
  rule(:one_substance)       { (substance) }
  rule(:one_substance)       { (histamin | substance | praeparatio).as(:substance) }
  rule(:all_substances)      { (one_substance >> substance_separator.maybe).repeat(1) }
  root :all_substances
end

class SubstanceTransformer < DoseTransformer
  @@substances ||= []
  def SubstanceTransformer.clear_substances
    @@substances = []
  end
  def SubstanceTransformer.substances
    @@substances.clone
  end

  rule(:farbstoff => simple(:farbstoff),
       :digits => simple(:digits)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new("#{dictionary[:farbstoff]} #{dictionary[:digits]}")
  }
  rule(:substance => simple(:substance)) {
    |dictionary|
    puts "#{__LINE__}: dictionary #{dictionary}"
    dictionary[:substance]
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
  }
  rule(:substance_name => simple(:substance_name),
       :conserv => simple(:conserv),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:dose].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:conserv].to_s.sub(/:$/, '')
  }
  rule(:substance_name => simple(:substance_name),
       :residui => simple(:residui),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name])
      @@substances <<  substance
      substance.more_info =  dictionary[:residui].to_s.sub(/:$/, '')
  }
  rule(:substance_name => simple(:substance_name),
       :qty => simple(:qty),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s.strip, ParseDose.new(dictionary[:qty].to_s))
  }

  rule(:substance_name => simple(:substance_name),
       :dose_corresp => simple(:dose_corresp),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose_corresp])
  }
  rule(:description => simple(:description),
       :substance_name => simple(:substance_name),
       :qty => simple(:qty),
       :more_info => simple(:more_info),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:qty].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:more_info].to_s
      substance.description =  dictionary[:description].to_s
      substance
  }
  rule(:der => simple(:der),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:der].to_s)
  }
  rule(:histamin => simple(:histamin),
       ) {
    |dictionary|
      puts "#{__LINE__}: histamin dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:histamin].to_s)
  }
  rule(:substance_name => simple(:substance_name),
       ) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:substance => simple(:substance),
       :excipiens => sequence(:excipiens)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
       binding.pry
    @@substances << ParseSubstance.new(dictionary[:substance_name])
  }

  rule(:substance_name => simple(:substance_name),
       :substance_ut => sequence(:substance_ut),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
 #      binding.pry
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
  }

  rule(:substance_name => simple(:substance_name),
       :substance_ut => sequence(:substance_ut),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
#         binding.pry
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, nil)
      nil
  }

  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       :more_info => simple(:more_info)) {
    |dictionary|
        puts "#{__LINE__}: dictionary #{dictionary}"
        substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:dose].to_s))
        substance.more_info = dictionary[:more_info].to_s
        @@substances <<  substance
  }
end

class CompositionParser < SubstanceParser

  rule(:composition) { all_substances }
  rule(:label) {
     (
                           str('V') |
                           str('IV') |
                           str('III') |
                           str('II') |
                           str('I') |
                           str('A') |
                           str('B') |
                           str('C') |
                           str('D') |
                           str('E')
                          ).as(:label) >>
    (  (str('):')  | str(')')) >> (space? >> (match(/[^:]/).repeat(1)).as(:label_description)  >> str(':')).maybe
      ) >> space
  }
  rule(:expression_comp) { label.maybe >>  composition.as(:composition) }
  root :expression_comp
end

class CompositionTransformer < SubstanceTransformer
  rule(:substance => simple(:substance)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
       binding.pry
  }
end

class ParseDose
  attr_reader :qty, :unit
  def initialize(qty=nil, unit=nil)
    puts "ParseDose.new from #{qty.inspect} #{unit.inspect} #{unit.inspect}" if VERBOSE_MESSAGES
    if qty and (qty.is_a?(String) || qty.is_a?(Parslet::Slice))
      string = qty.to_s.gsub("'", '')
      @qty  = string.index('.') ? string.to_f : string.to_i
    elsif qty
      @qty  = qty.eval
    else
      @qty = 1
    end
    @unit = unit ? unit.to_s : nil
  end
  def eval
    self
  end
  def to_s
    return @unit unless qty
    "#{@qty} #{@unit}"
  end
  def ParseDose.from_string(string)
    cleaned = string.sub(',', '.')
    puts "ParseDose.from_string #{string} -> cleaned #{cleaned}" if VERBOSE_MESSAGES
    value = nil
    parser = DoseParser.new
    transf = DoseTransformer.new
    puts "#{__LINE__}: ==>  #{parser.parse_with_debug(cleaned)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(cleaned))
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose, :is_excipiens
  attr_accessor  :description, :more_info, :salts
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    @name = name.to_s.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
    @name.sub!(/\baqua\b/i, 'aqua')
    @name.sub!(/\bad pulverem\b/i, 'ad pulverem')
    @name.sub!(/\bad iniectabilia\b/i, 'ad iniectabilia')
    @name.sub!(/\bad suspensionem\b/i, 'ad suspensionem')
    @name.sub!(/\bad solutionem\b/i, 'ad solutionem')
    @name.sub!(/\bpro compresso\b/i, 'pro compresso')
    @name.sub!(/\bpro\b/i, 'pro')
    @name.sub!(/ Q\.S\. /i, ' q.s. ')
    @name.sub!(/\s+\bpro$/i, '')
    if dose
      @qty = dose.qty
      @unit = dose.unit
    end
    @salts = []
  end
  def qty
    @dose ? @dose.qty : @qty
  end
  def unit
    @dose ? @dose.unit : @unit
  end
  def to_string
    s = "#{@name}:"
    s = " #{@qty}" if @qty
    s = " #{@unit}" if @unit
    s += @chemical_substance.to_s if chemical_substance
    s
  end
  def eval
    puts "ParseSubstance.eval" if VERBOSE_MESSAGES
    self
  end
  def ParseSubstance.from_string(string)
    value = nil
    puts "ParseSubstance for string #{string}" if VERBOSE_MESSAGES
    SubstanceTransformer.clear_substances if defined?(RSpec) # TODO: Ugly. Why do I need it here???

    parser = SubstanceParser.new
    transf = SubstanceTransformer.new
    puts "#{__LINE__}: ==>  #{parser.parse_with_debug(string)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(string))
    return ParseSubstance.new(string) if /^E/.match(string) # Handle Farbstoffe
    name = nil
    name = result.to_s if result.is_a?(Parslet::Slice)
    name = result.first.to_s if result.is_a?(Array) and result.first.is_a?(Parslet::Slice)
    return ParseSubstance.new(name) if name
    # result = result.first if result.is_a?(Array) and result.first.is_a?(Array)
    if result.is_a?(Array)
      if result.first.is_a?(ParseSubstance)
        substance = result.first
        substance_et = result.collect{ |x| x[:substance_et] if x.is_a?(Hash) and x[:substance_et]  }.compact.first
        substance_et = substance_et[:substance_corresp] if substance_et.is_a?(Hash) and substance_et[:substance_corresp]
        substance.chemical_substance = substance_et
        substance.dose = ParseDose.new(substance.qty.to_s, substance.unit.to_s) if substance.qty or substance.unit
        if substance_et
          substance.cdose = ParseDose.new(substance_et.qty.to_s, substance_et.unit) if substance_et.qty or substance_et.unit
          substance.chemical_qty =  substance_et.qty.to_s
          substance.chemical_unit = substance_et.unit
        end
        return substance
      end
      if result.first.is_a?(Hash) and result.first[:excipiens]
        if result.first[:excipiens].is_a?(Hash) and result.first[:excipiens]
          # substance = ParseSubstance.new(string) TODO: should we use a long name for excipiens?
          substance = ParseSubstance.new('Excipiens')
          substance.is_excipiens = true
          substance.dose  = result.first[:excipiens][:dose]         if result.first[:excipiens][:dose]
          substance.dose  = result.first[:excipiens][:dose_pro]     if substance.dose == nil and result.first[:excipiens][:dose_pro]
          substance.cdose = result.first[:excipiens][:dose_corresp] if result.first[:excipiens][:dose_corresp]
          if result.first[:excipiens][:substance_corresp]
            chemical_name = result.first[:excipiens][:substance_corresp][:substance_name].to_s
            substance.chemical_substance = ParseSubstance.new(chemical_name)
          end
          return substance
        end
        return ParseSubstance.new(result.first[:excipiens].to_s) if result.first[:excipiens].is_a?(Parslet::Slice)
        if result.first[:excipiens].is_a?(ParseSubstance)
          substance = result.first[:excipiens]
        elsif  result.first[:excipiens].is_a?(Hash) and result.first[:excipiens][:excipiens].is_a?(ParseSubstance)
          substance = result.first[:excipiens][:excipiens] if result.first[:excipiens][:excipiens].is_a?(ParseSubstance)
        end
        if val = result.first[:excipiens]
          binding.pry unless /excipiens/i.match(string)
          # TODO: Should we use long or short names for excipiens?
          # name = val[:dose_pro] ? val[:dose_pro].to_s + ' ' : ''
          # name += val[:dose_corresp].to_s  + ' ' if val[:dose_corresp]
          # name += val[:ad_pulverem].to_s   + ' ' if val[:ad_pulverem]
          name  = name.sub(/^excipiens /i, '')
          substance = ParseSubstance.new(name, ParseDose.new(val[:qty].to_s, val[:unit].to_s))
          binding.pry
          substance.is_excipiens = true
        end unless substance.is_a?(ParseSubstance)
        return substance
      end
#      binding.pry
      result = result.first if result.is_a?(Array) and result.size == 1
      substance = nil
      substance ||= result.first if result.is_a?(Array) and result.first.is_a?(ParseSubstance)
      substance ||= result.first[:substance] if result.first.is_a?(Hash) and result.first[:substance]
      substance ||= result.first.first if result.first.is_a?(Array) and result.first.first.is_a?(ParseSubstance)
      substance ||= substance[:substance] if substance.is_a?(Hash) and substance[:substance]
      return substance
      substance ||= substance.first if substance.is_a?(Array)
      substance ||= result.first[:substance_et] if result.first.is_a?(Hash) and result.first[:substance_et]
      substance ||= result.first[:substance_corresp] if result.first.is_a?(Hash) and result.first[:substance_corresp]
      if result.first[:substance].is_a?(Hash) and result.first[:substance][:excipiens].is_a?(Parslet::Slice)
        name =  result.first[:substance][:excipiens].to_s
        substance = ParseSubstance.new(name, nil)
          binding.pry
        substance.is_excipiens = true
      elsif result.first[:substance].is_a?(Hash) and result.first[:substance][:excipiens].is_a?(Hash)
        name = 'excipiens'
        substance = ParseSubstance.new(name, result.first[:substance][:excipiens][:ad_solutionem])
          binding.pry
        substance.is_excipiens = true
        return substance
      end
      if result.first[:substance].is_a?(Hash) and result.first[:substance][:dose].is_a?(ParseDose)
        substance.dose = result.first[:substance][:dose]
      elsif result.first[:substance].is_a?(ParseSubstance)
        substance.dose = ParseDose.new(result.first[:substance].qty.to_s, result.first[:substance].unit) if result.first[:substance]
      end
      if result.first[:ad_solutionem]
        old_unit = substance.unit
        new_unit = old_unit + '/' + result.first[:ad_solutionem].to_s
        new_dose = ParseDose.new(substance.qty.to_s, new_unit)
        substance.unit = new_unit
        substance.dose = new_dose
      end
      if result.first[:substance_corresp]
        if result.first[:substance_corresp].is_a?(Array)
          substance.chemical_substance = result.first[:substance_corresp].find{ |x| x.is_a?(Hash) and x[:substance_et] }[:substance_et]
          # substance.chemical_substance = result.first[:substance_corresp].first[:substance_et]
        elsif  result.first[:substance_corresp][:substance] and  result.first[:substance_corresp][:substance].is_a?(Array)
          substance.chemical_substance = result.first[:substance_corresp][:substance].first
        else
          binding.pry if defined?(RSpec)
        end
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_et]
        binding.pry
        substance.chemical_substance = result.first[:substance_et]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_ut]
        binding.pry
        substance.chemical_substance = result.first[:substance_ut]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      end
      puts "ParseSubstance #{string} returning substance #{substance}" if VERBOSE_MESSAGES
      return substance
    end
    nil
  end
end

# this class is responsible to patch errors in swissmedic entries after
# oddb.org detected them, as it takes sometimes a few days (or more) till they get corrected
# Reports the number of occurrences of each entry
class HandleSwissmedicErrors

  class ErrorEntry   < Struct.new('ErrorEntry', :pattern, :replacement, :nr_occurrences)
  end

  def reset_errors
    @errors = []
  end

  # error_entries should be a hash of  pattern, replacement
  def initialize(error_entries)
    reset_errors
    error_entries.each{ |pattern, replacement| @errors << ErrorEntry.new(pattern, replacement, 0) }
  end

  def report
    s = ["Report of changed compositions" ]
    @errors.each {
      |entry|
    s << "  replaced #{entry.nr_occurrences} times '#{entry.pattern}'  by '#{entry.replacement}'"
    }
    s
  end

  def apply_fixes(string)
    result = string.clone
    @errors.each{
      |entry|
      intermediate = result.clone
      result = result.gsub(entry.pattern,  entry.replacement)
      entry.nr_occurrences += 1 unless intermediate.eql?(intermediate)
    }
    result
  end
  #  hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg where itlacks a comma and should be hepar sulfuris D6 2,2 mg, hypericum perforatum D2 0,66 mg
end

class ParseComposition
  attr_accessor   :source, :label, :label_description, :substances, :galenic_form, :route_of_administration

  ErrorsToFix = { /(sulfuris D6\s[^\s]+\smg)\s([^,]+)/ => '\1, \2',
                  /(excipiens ad solutionem pro \d+ ml), corresp\./ => '\1 corresp.',
                  # excipiens ad solutionem pro 1 ml
                  "F(ab')2" => "F_ab_2",
                }
  @@errorHandler = HandleSwissmedicErrors.new( ErrorsToFix )

  def initialize(source)
    @substances ||= []
    puts "ParseComposition.new from #{source.inspect} @substances #{@substances.inspect}" if VERBOSE_MESSAGES
    @source = source.to_s
  end
  def ParseComposition.reset
    @@errorHandler = HandleSwissmedicErrors.new( ErrorsToFix )
  end
  def ParseComposition.report
    @@errorHandler.report
  end
  def eval
    self
  end
  def ParseComposition.from_string(string)
    return nil if string == nil or  string.eql?('.') or string.eql?('')
    # cleaned = string.gsub(/^"|[^IU]["\n\.]+$/, '')
    cleaned = string.gsub(/^"|["\n]+$/, '')
    return nil unless cleaned
    cleaned = cleaned.sub(/[\.]+$/, '') unless /(U\.I\.|U\.)$/.match(cleaned)
    value = nil
    puts "ParseComposition.from_string #{string}" if VERBOSE_MESSAGES
    cleaned = @@errorHandler.apply_fixes(cleaned)
    puts "ParseComposition.new cleaned #{cleaned}" if VERBOSE_MESSAGES and not cleaned.eql?(string)

    SubstanceTransformer.clear_substances
    result = ParseComposition.new(cleaned)
    parser3 = CompositionParser.new
    transf3 = SubstanceTransformer.new
    puts "#{__LINE__}: ==>  #{parser3.parse_with_debug(cleaned)}" if VERBOSE_MESSAGES
    ast = transf3.apply(parser3.parse(cleaned))
    # pp ast; binding.pry
    result.source = string
    result.label              = ast[:label].to_s             if ast[:label]
    result.label_description  = ast[:label_description].to_s if ast[:label_description]

    if ast.is_a?(Parslet::Slice)
    else
      ast.find_all{|x| x.is_a?(ParseSubstance)}.each{ |x| result.substances << x }
      result.substances = SubstanceTransformer.substances
      if ast.is_a?(Array) and  ast.first.is_a?(Hash)
        result.label              = ast.first[:label].to_s
        result.label_description  = ast.first[:label_description].to_s
      end
    end
    return result
  end
end

