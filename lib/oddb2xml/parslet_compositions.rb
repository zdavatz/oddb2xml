# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
include Parslet
VERBOSE_MESSAGES = true

class DoseParser < Parslet::Parser

  # Single character rules
  rule(:lparen)     { str('(') >> space? }
  rule(:rparen)     { str(')') >> space? }
  rule(:comma)      { str(',') >> space? }

  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }

  # Things
  rule(:digit) { match('[0-9]') }
  rule(:digits) { digit.repeat(1) }
  rule(:number) {
    (
      str('-').maybe >> (
        str('0') | (match('[1-9]') >> digit.repeat)
      ) >> (
        str('.') >> digit.repeat(1)
      ).maybe >> (
        match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
      ).maybe
    )
  }
  rule(:identifier) { match['a-zA-Zéàèèçïöäüâ'] >> match['0-9a-zA-Z\-éàèèçïöäüâ\'\/\.:%'].repeat(0) }
  #  poliomyelitis typus 1 inactivatum (D-Antigen)
  rule(:name_with_parenthesis) {
    (match('[a-zA-Z]') >> ((match('[0-9]') >> space >> match('[a-zA-Z]')).maybe >>match('[a-zA-Z_\- \(\)]')).repeat) >> space?
  }
  # dose
  rule(:dose_unit)      { (
                           str('% V/V') |
                           str('µg') |
                           str('guttae') |
                           str('mg') |
                           str('Mg') |
                           str('g') |
                           str('l') |
                           str('µl') |
                           str('ml') |
                           str('mg/ml') |
                           str('U.I.') |
                           str('U.') |
                           str('Mia. U.') |
                           str('% ad pulverem') | # only one occurrence  pimpinellae radix 15 % ad pulverem
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> str('-') >> number).as(:qty_range) }
  rule(:qty_unit)       { (qty_range | dose_qty) >> space? >> dose_unit }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { qty_unit | dose_qty |dose_unit}
  root :dose

end

class IntLit   < Struct.new(:int)
  def eval; int.to_i; end
end
class QtyLit   < Struct.new(:qty)
  def eval; qty.to_i; end
end
class Addition < Struct.new(:left, :right)
  def eval; left.eval + right.eval; end
end

class DoseTransformer < Parslet::Transform
  rule(:int => simple(:int))        { IntLit.new(int) }
  rule(:number => simple(:nb)) {
    nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
  }
  rule(
    :left => simple(:left),
    :right => simple(:right),
    :op => '+')                     { Addition.new(left, right) }
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
  rule(:sum)        {
    number.as(:left) >> operator.as(:op) >> expression.as(:right) }

#  rule(:farbstoff) { (str('E').as(:farbstoff) >> space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) } # Match Wirkstoffe like E 270
#  rule(:farbstoff) { ((str('antiox.:') | str('color:')) >> space) |  (str('E').as(:farbstoff) >> space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) } # Match Wirkstoffe like E 270
  rule(:farbstoff) { ((str('antiox.:') | str('color.:'))  >> space).maybe >>  (str('E').as(:farbstoff) >> space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) } # Match Wirkstoffe like E 270
  rule(:name_simple_part) { identifier | identifier >> (space >> identifier).repeat(1) }
  rule(:substance_in_parenthesis) { (name_complex_part >>  space?).repeat(1) >> (comma >> (name_simple_part >> space?).repeat(0)).repeat(0) }
  rule(:name_complex_part) { identifier |
                             str('>') |
                           digit.repeat >> space >> dose_unit.absent? >> any.repeat | # match stuff like typus 1 inactivatum
#                           lparen >> name_simple_part.maybe >> (space? >> name_simple_part).repeat(0) >> rparen       # Match name_with_parenthesis like  (D-Antigen)
#                           lparen >> (name_simple_part >>  space?).repeat(1) >> (comma >> name_simple_part >> space?).maybe >> rparen       # Match name_with_parenthesis like  (D-Antigen)
#                           lparen >> substance_in_parenthesis >> rparen       # Match name_with_parenthesis like  (D-Antigen)
                            str('(') >> substance_in_parenthesis >> str(')') >> digit.repeat(0,1) >> str('-like:').maybe      # Match name_with_parenthesis like  (D-Antigen)
#                           lparen >>  match['a-zA-Z\-éàèçïöäü\''].repeat(1) >> rparen       # Match name_with_parenthesis like  (D-Antigen)
                           }
