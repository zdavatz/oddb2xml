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
  rule(:identifier) { (match['a-zA-Zéàèèçïöäüâ'] | digit >> str('-'))  >> match['0-9a-zA-Z\-éàèèçïöäüâ\'\/\.%'].repeat(0) }
  # handle stuff like acidum 9,11-linolicum specially. it must contain at least one a-z
  rule(:umlaut) { match(['éàèèçïöäüâ']) }
  rule(:identifier_with_comma) { match['0-9,\-'].repeat(0) >> (match['a-zA-Z']|umlaut)  >> (match(['_,\(']).maybe >> (match['0-9a-zA-Z\-\)'] | umlaut)).repeat(0) }
  rule(:one_word) { identifier_with_comma }
  rule(:in_parent) { lparen >> one_word.repeat(1) >> rparen }
  rule(:words_nested) { one_word.repeat(1) >> in_parent.maybe >> space? >> one_word.repeat(0) }
  rule(:name_with_parenthesis) {
    (match('[a-zA-Z]') >> ((match('[0-9]') >> space >> match('[a-zA-Z]')).maybe >>match('[a-zA-Z_\- \(\)]')).repeat) >> space?
  }
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
#                           str('U.I') |
                           str('U.') |
                           str('Mia. U.') |
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> str('-') >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { (qty_range | dose_qty) >> space? >> dose_unit }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { (qty_unit | dose_qty |dose_unit) >>
                          space?
#                          (space >> (str('ad pulverem') | str('pro charta') | str('pro dosi') )).repeat(0)
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
  rule(:farbstoff) { ((str('antiox.:') | str('color.:'))  >> space).maybe >>  (str('E').as(:farbstoff) >> space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) } # Match Wirkstoffe like E 270
  # rule(:name_simple_part) { ((identifier_with_comma) >> space?).repeat(1) }
  rule(:name_simple_part) { ((identifier_with_comma | identifier) >> space?).repeat(1) }
  rule(:substance_in_parenthesis) { (name_complex_part >>  space?).repeat(1) >> (comma >> (name_simple_part >> space?).repeat(0)).repeat(0) }
  rule(:name_complex_part) { identifier |
#                             str('>') |
                            # digit.repeat >> space >> dose_unit.absent? >> any.repeat | # match stuff like typus 1 inactivatum
                            space? >> lparen >> substance_in_parenthesis >> space? >> rparen >> digit.repeat(0,1) >> str('-like:').maybe      # Match name_with_parenthesis like  (D-Antigen)
                           }
  rule(:der) { (str('DER:')  >> space >> (digit >> match['\.-']).maybe >> digit >> str(':') >> digit).as(:der) } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1
  rule(:substance_name) { ( # first come the strings which may not be part of a substance name
                           (str('corresp.') |
#                            str('aqua ad iniectabilia q.s. ad solutionem pro')
                            str('et') |
                            str('ad') |
                            str('ut') |
                            str('ad pulverem') |
                            str('ad pulverem') |
                            str('ad suspensionem') |
                            str('ad solutionem pro') |
                            str('excipiens')
                           ).absent? >> one_word >> space?).repeat(1)
                        }
# excipiens ad solutionem pro 3 ml corresp. 50 µg
#                                  34
# aqua ad iniectabilia q.s. ad solutionem pro 5 ml
#                                                 49
# excipiens ad pulverem corresp. suspensio reconstituta
#                      22                              54
# ginseng extractum 40 mg corresp. ginsenosidea 1.6 mg
#                         25

#  rule(:simple_substance) { substance_name >> (space >> dose >> space?).as(:dose).maybe }
# calcium 10 mg
#            12
#  rule(:simple_substance) { (substance_name.as(:substance_name) >> (space >> dose).maybe).as(:substance)}
# excipiens ad solutionem pro 2 ml
#                         25
  rule(:simple_substance) { (substance_name.as(:substance_name) >> (space? >> dose.as(:dose)).maybe)}
  rule(:substance3) { identifier }
  rule(:ad_pulverem_pro) {
                     str('excipiens ad pulverem pro').as(:excipiens) >> space >> dose.as(:dose_pro).maybe
    }
  rule(:ad_pulverem) {
                     str('excipiens ad pulverem corresp. suspensio reconstituta') >> space? >> dose.as(:dose_pro) |
                     str('excipiens ad pulverem')
  }
# excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V
#                                  34
  rule(:ad_solutionem) {
                     str('excipiens ad solutionem pro') >> space >> dose.as(:ad_solutionem).maybe >>
                        (space? >> str('corresp.') >> space >> dose.as(:dose_corresp).maybe).maybe
    }
  rule(:substance_corresp) {
                    simple_substance >> space? >> str('corresp.') >> space >> simple_substance
    }
# aqua q.s. ad suspensionem
  rule(:aqua) { (str('aqua q.s. ad suspensionem pro') | str('aqua ad iniectabilia q.s. ad solutionem pro')).as(:substance_name) >>
                space?  >> dose.as(:dose).maybe
              }
  rule(:substance) {  aqua |
                      ad_solutionem.as(:excipiens) |
                      substance_corresp |
                      simple_substance  |
                      ad_pulverem_pro.as(:excipiens) |
                      ad_pulverem.as(:excipiens) |
# is okay                     str('excipiens ad pulverem pro 1000 mg')
                     str('excipiens pro compresso')
# excipiens ad solutionem pro 3 ml corresp. 50 µg

                   }
  rule(:substance3) { str('excipiens').as(:excipiens).maybe >> space? >>
                     str('ad pulverem').as(:ad_pulverem).maybe >> space? >>
                     str('ad solutionem pro 2 ml').maybe >>
                     str('ad solutionem').as(:ad_solutionem).maybe >> space? >>
#                     str('ad solutionem pro').as(:ad_solutionem) >> space? >> # >> dose.as(:ad_dose)).maybe >>
#                     str('ad suspensionem').as(:ad_suspensionem).maybe >> space? >>
#                        str('ad suspensionem').as(:ad_suspensionem).maybe >> space? >>
#                      (str('corresp.') >> space).maybe >> # simple_substance.as(:substance_corresp) ).maybe >>
#                      (str('corresp.') >> space >> dose.maybe >> space?).maybe >> # simple_substance.as(:substance_corresp) ).maybe >>
#                      (str('corresp.') >> space >> dose.maybe).maybe >> # simple_substance.as(:substance_corresp) ).maybe >>
#                      str('corresp. 50 µg') >>
                    space?
#                      simple_substance.maybe
#  >> (space? >> str('corresp.')>> space? >> simple_substance.as(:substance_corresp)).maybe >>
#                      substance_name >> space? >>
#      (str('ad solutionem pro').as(:ad_solutionem) >> space >> str('1 ml')).maybe >>
#      space >> dose.maybe.as(:dose)
  }
  rule(:substanceSome) { simple_substance }
  rule(:substanceALT) {  aqua |
                      farbstoff |
                      ((str('ut').as(:ut) >> space).maybe >>
#                       (str('ad solutionem pro').as(:ad_solutionem) >> space).maybe >>
                       handle_excipiens.maybe >>
                       (
                        radio_isotop |
                        substance_name
                       ).as(:substance_name) >>
                      (space? >> dose.maybe.as(:dose))) >>
                      (space >> (str('ad solutionem pro') ).maybe >> space? >> dose.as(:ad_solutionem).maybe).maybe >>
                   space?
                     }

  rule(:handle_excipiens) { (str('excipiens') |  str('excipiens ad solutionem pro'))>>  space }

  rule(:excipiens) { (str('excipiens') >> space >>
                      (str('pro compresso').as(:pro_compresso)).maybe |
                      (str('ad pulverem').as(:ad_pulverem) >>
                          (space >> str('corresp. suspensio reconstituta').as(:name_corresp)  >> space? >> dose.as(:dose_x1).maybe).maybe >>
                          (space >> str('pro charta').as(:pro_charta)).maybe >>
                          (space >> str('pro').as(:pro) >> space >> dose.as(:dose3)).maybe
                      ) |
                      ((
                        ((str('ad emulsionem').as(:ad_emulsionem) |
                          str('aqua q.s. ad suspensionem pro').as(:ad_suspensionem) |
                          str('ad solutionem pro').as(:ad_solutionem_pro) |
                          str('pro dosi') |
                          str('corresp.') # | (space >> name_simple_part)
                         ) >>
                          (space >> dose.as(:dose4).maybe  ).maybe >>
                        space?
                        )
                       ) >> ( space? >> str('corresp.') >>
                             (space  >> dose.as(:dose_corresp)).maybe >>
                             (space >> str('pro dosi')).maybe).maybe
                      ) #|
#                          space? >> (substance_name >> space >> dose)
#                          space? >> (match(['a-zA-Z']).repeat(1)).as(:substance_name) >>  (space >> dose.as(:dose) ) >> str('impossible')
                     ).as(:excipiens)
                     }
  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:named_substance) { (identifier >> space?).repeat(1).as(:substance_name) >> dose.as(:dose).maybe >> str(':') >>
                           (space >> (identifier >> space? >> dose.as(:dose).maybe >> (space? >> str('et') >> space?).maybe).repeat(1)).maybe}
