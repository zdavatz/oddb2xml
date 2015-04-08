# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
include Parslet

ParseComposition   = Struct.new("ParseComposition",  :source, :label, :label_description, :substances, :galenic_form, :route_of_administration)
ParseSubstance     = Struct.new("ParseSubstance",    :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose)

class CompositionsParser < Parslet::Parser

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

  rule(:identifier) { match['a-z'].repeat(1) }
  rule(:operator)   { match('[+]') >> space? }

  # Grammar parts
  rule(:sum)        {
    number.as(:left) >> operator.as(:op) >> expression.as(:right) }
  rule(:arglist)    { expression >> (comma >> expression).repeat }
#  rule(:funcall)    {
#    identifier.as(:funcall) >> lparen >> arglist.as(:arglist) >> rparen }

  # dose
  rule(:dose_unit)      { (
                           str('mg') |
                           str('g') |
                           str('l') |
                           str('ml') |
                           str('mg/ml')).as(:unit) }
  rule(:qty_unit)       { dose_qty >> space? >> dose_unit }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { qty_unit | dose_qty |dose_unit}

  rule(:expression) { dose }
  #rule(:expression) { dose | funcall | sum | integer }
  root :expression
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

class CompositionsTransformer < Parslet::Transform
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
    :unit   => simple(:unit))  { ParseDose.new(qty, unit) }
  rule(
    :unit    => simple(:unit))  { ParseDose.new(nil, unit) }
  rule(
    :qty    => simple(:qty))  { ParseDose.new(qty, nil) }
end

class ParseDose
  attr_reader :qty, :unit
  def initialize(qty=nil, unit=nil)
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
    parser = CompositionsParser.new
    transf = CompositionsTransformer.new
    result = transf.apply(parser.parse(string))
  end
end