#  rule(:substance_name) { identifier >> (space >> (identifier|digit >> space >> identifier|lparen >> substance_name >> rparen)).repeat(0) }
  rule(:der) { (str('DER:')  >> space >> (digit >> match['\.-']).maybe >> digit >> str(':') >> digit).as(:der) } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1
  rule(:substance_name) { (name_simple_part >> (space? >> name_complex_part).repeat(0)).as(:substance_name) }
  rule(:substance) { (farbstoff |  substance_name >> space? >> dose.maybe.as(:dose)).as(:substance) }
  rule(:excipiens) { ( str('excipiens ad pulverem') >> space? >> (str('pro charta') |str('pro') >> space? >> dose.as(:dose)).maybe |
                      (str('excipiens') >> space >> ((str('ad solutionem pro') |
                                                      str('pro'))>> space).maybe >> substance).as(:excipiens))
                      .as(:excipiens) }
  #  excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V.
  rule(:additional_substance) { str(',') >> space >> one_substance }
  rule(:substance_residui) { str('residui:')    >> space >> substance }
  rule(:substance_residui) { str('residui:')    >> space >> substance }
  rule(:substance_conserv) { str('conserv.:')   >> space >> substance }
  rule(:substance_corresp) { substance.as(:substance) >> space >> str('corresp.') >> space >> substance.as(:substance_corresp) }
  rule(:substance_ut) { substance.as(:substance_ut) >> space >> str('ut') >> space >> substance }
  rule(:substance_et) { (substance.as(:substance_et) >> space >> str('et') >> space).repeat(1) >> (substance_corresp | substance) }
  rule(:substances) { one_substance.repeat(0, 1) >> additional_substance.repeat(0) }
  rule(:one_substance) { (der | excipiens | substance_residui | substance_conserv | substance_et | substance_ut | substance_corresp | substance) }
  rule(:all_substances) { (one_substance.repeat(0, 1) >> additional_substance.repeat(0)) }
  root :all_substances
end

class SubstanceTransformer < DoseTransformer
  @@substances ||= []
  def SubstanceTransformer.clear_substances
    @@substances = []
  end
  def SubstanceTransformer.substances
    @@substances
  end
  def SubstanceTransformer.add_substance(substance)
    @@substances << substance
  end
  rule(:farbstoff => simple(:farbstoff),
       :digits => simple(:digits)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new("#{dictionary[:farbstoff]} #{dictionary[:digits]}")
  }
  rule(:substance => simple(:substance)) {
    |dictionary|
    puts "#{__LINE__}: dictionary #{dictionary}"
    dictionary[:substance]
    # binding.pry
    # ParseSubstance.new(dictionary[:substance])
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
  }
  rule(:der => simple(:der),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:der].to_s)
  }
  rule(:substance => simple(:substance),
       :substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:substance], dictionary[:dose])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
    ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:excipiens => sequence(:excipiens)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
    ParseSubstance.new(dictionary[:excipiens])
  }
  rule(:substance_name => sequence(:substance_name)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
    ParseSubstance.new(dictionary[:substance_name])
  }
  rule(
    :substances    => simple(:substances) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "substances is #{dictionary[:substances]}"
      binding.pry
      nil
    }
end

class CompositionParser < SubstanceParser

  rule(:composition) { (all_substances.as(:all_substances) ) }
  # "I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I."

#  rule(:label) { (match(/[^:]/).repeat(1)).as(:label2) >> str(':') >> space }

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
                          ).as(:label) >> str(')').maybe >> space >>
    (match(/[^:]/).repeat(1)).as(:label_description)  >> str(':') >> space
  }

  rule(:expression_comp) { label.maybe >> composition.as(:composition) }
  root :expression_comp
end

