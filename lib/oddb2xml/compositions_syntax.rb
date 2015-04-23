# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
require 'parslet/convenience'
include Parslet

class CompositionParser < Parslet::Parser

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
            (str('*') >>  digit.repeat(1)).maybe >>
            match(['.,^']) >> digit.repeat(1)
      ).maybe >> (
        match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
      ).maybe
    )
  }
  rule(:radio_isotop) { match['a-zA-Z'].repeat(1) >> lparen >> digits >> str('-') >> match['a-zA-Z'].repeat(1-3) >> rparen >>
                        ((space? >> match['a-zA-Z']).repeat(1)).repeat(0)
                        } # e.g. Xenonum (133-Xe) or yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt
  rule(:ratio_value) { match['0-9:\-\.'].repeat(1)  >> space?}  # eg. ratio: 1:1, ratio: 1:1.5-2.4., ratio: 1:0.68-0.95

  # handle stuff like acidum 9,11-linolicum or 2,2'-methylen-bis(6-tert.-butyl-4-methyl-phenolum) specially. it must contain at least one a-z
  rule(:umlaut) { match(['éàèèçïöäüâ']) }
  rule(:identifier_D12) { match['a-zA-Z'] >>  match['0-9'].repeat(1) }
  rule(:identifier)  {  str('A + B') | str('ethanol.') | str('poloxamerum 238') | str('TM:') | str('&') | # TODO: why do we have to hard code these identifiers?
                        str('spag.') | str('spp.') | str('ssp.') | str('deklar.') | # TODO: Sind diese Abkürzung wirklich Teil eines Substanznamens?
                        str('ca.') | str('var.') | str('spec.') |
                        identifier_D12 | identifier_without_comma | identifier_with_comma
                     }

  rule(:identifier_with_comma) {
    match['0-9,\-'].repeat(0) >> (match['a-zA-Z']|umlaut)  >> (match(['_,']).maybe >> (match['0-9a-zA-Z\-\'\/'] | umlaut)).repeat(0)
  }

  rule(:identifier_without_comma) {
    match['0-9\',\-'].repeat(0) >> (match['a-zA-Z']|umlaut)  >> (match(['_']).maybe >> (match['0-9a-zA-Z\-\'\/'] | umlaut)).repeat(0) >>
        lparen >> (rparen.absent? >> any).repeat(1) >> rparen
  }
  rule(:one_word) { match['a-zA-Z'] >> match['0-9'].repeat(1) | match['a-zA-Z'].repeat(1) }
  rule(:in_parent) { lparen >> one_word.repeat(1) >> rparen }
  rule(:words_nested) { one_word.repeat(1) >> in_parent.maybe >> space? >> one_word.repeat(0) }
  # dose
  # 150 U.I. hFSH et 150 U.I. hLH
  rule(:dose_unit)      { (str('cm²') |
                           str('g/dm²') |
                           str('g/l') |
                           str('g/L') |
                           str('% V/V') |
                           str('µg/24 h') |
                           str('µg/g') |
                           str('µg') |
                           str('guttae') |
                           str('mg/g') |
                           str('mg/ml') |
                           str('MBq/ml') |
                           str('MBq') |
                           str('CFU') |
                           str('mg') |
                           str('Mg') |
                           str('kJ') |
                           str('G') |
                           str('g') |
                           str('l') |
                           str('µl') |
                           str('U. Ph. Eur.') |
                           str('ml') |
                           str('µmol') |
                           str('mmol/l') |
                           str('mmol') |
                           str('Mio CFU') |
                           str('Mio U.I.') |
                           str('Mio U.') |
                           str('Mio. U.I.') |
                           str('Mio. U.') |
                           str('Mia. U.I.') |
                           str('Mia. U.') |
                           str('U.I. hFSH') |
                           str('U.I. hCG') |
                           str('U.I. hLH') |
                           str('U.I.') |
                           str('U./ml') |
                           str('U.') |
                           str('Mia.') |
                           str('Mrd.') |
                           str('% m/m') |
                           str('% m/m') |
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> (str(' - ') | str(' -') | str('-') | str('±')) >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { dose_qty >> (space >> dose_unit).maybe }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:min_max)        { str('mind.') | (str('min.') | str('max.') | str('ca.') ) >> space? } # TODO: swissmedic should replace mind. -> min.
  # 75 U.I. hFSH et 75 U.I. hLH
  rule(:dose_fsh) { qty_unit >> space >> str('et') >> space >> qty_unit.as(:dose_right) }
  rule(:dose)           { dose_fsh |
                          ( min_max.maybe >>
                            ( (qty_range >> (space >> dose_unit).maybe) | (qty_unit | dose_qty |dose_unit)) >> space? )
                           }
  rule(:dose_with_unit) { min_max.maybe >>
                            dose_fsh |
                          ( qty_range >> space >> dose_unit |
                            dose_qty  >> space >> dose_unit
                          ) >>
                          space?
                        }
  rule(:operator)   { match('[+]') >> space? }

  # Grammar parts
  rule(:useage) {   (any >> str('berzug:')) | # match Überzug
                    str('antiox.:') |
                    str('arom.:') |
                    str('conserv.:') |
                    str('color.:')
                   }
  rule(:lebensmittel_zusatz) {  str('E').as(:lebensmittel_zusatz) >> space >>
                                (digits >> match['(a-z)'].repeat(0,3)).as(:digits) >>
                                (space >> dose.as(:dose_lebensmittel_zusatz)).maybe >> space?

                   } # Match Wirkstoffe like E 270
  rule(:der) { (str('DER:')  >> space >> digit >> match['0-9\.\-:'].repeat).as(:der) >> space?
             } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1 or DER: 4.0-9.0:1'
  rule(:forbidden_in_substance_name) {
                           useage |
                           min_max |
                           str('corresp. ca.,') |
                           str(', corresp.') |
                           str('corresp.') |
                           str('ratio:') |
                            str('Mio ') |
                            str('et ') |
                            str('ut ') |
                            str('Beutel: ') |
                            str('ut alia: ') |
                            str('per centum ') |
                            str('pro dosi') |
                            str('pro capsula') |
                            (digits.repeat(1) >> space >> str(':')) | # match 50 %
                            str('ad globulos') |
                            str('ana ') |
                            str('ana partes') |
                            str('partes') |
                            str('ad pulverem') |
                            str('ad suspensionem') |
                            str('q.s. ') |
                            str('ad solutionem') |
                            str('ad emulsionem') |
                            str('excipiens')
    }
  rule(:name_without_parenthesis) {
    (
      (str('(') | forbidden_in_substance_name).absent? >>
        (radio_isotop | str('> 1000') | str('> 500') | identifier.repeat(1)) >>
      space?
    ).repeat(1)
  }

  rule(:part_with_parenthesis) { lparen >> ( (lparen | rparen).absent? >> any).repeat(1) >>
                                 (part_with_parenthesis | rparen >> str('-like:') | rparen  ) >> space?
                               }
  rule(:name_with_parenthesis) {
    forbidden_in_substance_name.absent? >>
    ((comma | lparen).absent? >> any).repeat(0) >> part_with_parenthesis >>
    (forbidden_in_substance_name.absent? >> (identifier.repeat(1) | part_with_parenthesis | rparen) >> space?).repeat(0)
  }
  rule(:substance_name) { (
                            der |
                            name_with_parenthesis |
                            name_without_parenthesis
                          ) >>
                          str('pro dosi').maybe
                          }
  rule(:simple_substance) { substance_name.as(:substance_name) >> space? >> dose.as(:dose).maybe}
  rule(:simple_subtance_with_digits_in_name_and_dose)  {
    substance_lead.maybe >> space? >>
    (name_without_parenthesis >> space? >> ((digits.repeat(1) >> (str(' %') | str('%')) | digits.repeat(1)))).as(:substance_name) >>
    space >> dose_with_unit.as(:dose)
  }


  rule(:pro_dose) { str('pro') >>  space >> dose.as(:dose_corresp) }

    # TODO: what does ut alia: impl?
  rule(:substance_ut) {
      (substance_lead.maybe >> simple_substance).as(:substance_ut) >>
  (space? >> (str('pro dosi ut ') | str('ut ') )  >>
    space? >> str('alia:').absent? >>
    (excipiens |
    substance_name >> space? >> str('corresp.') >> space? >> substance_lead.maybe >> space? >> simple_substance |
    simple_substance
     ).as(:for_ut)
  ).repeat(1) >>
    space? # >> str('alia:').maybe >> space?
    }

  rule(:substance_more_info) { # e.g. "acari allergeni extractum 5000 U.:
      (str('ratio:').absent? >> (identifier|digits) >> space?).repeat(1).as(:more_info) >> space? >> (str('U.:') | str(':')| str('.:')) >> space?
    }

  rule(:dose_pro) { (
                       str('excipiens ad solutionem pro ') |
                       str('aqua q.s. ad gelatume pro ') |
                       str('aqua q.s. ad solutionem pro ') |
                       str('aqua q.s. ad suspensionem pro ') |
                       str('q.s. ad pulverem pro ') |
                       str('pro vase ') |
                       str('per centum ') |
                       str('excipiens ad emulsionem pro ') |
                       str('excipiens ad pulverem pro ') |
                       str('aqua ad iniectabilia q.s. ad solutionem pro ')
                    )  >> dose.as(:dose_pro) >> space? >> ratio.as(:ratio).maybe
  }

  rule(:excipiens)  { (dose_pro |
                       str('excipiens pro compresso obducto') |
                       str('excipiens pro compresso') |
                       str('excipiens pro praeparatione') |
                       str('excipiens') |
                       str('ad pulverem') |
                       str('pro charta') |
                       str('ad globulos') |
                       str('aqua ad iniectabilia q.s. ad solutionem') |
                       str('solvens (i.v.): aqua ad iniectabilia') |
                       str('ad solutionem') |
                       str('q.s. ad') |
                       str('aqua q.s. ad') |
                       str('saccharum ad') |
                       str('aether q.s.') |
                       str('aqua ad iniectabilia') |
                       str('aqua ad iniectabilia') |
                       str('q.s. pro praeparation') |
                       str('ana partes')
                      ) >> space? >>
                      ( any.repeat(0) )
                      }

  rule(:substance_lead) { useage.as(:more_info) >> space? |
                      str('Beutel:').as(:more_info) >> space? |
                      str('residui:').as(:more_info) >> space? |
                      str('mineralia').as(:mineralia) >> str(':') >> space? |
                      str('Solvens:').as(:solvens) >> space? |
                      substance_more_info
    }
  rule(:corresp_substance_label) {
      str(', corresp. ca.,') |
      str('corresp. ca.,') |
      str('corresp.') |
      str('corresp., ') |
      str(', corresp.')
    }

  rule(:corresp_substance) {
                            (corresp_substance_label) >> space? >>
                            (
                             simple_substance.as(:substance_corresp) |
                             dose.as(:dose_corresp_2)
                            )
  }

  rule(:ratio) { str('ratio:') >>  space >> ratio_value }

  rule(:solvens) { (str('Solvens:') | str('Solvens (i.m.):'))>> space >> (any.repeat).as(:solvens) >> space? >>
                   (substance.as(:substance) >> str('/L').maybe).maybe  >>
                    any.maybe
                }
  rule(:substance) {
    simple_subtance_with_digits_in_name_and_dose |
    ratio.as(:ratio) |
    solvens |
    der  >> corresp_substance.maybe |
    (str('potenziert mit:') >> space).maybe >> excipiens.as(:excipiens) |
    substance_ut |
    substance_lead.maybe >> space? >> lebensmittel_zusatz |
    substance_lead.maybe >> space? >> simple_substance >> corresp_substance.maybe >> space? >> corresp_substance.maybe >> space? >> dose_pro.maybe >> str('pro dosi').maybe
  }

  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:praeparatio){ ((one_word >> space?).repeat(1).as(:description) >> str(':') >> space?).maybe >>
                      (name_with_parenthesis | name_without_parenthesis).repeat(1).as(:substance_name) >>
                      number.as(:qty) >> space >> str('U.:') >> space? >>
                      ((identifier >> space?).repeat(1).as(:more_info) >> space?).maybe
                    }
  rule(:substance_separator) { (str(', et ') | comma | str('et ') | str('ut alia: ')) >> space? }
  rule(:one_substance)       { (praeparatio | histamin | substance).as(:substance) >> space? >> ratio.as(:ratio).maybe }
  # rule(:one_substance)       { (substance_ut).as(:substance) } # >> str('.').maybe }
  rule(:all_substances)      { (one_substance >> substance_separator.maybe).repeat(1) }
  rule(:composition)         { all_substances }
  rule(:long_labels) {
        str('Praeparatio cryodesiccata:') |
        str('Tela cum praeparatione (Panel ') >> digit >> str('):') 
      }
  rule(:label_id) {
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
     )
  }
  rule(:label_separator) {  (str('):')  | str(')')) }
  rule(:label) { label_id.as(:label) >> space? >>
    label_separator >> str(',').absent?  >>
               (space? >> (match(/[^:]/).repeat(0)).as(:label_description)  >> str(':') >> space).maybe
  }
  rule(:leading_label) {    label_id >> label_separator >> (str(' et ') | str(', ') | str(' pro usu: ') | space) >>
                            label_id >> label_separator >> any.repeat(1)  |
                            long_labels.as(:label) |
                            label
    }
  rule(:corresp_label) {
    str('doses ') |
    str('Pulver: ') |
    str('Diluens: ') |
    str('Solvens (i.v.): ') |
    str('Solvens (i.m.): ') |
    str('Solvens: ') |
    str('Solutio reconstituta:') |
    str('Corresp., ') |
    str('Corresp. ') |
    str('corresp. ')
  }
  rule(:corresp_line) { corresp_label >> any.repeat(1).as(:corresp)  |
                        ((label_id >> label_separator >> space? >> str('et ').maybe).repeat(1) >> any.repeat(1)).as(:corresp)
  }

  rule(:expression_comp) {
    leading_label.maybe >> space? >> composition.as(:composition) >> space? >> str('.').maybe >> space? |
    corresp_line
  }
  root :expression_comp
end