#  rule(:substance_residui) { str('residui:')    >> space >> simple_substance.as(:residui) }
#  rule(:substance_conserv) { str('conserv.:')   >> space >> simple_substance.as(:conserv) }
#  rule(:substance_corresp) { substance >>str('corresp.') >> space >>  (str('suspensio reconstituta') >> space).maybe >>
#                             (simple_substance).as(:substance_corresp)  }
#  rule(:substance_ut) { substance.as(:substance_before_ut) >> space >> str('ut') >> space >> simple_substance.as(:substance_ut) }
# acari allergeni extractum 50'000 U.:
#                                     37
  rule(:praeparatio) { ((identifier >> space?).repeat(1).as(:description) >> str(':') >> space).maybe>>
                       (identifier >> space?).repeat(1).as(:substance_name) >>
                        number.as(:qty) >> space >> str('U.:') >> space? >>
                        (identifier.as(:more_info) >> space?).maybe
                       }

  rule(:substance_separator) { (comma | str('et')) >> space? }
# rule(:one_substance) { (der | excipiens | praeparatio | histamin | named_substance | substance_residui | substance_conserv | substance_ut | substance_corresp | substance ) >> substance_separator }
# rule(:one_substance) { excipiens >> substance_separator.maybe} # Sometimes it is handy for debugging to be able to debug just one the different variants
#  rule(:one_substance) { praeparatio | substance_corresp | substance | excipiens}
  rule(:one_substance) { (praeparatio | substance).as(:substance) }