class CompositionTransformer < SubstanceTransformer
  @@curSubstance = nil
  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      dose = ParseDose.new(dictionary[:qty], dictionary[:unit])
      @@curSubstance.dose = dose if @@curSubstance
      nil
    } if false
  rule(
    :label    => simple(:label) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "label is #{dictionary[:label]}"
      binding.pry
      nil
    }
  rule(:label_description => simple(:label_description) ) {
    binding.pry
  }
  rule(
    :composition    => simple(:composition) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "composition is #{dictionary[:composition]}"
      binding.pry
      nil
    }
end

class ParseDose
  attr_reader :qty, :unit
  def initialize(qty=nil, unit=nil)
    puts "ParseDose.new from #{qty.inspect} #{unit.inspect} #{unit.inspect}" if VERBOSE_MESSAGES
    if qty and (qty.is_a?(String) || qty.is_a?(Parslet::Slice))
      @qty  = qty.to_s.index('.') ? qty.to_s.to_f : qty.to_s.to_i
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
    value = nil
    parser = DoseParser.new
    transf = DoseTransformer.new
    puts " ==>  #{parser.parse(string)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(string))
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose, :is_excipiens
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    binding.pry unless name.is_a?(String)
    @name = name.to_s.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
    if dose
      @qty = dose.qty
      @unit = dose.unit
    end
    SubstanceTransformer.add_substance(self)
  end
  def qty
    @dose ? @dose.qty : @qty
  end
  def unit
    @dose ? @dose.unit : @unit
  end
  def eval
    puts "ParseSubstance.eval" if VERBOSE_MESSAGES
    self
  end
  def ParseSubstance.from_string(string)
    value = nil
    puts "ParseSubstance for string #{string}" if VERBOSE_MESSAGES
    parser = SubstanceParser.new
    transf = SubstanceTransformer.new
    puts " ==>  #{parser.parse(string)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(string))
    return ParseSubstance.new(string) if /^E/.match(string) # Handle Farbstoffe
    if result.is_a?(Array)
      return result.first if result.first.is_a?(ParseSubstance)
      if result.first[:excipiens]
        if result.first[:excipiens].is_a?(Hash) and result.first[:excipiens] and result.first[:excipiens][:dose]
          substance = ParseSubstance.new(string)
          substance.is_excipiens = true
          substance.dose = result.first[:excipiens][:dose]
          return substance
        end
        return ParseSubstance.new(result.first[:excipiens].to_s) if result.first[:excipiens].is_a?(Parslet::Slice)
        if result.first[:excipiens].is_a?(ParseSubstance)
          substance = result.first[:excipiens]
        else
          substance = result.first[:excipiens][:excipiens] if result.first[:excipiens][:excipiens].is_a?(ParseSubstance)
        end
        substance.is_excipiens = true
        return substance
      end
      substance = result.first[:substance]
      substance = result.first[:substance_et] if result.first[:substance_et] and not substance
      substance.dose = ParseDose.new(result.first[:substance].qty.to_s, result.first[:substance].unit) if result.first[:substance]
      if result.first[:substance_corresp]
        substance.chemical_substance = result.first[:substance_corresp]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_et]
        substance.chemical_substance = result.first[:substance_et]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_ut]
        substance.chemical_substance = result.first[:substance_ut]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      end
      puts "ParseSubstance #{string} returning substance #{substance}" if VERBOSE_MESSAGES
      return substance
    end
    result
  end
end

class ParseComposition
  attr_accessor   :source, :label, :label_description, :substances, :galenic_form, :route_of_administration
  def initialize(source)
    @substances ||= []
    puts "ParseComposition.new from #{source.inspect} @substances #{@substances.inspect}" if VERBOSE_MESSAGES
    @source = source.to_s
  end
  def eval
    self
  end
  def ParseComposition.from_string(string)
    cleaned = string.gsub(/^"|[\n\.]+$/, '')
    value = nil
    puts "ParseComposition.from_string #{string}" if VERBOSE_MESSAGES
    SubstanceTransformer.clear_substances
    result = ParseComposition.new(cleaned)
    parser3 = CompositionParser.new
    transf3 = CompositionTransformer.new
    ast = transf3.apply(parser3.parse(cleaned))
    puts "#{__LINE__} #{ast}"
    # binding.pry if ast[:label_description]
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

