# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
require 'parslet/convenience'
include Parslet
VERBOSE_MESSAGES = false

module ParseUtil
  def ParseUtil.capitalize(string)
    string.split(/\s+/u).collect { |word| word.capitalize }.join(' ').strip
  end

  def ParseUtil.parse_compositions(composition_text, active_agents_string = '')
    active_agents = active_agents_string ? active_agents_string.downcase.split(/,\s+/) : []
    comps = []
    lines = composition_text.gsub(/\r\n?/u, "\n").split(/\n/u)
    lines.select {
      |line|
      composition =  ParseComposition.from_string(line)
      if composition and composition.substances.size > 0
        composition.substances.
    each {
          |substance_item|
          substance_item.is_active_agent = (active_agents.find {|x| x.downcase.eql?(substance_item.name.downcase) } != nil)
          substance_item.is_active_agent = true if substance_item.chemical_substance and active_agents.find {|x| x.downcase.eql?(substance_item.chemical_substance.name.downcase) }
         }
        comps << composition
      end
    }
    comps << ParseComposition.new(composition_text.split(/,|:|\(/)[0]) if comps.size == 0
    comps
  end
end

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
  rule(:identifier_D12) { match['a-zA-Z'] >> digit.repeat(1) }
  rule(:identifier_with_comma) {
    match['0-9,\-'].repeat(0) >> (match['a-zA-Z']|umlaut)  >> (match(['_,']).maybe >> (match['0-9a-zA-Z\-\'\/'] | umlaut)).repeat(0)
  }
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
                           str('G') |
                           str('g') |
                           str('l') |
                           str('µl') |
                           str('ml') |
                           str('µmol') |
                           str('mmol') |
                           str('U.I.') |
                           str('U.') |
                           str('Mia. U.') |
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> str('-') >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { dose_qty >> space? >> dose_unit.maybe }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { ( (qty_range >> space? >> dose_unit.maybe) | (qty_unit | dose_qty |dose_unit)) >> space?
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
    :qty_range    => simple(:qty_range)) {
      ParseDose.new(qty_range)
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
  rule(:farbstoff) { (( str('antiox.:').as(:more_info) |
                        str('arom.:').as(:more_info) |
                        str('color.:').as(:more_info) |
                        str('conserv.:').as(:more_info)
                      ).  >> space).maybe >>
                     (str('E').as(:farbstoff) >>
                      space >> (digits >> match['(a-z)'].repeat(0,3)).as(:digits)
                     ) >>
                      space? >> dose.maybe >> space?

                   } # Match Wirkstoffe like E 270
  rule(:der) { (str('DER:')  >> space >> digit >> match['0-9\.\-:'].repeat).as(:der)
             } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1 or DER: 4.0-9.0:1'
  rule(:forbidden_in_substance_name) {
                           str(', corresp.') |
                           str('corresp.') |
                            str('et ') |
                            str('ut ') |
                            str('ut alia: ') |
                            str('ut alia: ') |
                            str('pro capsula') |
                            (digits.repeat(1) >> space >> str(':')) | # match 50 %
                            str('ad globulos') |
                            str('ana ') |
                            str('ana partes') |
                            str('partes') |
                            str('ad pulverem') |
                            str('ad suspensionem') |
                            str('q.s. ad solutionem') |
                            str('ad solutionem') |
                            str('ad emulsionem') |
                            str('excipiens')
    }
  rule(:name_without_parenthesis) {
    (
     (str('(') |
      forbidden_in_substance_name).absent? >> (radio_isotop |
                                               str('> 1000') |
                                               str('> 500') |

                                              one_word) >> space?).repeat(1)
  }

  rule(:name_with_parenthesis) {
    (str('(').absent? >> any).repeat(1) >> str('(') >>
    (str(')').absent? >> any).repeat(1) >>
     str(')')
  }
  rule(:substance_name) { der | farbstoff | name_with_parenthesis | name_without_parenthesis >> str('.').maybe }
  rule(:simple_substance) { (substance_name.as(:substance_name) >> (space? >> dose.as(:dose)).maybe)}

  rule(:pro_dose) { str('pro') >>  space >> dose.as(:dose_corresp) }

  rule(:substance_corresp) {
                    simple_substance >> space? >> ( str('corresp.') | str(', corresp.')) >> space >> simple_substance.as(:substance_corresp)
    }

    # TODO: what does ut alia: impl?
  rule(:substance_ut) {
    simple_substance.as(:substance_ut) >>
  (space? >> str('ut ')  >>
   space? >> str('alia:').absent? >>simple_substance.as(:for_ut)
  ).repeat(1) >>
    space? # >> str('alia:').maybe >> space?
  }

  rule(:substance_more_info) { # e.g. "acari allergeni extractum 5000 U.:
      ((identifier|digits) >> space?).repeat(1).as(:more_info) >> space? >> (str('U.:') | str(':')) >> space?
    }

  rule(:dose_pro) { (
                       str('excipiens ad solutionem pro ') |
                       str('aqua q.s. ad suspensionem pro ') |
                       str('excipiens ad emulsionem pro ') |
                       str('excipiens ad pulverem pro ') |
                       str('aqua ad iniectabilia q.s. ad solutionem pro ')
                    )  >> dose
  }
# aqua ad iniectabilia q.s. ad solutionem pro 0.5 ml.
  rule(:excipiens)  { (dose_pro.as(:dose_pro) |
                       str('excipiens') |
                       str('ad pulverem') |
                       str('pro charta') |
                       str('aqua ad iniectabilia q.s. ad solutionem') |
                       str('ad solutionem') |
                       str('q.s. ad') |
                       str('aqua q.s. ad') |
                       str('saccharum ad') |
                       str('aether q.s.') |
                       str('aqua ad iniectabilia') |
                       str('ana partes')
                      ) >> space? >>
                      ( any.repeat(0) )
                      }

  rule(:substance_lead) {
                      str('residui:').as(:residui) >> space? |
                      str('mineralia:').as(:mineralia) >> space? |
                      str('Solvens:').as(:solvens) >> space? |
                      substance_more_info
    }
  rule(:corresp_substance) {
                            (str(', corresp.') | str('corresp.')) >> space? >>
                            (
                             simple_substance.as(:substance_corresp) |
                             dose.as(:dose_corresp_2)
                            )
  }

  rule(:solvens) { str('Solvens:') >> space >> (any.repeat).as(:solvens) >> space? >>
                   (substance.as(:substance) >> str('/L').maybe).maybe  >>
                    any.maybe
                }
  rule(:substance) {
    solvens |
    der |
    substance_lead.maybe >>
    (
      excipiens.as(:excipiens) |
      farbstoff |
      substance_ut |
      substance_more_info.maybe >> simple_substance >> corresp_substance.maybe >> space?
    )
                     }
  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:praeparatio){ ((one_word >> space?).repeat(1).as(:description) >> str(':') >> space?).maybe >>
                      (identifier >> space?).repeat(1).as(:substance_name) >>
                      number.as(:qty) >> space >> str('U.:') >> space? >>
                      ((identifier >> space?).repeat(1).as(:more_info) >> space?).maybe
                    }

  rule(:substance_separator) { (comma | str('et ') | str('ut alia: ')) >> space? }
  rule(:one_substance)       { (substance).as(:substance) }
  rule(:one_substance)       { (praeparatio | histamin | substance ).as(:substance) }
  rule(:all_substances)      { (one_substance >> substance_separator.maybe).repeat(1) }
  root :all_substances
end

class SubstanceTransformer < DoseTransformer
  @@substances ||= []
  @@excipiens  = nil
  def SubstanceTransformer.clear_substances
    @@substances = []
    @@excipiens  = nil
  end
  def SubstanceTransformer.substances
    @@substances.clone
  end
  def SubstanceTransformer.excipiens
    @@excipiens ? @@excipiens.clone : nil
  end

  rule(:solvens => simple(:solvens) ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance =  ParseSubstance.new(dictionary[:solvens].to_s)
      substance.more_info =  'Solvens'
      @@substances <<  substance
  }
  rule(:farbstoff => simple(:farbstoff),
       :more_info => simple(:more_info),
       :digits => simple(:digits)) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance =  ParseSubstance.new("#{dictionary[:farbstoff]} #{dictionary[:digits]}")
      substance.more_info =  dictionary[:more_info].to_s.sub(/:$/, '')
      @@substances <<  substance
  }
  rule(:farbstoff => simple(:farbstoff),
       :digits => simple(:digits)) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"  if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new("#{dictionary[:farbstoff]} #{dictionary[:digits]}")
  }
  rule(:substance => simple(:substance)) {
    |dictionary|
    puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
    dictionary[:substance]
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
  }
  rule(:substance_ut => sequence(:substance_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      nil
  }
  rule(:for_ut => sequence(:for_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      if dictionary[:for_ut].size > 1
        @@substances[-2].salts << dictionary[:for_ut].last.clone
        @@substances.delete(dictionary[:for_ut].last)
      end
      nil
  }

  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       :substance_corresp => sequence(:substance_corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      substance.chemical_substance = @@substances.last
      @@substances.delete_at(-1)
      @@substances <<  substance
  }

  rule(:mineralia => simple(:mineralia),
       :more_info => simple(:more_info),
       :substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      substance.more_info = dictionary[:mineralia].to_s + ' ' + dictionary[:more_info].to_s
       # TODO: fix alia
      @@substances <<  substance
  }
  rule(:substance_name => simple(:substance_name),
       :conserv => simple(:conserv),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:dose].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:conserv].to_s.sub(/:$/, '')
  }

  rule(:substance_name => simple(:substance_name),
       :mineralia => simple(:mineralia),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name])
      substance.more_info =  dictionary[:mineralia].to_s.sub(/:$/, '')
      pp substance; binding.pry
      @@substances <<  substance
  }
  rule(:substance_name => simple(:substance_name),
       :residui => simple(:residui),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name])
      @@substances <<  substance
      substance.more_info =  dictionary[:residui].to_s.sub(/:$/, '')
  }
  rule(:substance_name => simple(:substance_name),
       :qty => simple(:qty),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s.strip, ParseDose.new(dictionary[:qty].to_s))
  }

  rule(:substance_name => simple(:substance_name),
       :dose_corresp => simple(:dose_corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose_corresp])
  }
  rule(:description => simple(:description),
       :substance_name => simple(:substance_name),
       :qty => simple(:qty),
       :more_info => simple(:more_info),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:qty].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:more_info].to_s
      substance.description =  dictionary[:description].to_s
      substance
  }
  rule(:der => simple(:der),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:der].to_s)
  }
  rule(:histamin => simple(:histamin),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: histamin dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:histamin].to_s)
  }
  rule(:substance_name => simple(:substance_name),
       ) {
    |dictionary|
       puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"  if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:substance_name])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }

  rule(:substance_name => simple(:substance_name),
       :substance_ut => sequence(:substance_ut),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
  }

  rule(:mineralia => simple(:mineralia),
       :substance_ut => simple(:substance_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
  }

  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       :more_info => simple(:more_info)) {
    |dictionary|
        puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
        substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:dose].to_s))
        substance.more_info = dictionary[:more_info].to_s
        @@substances <<  substance
  }

  rule(:excipiens => simple(:excipiens),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@excipiens = dictionary[:excipiens].is_a?(ParseDose) ? ParseSubstance.new('excipiens', dictionary[:excipiens]) : nil
  }

  rule(:dose_pro => simple(:dose_pro),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      dictionary[:dose_pro]
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

class ParseDose
  attr_reader :qty, :unit, :qty_range
  def initialize(qty=nil, unit=nil)
    puts "ParseDose.new from #{qty.inspect} #{unit.inspect} #{unit.inspect}" if VERBOSE_MESSAGES
    if qty and (qty.is_a?(String) || qty.is_a?(Parslet::Slice))
      string = qty.to_s.gsub("'", '')
      if string.index('-') and (string.index('-') > 0)
        @qty_range = qty
      else
        @qty  = string.index('.') ? string.to_f : string.to_i
      end
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
    return @unit unless qty or qty_range
    res = "#{@qty}#{qty_range}"
    res = "#{res} #{@unit}" if @unit
  end
  def ParseDose.from_string(string)
    cleaned = string.sub(',', '.')
    puts "ParseDose.from_string #{string} -> cleaned #{cleaned}" if VERBOSE_MESSAGES
    value = nil
    parser = DoseParser.new
    transf = DoseTransformer.new
    puts "#{File.basename(__FILE__)}:#{__LINE__}: ==>  #{parser.parse_with_debug(cleaned)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(cleaned))
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose, :is_excipiens
  attr_accessor  :description, :more_info, :salts
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    @name = ParseUtil.capitalize(name.to_s)
    @name.sub!(/\baqua\b/i, 'aqua')
    @name.sub!(/\DER\b/i, 'DER')
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
                  /^(acari allergeni extractum 5000 U\.\:)/ => 'A): \1',

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
    begin
      if defined?(RSpec)
        ast = transf3.apply(parser3.parse(cleaned))
        puts "#{File.basename(__FILE__)}:#{__LINE__}: ==>  #{ast}" if VERBOSE_MESSAGES
      else
        ast = transf3.apply(parser3.parse(cleaned))
      end
    rescue Parslet::ParseFailed => error
      puts "#{File.basename(__FILE__)}:#{__LINE__}: failed parsing ==>  #{cleaned}"
      return nil
    end
    result.source = string
    result.label              = ast[:label].to_s             if ast[:label]
    result.label_description  = ast[:label_description].to_s if ast[:label_description]

    if ast.is_a?(Parslet::Slice)
    else
      result.substances = SubstanceTransformer.substances
      excipiens = SubstanceTransformer.excipiens
      result.substances.each {
        |substance|
          substance.unit                    = "#{substance.unit}/#{excipiens.qty} #{excipiens.unit}"     if substance.unit
          substance.chemical_substance.unit = "#{substance.unit}/#{excipiens.qty} #{excipiens.unit}"     if substance.chemical_substance
      } if excipiens and excipiens.unit
      if ast.is_a?(Array) and  ast.first.is_a?(Hash)
        result.label              = ast.first[:label].to_s
        result.label_description  = ast.first[:label_description].to_s
      end
    end
    return result
  end
end