#  rule(:all_substances) { (one_substance >> substance_separator.maybe).repeat(1) }
  rule(:all_substances) { (one_substance >> substance_separator.maybe).repeat(1) }
 # rule(:all_substances) { substance.as(:substance) }
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
       :qty => simple(:qty),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s.strip, ParseDose.new(dictionary[:qty].to_s))
  }
  rule(:substance_name => simple(:substance_name),
       :ut => simple(:ut),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
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
end

class CompositionParser < SubstanceParser

  rule(:composition) { (all_substances.as(:all_substances) ) }
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
  rule(:expression_comp) { label.maybe >> composition.as(:composition) }
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
    @name.sub!(/\bq.s.\b/i, 'q.s.')
    @name.sub!(/\bpro\b/i, 'pro')
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
    # binding.pry
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
          substance = ParseSubstance.new(string)
          substance.is_excipiens = true
          substance.dose  = result.first[:excipiens][:dose]         if result.first[:excipiens][:dose]
          substance.cdose = result.first[:excipiens][:dose_corresp] if result.first[:excipiens][:dose_corresp]
          if result.first[:excipiens][:substance_corresp]
            chemical_name = result.first[:excipiens][:substance_corresp][:substance_name].to_s
        binding.pry
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
          name = val[:pro] ? val[:pro].to_s + ' ' : ''
          name += val[:dose_corresp].to_s  + ' ' if val[:dose_corresp]
          name += val[:ad_pulverem].to_s   + ' ' if val[:ad_pulverem]
          name  = name.sub(/^excipiens /i, '')
          substance = ParseSubstance.new(name, ParseDose.new(val[:qty].to_s, val[:unit].to_s))
          substance.is_excipiens = true
        end unless substance.is_a?(ParseSubstance)
        return substance
      end
      substance = result.first[:substance] if result.first[:substance]
      substance = substance[:substance] if substance.is_a?(Hash) and substance[:substance]
      substance = substance.first if substance.is_a?(Array)
      substance ||= result.first[:substance_et] if result.first[:substance_et]
      substance ||= result.first[:substance_corresp] if result.first[:substance_corresp]
      if result.first[:substance].is_a?(Hash) and result.first[:substance][:excipiens].is_a?(Parslet::Slice)
        name =  result.first[:substance][:excipiens].to_s
        substance = ParseSubstance.new(name, nil)
        substance.is_excipiens = true
      elsif result.first[:substance].is_a?(Hash) and result.first[:substance][:excipiens].is_a?(Hash)
        name = 'excipiens'
        substance = ParseSubstance.new(name, result.first[:substance][:excipiens][:ad_solutionem])
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
        binding.pry
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

  ErrorsToFix = { /(sulfuris D6\s[^\s]+\smg)\s([^,]+)/ => '\1, \2' }
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
    return nil if string.eql?('.') or string.eql?('')
    cleaned = string.gsub(/^"|["\n\.]+$/, '')
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

