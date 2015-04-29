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
            (match(['.,^']) >> digit.repeat(1)).repeat(1)
      ).maybe >> (
        match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
      ).maybe
    )
  }
  rule(:radio_isotop) { match['a-zA-Z'].repeat(1) >> lparen >> digits >> str('-') >> match['a-zA-Z'].repeat(1-3) >> rparen >>
                        ((space? >> match['a-zA-Z']).repeat(1)).repeat(0)
                        } # e.g. Xenonum (133-Xe) or yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt
  rule(:ratio_value) { match['0-9:\-\.,'].repeat(1)  >> space?}  # eg. ratio: 1:1, ratio: 1:1.5-2.4., ratio: 1:0.68-0.95, 1:4,1

  # handle stuff like acidum 9,11-linolicum or 2,2'-methylen-bis(6-tert.-butyl-4-methyl-phenolum) specially. it must contain at least one a-z
  rule(:umlaut) { match(['éàèèçïöäüâ']) }
  rule(:identifier_D12) { match['a-zA-Z'] >>  match['0-9'].repeat(1) }

  # TODO: why do we have to hard code these identifiers?
  rule(:fix_coded_identifiers) {
    str("2,2'-methylen-bis(6-tert.-butyl-4-methyl-phenolum)") |
    str('A + B') |
    str('CRM 197') |
    str('F.E.I.B.A.') |
    str('LA ') >> digit.repeat(1,2) >> str('% TM') |
    str('TM:') | str('&') |
    str('ethanol.') |
    str('poloxamerum 238') |
    str('polysorbatum ') >> digit >> digit
  }

  # TODO: Sind diese Abkürzung wirklich Teil eines Substanznamens?
  rule(:identifier_abbrev_with_comma)  {
    str('aquos') |
    str('ca.') |
    str('deklar.') |
    str('spag.') |
    str('spec.') |
    str('spp.') |
    str('ssp.') |
    str('var.')
  }
  rule(:fix_coded_doses) {
    digit >> digit.maybe >> space >> str('per centum ') >> str('q.s.').maybe |
    str('50/50') |
    str('1g/9.6 cm²') |
    str('9 g/L 5.4 ml')
  }
  rule(:identifier)  {  fix_coded_identifiers |
                        identifier_abbrev_with_comma |
                        fix_coded_doses |
                        str('q.s.') |
                        identifier_D12 |
                        identifier_without_comma |
                        identifier_with_comma
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
  rule(:dose_unit) {
    (
      str('cm²') |
      str('g/dm²') |
      str('g/l') |
      str('g/L') |
      str('% V/V') |
      str('µg/24 h') |
      str('µg/g') |
      str('µg') |
      str('ng') |
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
      str('S.U.') |
      str('U. Botox') |
      str('U.I. hFSH') |
      str('U.I. hCG') |
      str('U.I. hLH') |
      str('U.I.') |
      str('U./ml') |
      str('U.K.I.') |
      str('U.') |
      str('Mia.') |
      str('Mrd.') |
      str('% m/m') |
      str('% m/m') |
      str('%')
    ).as(:unit)
  }
  rule(:qty_range)       { (number >> space? >> (str('+/-') | str(' - ') | str(' -') | str('-') | str('±') ) >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { dose_qty >> (space >> dose_unit).maybe }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:min_max)        { (str('min.') | str('max.') | str('ca.') | str('<') ) >> space? }
  # 75 U.I. hFSH et 75 U.I. hLH
  rule(:dose_fsh) { qty_unit >> space >> str('et') >> space >> qty_unit.as(:dose_right) }
  rule(:dose_per) { (digits >> str('/') >> digits).as(:qty)}
  rule(:dose)           { dose_fsh |
                          dose_per |
                          ( min_max.maybe >>
                            ( (qty_range >> (space >> dose_unit).maybe) | (qty_unit | dose_qty |dose_unit)) >> space? ) >>
                        str('pro dosi').maybe >> space?
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
  rule(:der) { (str('DER:')  >> space >> digit >> match['0-9\.\-:'].repeat).as(:substance_name) >> space? >> dose.maybe.as(:dose)
             } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1 or DER: 4.0-9.0:1'
  rule(:forbidden_in_substance_name) {
                            min_max |
                            useage |
                            excipiens_identifiers |
                            pro_identifiers |
                            corresp_substance_label |
                            (digits.repeat(1) >> space >> str(':')) | # match 50 %
                            str(', corresp.') |
                            str('Beutel: ') |
                            str('Mio ') |
                            str('ad emulsionem') |
                            str('ad globulos') |
                            str('ad pulverem') |
                            str('ad q.s. ') |
                            str('ad solutionem') |
                            str('ad suspensionem') |
                            str('ana partes') |
                            str('ana ') |
                            str('aqua ad ') |
                            str('aqua q.s. ') |
                            str('corresp. ca.,') |
                            str('et ') |
                            str('excipiens') |
                            str('partes') |
                            str('pro capsula') |
                            str('pro dosi') |
                            str('pro vitroe') |
                            str('q.s. ad ') |
                            str('q.s. pro ') |
                            str('ratio:') |
                            str('ut alia: ') |
                            str('ut ')
    }
  rule(:name_without_parenthesis) {
    (
      (str('(') | forbidden_in_substance_name).absent? >>
        (radio_isotop | str('> 1000') | str('> 500') | identifier.repeat(1) >> str('.').maybe) >>
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
                            name_with_parenthesis |
                            name_without_parenthesis
                          ) >>
                          str('pro dosi').maybe >> space?
                          }
  rule(:simple_substance) { substance_name.as(:substance_name) >> space? >> dose.maybe.as(:dose)}
  rule(:simple_subtance_with_digits_in_name_and_dose)  {
    substance_lead.maybe.as(:more_info) >> space? >>
    (name_without_parenthesis >> space? >> ((digits.repeat(1) >> (str(' %') | str('%')) | digits.repeat(1)))).as(:substance_name) >>
    space >> dose_with_unit.as(:dose)
  }


  rule(:substance_more_info) { # e.g. "acari allergeni extractum 5000 U.:
      (str('ratio:').absent? >> (identifier|digits) >> space?).repeat(1) >> space? >> (str('U.:') | str(':')| str('.:')) >> space?
    }

  rule(:pro_identifiers) {
                       str('ut aqua ad iniectabilia q.s. ad emulsionem pro ') |
                       str('aqua ').maybe >> str('ad iniectabilia q.s. ad solutionem pro ') |
                       str('aqua ').maybe >> str('ad solutionem pro ')  |
                       str('aqua ').maybe >> str('q.s. ad emulsionem pro ') |
                       str('aqua ').maybe >> str('q.s. ad gelatume pro ') |
                       str('aqua ').maybe >> str('q.s. ad solutionem pro ') |
                       str('aqua ').maybe >> str('q.s. ad suspensionem pro ') |
                       str('doses pro vase ') |
                       str('excipiens ad emulsionem pro ') |
                       str('excipiens ad pulverem pro ') |
                       str('excipiens ad solutionem pro ') |
                       str('pro vase ') |
                       str('q.s. ad pulverem pro ')
  }
  rule(:excipiens_dose) { pro_identifiers.as(:excipiens_description) >> space? >> dose.as(:dose) >> space? >> ratio.maybe.as(:ratio) >>
                    space? >> str('corresp.').maybe >> space? >> dose.maybe.as(:dose_corresp)
                    }

  rule(:excipiens_identifiers)  {
                       str('ad globulos') |
                       str('ad pulverem') |
                       str('ad solutionem') |
                       str('aether q.s.') |
                       str('ana partes') |
                       str('aqua ad iniectabilia q.s. ad solutionem') |
                       str('aqua ad iniectabilia') |
                       str('aqua q.s. ad') |
                       str('excipiens pro compresso obducto') |
                       str('excipiens pro compresso') |
                       str('excipiens pro praeparatione') |
                       str('excipiens') |
                       str('pro charta') |
                       str('pro praeparatione') |
                       str('pro vitro') |
                       str('q.s. ad') |
                       str('q.s. pro praeparatione') |
                       str('saccharum ad') |
                       str('solvens (i.v.): aqua ad iniectabilia')
                      }

  rule(:excipiens)  { substance_lead.maybe.as(:more_info) >> space? >>
                      ( excipiens_dose | excipiens_identifiers.as(:excipiens_description)) >>
                      space? >> excipiens_dose.maybe.as(:dose_2) >>
                      any.repeat(0)
                    }

  rule(:substance_lead) { useage >> space? |
                      str('Beutel:') >> space? |
                      str('residui:') >> space? |
                      str('mineralia:') >> str(':') >> space? |
                      str('Solvens:') >> space? |
                      substance_more_info
    }
  rule(:corresp_substance_label) {
      str(', corresp. ca.,') |
      str('corresp. ca.,') |
      str('corresp.,') |
      str('corresp.') |
      str(', corresp.')
    }
  rule(:ratio) { str('ratio:') >>  space >> ratio_value }

  rule(:solvens) { (str('Solvens:') | str('Solvens (i.m.):'))>> space >> (any.repeat).as(:more_info) >> space? >>
                   (substance.as(:substance) >> str('/L').maybe).maybe  >>
                    any.maybe
                }
    # Perhaps we could have some syntax sugar to make this more easy?
    #
    def tag(opts={})
        close = opts[:close] || false
    end

    # TODO: what does ut alia: impl?
  rule(:substance_ut) {
   (space? >> (str('pro dosi ut ') | str('ut ') ) >>
    space? >> str('alia:').absent? >>substance
  ) >>
    space?
    }

  rule(:corresp_substance) {
                            (corresp_substance_label) >> space? >>
                            (
                             substance |
                             dose.as(:dose_corresp_2) |
                             excipiens.as(:excipiens)
                            )
  }

  rule(:substance) {
      (
      simple_subtance_with_digits_in_name_and_dose |
    der |
    substance_lead.maybe.as(:more_info) >> space? >> lebensmittel_zusatz |
    substance_lead.maybe.as(:more_info) >> space? >> simple_substance >> str('pro dosi').maybe
      ).as(:substance) >>
    (space? >> str(', ').maybe >> ratio.maybe).as(:ratio) >>
    space? >> corresp_substance.maybe.as(:chemical_substance) >>
    space? >> substance_ut.repeat(0).as(:substance_ut) #>>
    # (space? >> str(', ').maybe >> ratio.maybe).as(:ratio)

  }
  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:praeparatio){ ((one_word >> space?).repeat(1).as(:description) >> str(':') >> space?).maybe >>
                      (name_with_parenthesis | name_without_parenthesis).repeat(1).as(:substance_name) >>
                      number.as(:qty) >> space >> str('U.:') >> space? >>
                      ((identifier >> space?).repeat(1).as(:more_info) >> space?).maybe
                    }
  rule(:substance_separator) { (str(', et ') | comma | str('et ') | str('ut alia: ')) >> space? }
  rule(:one_substance)       { (praeparatio | histamin | substance) >> space? >> ratio.as(:ratio).maybe >> space? }
  rule(:all_substances)      { (one_substance >> substance_separator.maybe).repeat(1) >> space? >> excipiens.as(:excipiens).maybe}
  rule(:composition)         { all_substances }
  rule(:long_labels) {
        str('Praeparatio sicca cum solvens: praeparatio sicca:') |
        str('Praeparatio cryodesiccata') >> (str(':').absent? >> any).repeat(0) >> str(':') |
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
    str('aqua ') |
    str('excipiens ') |
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
  rule(:corresp_line_neu) { corresp_label >> any.repeat(1).as(:corresp) }

  rule(:multiple_et_line) {
                        ((label_id >> label_separator >> space? >> (str('pro usu') |str('et '))).repeat(1) >> any.repeat(1)).as(:corresp)
  }

  rule(:polvac) { label_id.as(:label) >> label_separator >> space? >> composition.as(:composition) >> space? >> str('.').maybe >> space? }

  rule(:label_composition) { label >> space? >> composition.as(:excipiens) >> space? >> str('.').maybe >> space? }
  rule(:label_comment_excipiens) { label >> space? >> excipiens.as(:excipiens) >> space? >> str('.').maybe >> space? }

  rule(:expression_comp) {
    corresp_line_neu |
    leading_label.maybe >> space? >> composition.as(:composition) >> space? >> str('.').maybe >> space? |
    multiple_et_line |
    label_composition |
    polvac |
    label_comment_excipiens |
    excipiens.as(:composition) |
    space.repeat(3)
  }
  root :expression_comp
end

