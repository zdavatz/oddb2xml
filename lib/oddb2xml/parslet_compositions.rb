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
  rule(:integer)    { match('[0-9]').repeat(1).as(:int) >> space? }
  rule(:identifier) { match['a-z'].repeat(1) }
  rule(:operator)   { match('[+]') >> space? }

  # Grammar parts
  rule(:sum)        {
    integer.as(:left) >> operator.as(:op) >> expression.as(:right) }
  rule(:arglist)    { expression >> (comma >> expression).repeat }
  rule(:funcall)    {
    identifier.as(:funcall) >> lparen >> arglist.as(:arglist) >> rparen }

  # dose
  # rule(:qty) { integer }
  rule(:dose) { integer.as(:qty) >> str('mg').as(:unit) }

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
end

class ParseDose
  attr_reader :qty, :unit
  def initialize(qty, unit)
    @qty = qty.eval
    @unit = unit.to_s
  end
  def eval
    self
  end
  def ParseDose.from_string(string)
    parser = CompositionsParser.new
    transf = CompositionsTransformer.new
    res = parser.parse(string)
    transf.apply(parser.parse(string))
  end
end

