# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
include Parslet
VERBOSE_MESSAGES = false

class DoseParser < Parslet::Parser

  # Single character rules
  rule(:lparen)     { str('(') >> space? }
  rule(:rparen)     { str(')') >> space? }
  rule(:comma)      { str(',') >> space? }

  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }

  # Things
  rule(:digit) { match('[0-9]') }
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
  rule(:identifier) {
    (match('[a-zA-Z]') >> match('[a-zA-Z_]').repeat) >> space?
  }
  # dose
  rule(:dose_unit)      { (
                           str('mg') |
                           str('g') |
                           str('l') |
                           str('ml') |
                           str('mg/ml') |
                           str('U.I.')
                          ).as(:unit) }
  rule(:qty_unit)       { dose_qty >> space? >> dose_unit }
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
class FunCall < Struct.new(:name, :args);
  def eval
    p args.map { |s| s.eval }
  end
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
    :funcall => 'puts',
    :arglist => subtree(:arglist))  { FunCall.new('puts', arglist) }
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
  rule(:arglist)    { expression >> (comma >> expression).repeat }
#  rule(:funcall)    {
#    identifier.as(:funcall) >> lparen >> arglist.as(:arglist) >> rparen }

  rule(:substance) { (identifier >> space.maybe).repeat.as(:substance) >> str('.').maybe >> dose.repeat(0,1) }
  rule(:excipiens) { str('excipiens') >> space >> (str('pro') >> space).maybe >> substance }
  rule(:substances) { substance.repeat(0, 1) >> additional_substance.repeat(0) }
  rule(:additional_substance) { str(',') >> space >> substance }

  rule(:expression) { excipiens | substances }
  #rule(:expression) { dose | funcall | sum | integer }
  root :expression
end

class SubstanceTransformer < DoseTransformer
  rule(:substance => simple(:substance)) {
    |dictionary|
    ParseSubstance.new(dictionary[:substance])
  }
end

class CompositionParser < SubstanceParser

  rule(:composition) { (substances >> str('.').repeat(0,2)) }
  rule(:expression) { composition }
  root :expression
end

class CompositionTransformer < DoseTransformer
  rule( :substance => simple(:substance) )  {
    |dictionary|
    @@curSubstance = ParseSubstance.new(dictionary[:substance])
  }

  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
    |dictionary|
      @@curSubstance.dose = ParseDose.new(dictionary[:qty], dictionary[:unit])
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
  def ParseDose.from_string(string)
    value = nil
    parser = DoseParser.new
    transf = DoseTransformer.new
    result = transf.apply(parser.parse(string))
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    @name = name.to_s.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
    if dose
      @qty = dose.qty
      @unit = dose.unit
    end
  end
  def qty
    @dose ? @dose.qty : @qty
  end
  def unit
    @dose ? @dose.unit : @unit
  end
  def eval
    self
  end
  def ParseSubstance.from_string(string)
    value = nil
    puts "ParseSubstance for string #{string}" if VERBOSE_MESSAGES
    parser = SubstanceParser.new
    transf = SubstanceTransformer.new
    result = transf.apply(parser.parse(string))
    if result.is_a?(Array)
      second = result.flatten[0]
      if second.name.eql?('E') # Handle Farbstoffe
        second.name = "E #{result[1].qty}"
      else
        if result.size > 1
          second.dose = result[1]
          second.qty  = result[1].qty
          second.unit = result[1].unit
          puts "ParseSubstance returning second #{second}" if VERBOSE_MESSAGES
        end
      end
      return second
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
    value = nil
    result = ParseComposition.new(string)
    parser3 = CompositionParser.new
    transf3 = CompositionTransformer.new
    ast = transf3.apply(parser3.parse(string))
    ast.find_all{|x| x.is_a?(ParseSubstance)}.each{ |x| result.substances << x }
    return result
  end
end

