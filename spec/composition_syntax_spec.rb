# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'
require 'parslet/convenience'

RunAllParsingExamples = false # Takes over 3 minutes to run, all the other ones just a few seconds
GoIntoPry = true
NoGoIntoPry = false

if NoGoIntoPry

describe CompositionParser do
let(:parser) { CompositionParser.new }
 context "identifier parsing" do
    let(:dose_parser) { parser.dose }
    let(:identifier_parser) { parser.identifier }
    let(:identifier_with_comma_parser) { parser.identifier_with_comma }
    let(:identifier_without_comma_parser) { parser.identifier_without_comma }
    let(:substance_parser) { parser.substance }
    let(:salts_parser) { parser.salts }
    let(:substance_name_parser) { parser.substance_name }
    let(:number_parser) { parser.number }
    let(:excipiens_parser) { parser.excipiens }
    let(:composition_parser) { parser }

    it "parses identifier" do
      text = 'Solvens: conserv.: alcohol benzylicus 18 mg, aqua ad iniectabilia q.s. ad solutionem pro 2 ml.'
      res1 = composition_parser.parse_with_debug(text)
      pp res1; binding.pry
    end
  end
end
else

excipiens_tests = {
  'aqua ad iniectabilia ad solutionem pro 4 ml' => nil,
  'aether q.s. ad solutionem pro 1 g' => 'aether q.s. ad solutionem',
  'saccharum ad globulos pro 1 g'  => 'saccarum',
  'q.s. ad solutionem pro 5 ml' => 'q.s. ad solutionem pro 5 ml',
  'excipiens ad solutionem pro 1 g, corresp. ethanolum  31 % V/V.' => 'zzz',
  'excipiens ad emulsionem pro 1 1' =>  'aether q.s. ad solutionem',
  'aqua ad iniectabilia q.s. ad solutionem pro 1 ml' => "aqua ad iniectabilia q.s. ad solutionem",
  'aqua q.s. ad suspensionem pro 0.5 ml' =>  "aqua q.s. ad suspensionem",
  'excipiens ad pulverem corresp. suspensio reconstituta 1 ml' => 'Excipiens',
  'excipiens ad pulverem pro 1000 mg' => 'Excipiens',
  'excipiens ad emulsionem pro 1 ml' => 'Excipiens',
  'excipiens ad pulverem pro charta' => 'Excipiens',
  'excipiens ad pulverem' => 'Excipiens ad pulverem',
  'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V' => 'Excipiens',
  'excipiens ad solutionem pro 2 ml' => 'Excipiens',
  'excipiens ad solutionem pro 3 ml corresp. 50 µg' => 'Excipiens',
  'excipiens ad solutionem pro 4 ml corresp. 50 µg pro dosi' => 'Excipiens',
  'excipiens pro compresso' => 'Excipiens pro compresso',
}

substance_tests = {
  "U = Histamin Equivalent Prick" => 'U = Histamin Equivalent Prick', # 58566
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum" => "Vipera Aspis > 1000 Ld50 Mus",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80" => "Vipera Aspis > 1000 Ld50 Mus",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus",
  "antitoxinum equis Fab'" => "Antitoxinum Equis Fab'",
  "antitoxinum equis Fab'x" => "Antitoxinum Equis Fab'x",
  "calcii gluconas 100 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
  "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
  "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg" => 'Calcii Gluconas',
  "calcii gluconas corresp. calcium 100 mg" => 'Calcii Gluconas Corresp. Calcium',
  "calcii lactas pentahydricus 25 mg corresp. calcium 100 mg" => 'Calcii Lactas Pentahydricus',
  "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Lactas Pentahydricus',
  "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg" => 'Calcii Lactas Pentahydricus',
  "calcii lactas pentahydricus 25 mg" => 'Calcii Lactas Pentahydricus',
  "conserv.: E 217, E 219" => "E 217",
  "conserv.: E 217, E 219, natrii dehydroacetas" => "E 217",
  "conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "line #{__LINE__}",
  "ethanolum 59.5 % V/V" => 'Ethanolum',
  "globulina equina (immunisé')" => "Globulina Equina (immunisé')",
  "globulina equina (immunisé)" => 'Globulina Equina (immunisé)',
  "globulina equina'" => "Globulina Equina'",
  "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg" => "Osseinum-hydroxyapatit",
  "viperis antitoxinum equis F(ab')" => "Viperis Antitoxinum Equis F(ab')",
  "viperis antitoxinum equis F(ab')2" => "Viperis Antitoxinum Equis F(ab')2",
  "viperis antitoxinum equis F(ab)" => "Viperis Antitoxinum Equis F(ab)",
  "xylometazolini hydrochloridum 0.5 mg, natrii hyaluronas, conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "line #{__LINE__}",
  '1-Chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine 75 mg' => '1-chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine',
  '9,11-linolicum acidum' => "9,11-linolicum Acidum",
  '9,11-linolicum' => "9,11-linolicum",
  'A/California/7/2009 virus NYMC X-179A' => 'A/california/7/2009 Virus Nymc X-179a',
  'DER: 1:4' => 'Der: 1:4',
  'DER: 3.5:1' => 'Der: 3.5:1',
  'DER: 6-8:1' => 'Der: 6-8:1',
  'DTPa-IPV-Komponente (Suspension)' => 'Dtpa-ipv-komponente (suspension)',
  'DTPa-IPV-Komponente' => 'Dtpa-ipv-komponente',
  'E 160(a)' => 'E 160(a)',
  'E 270' => 'E 270',
  'X-179A' => 'X-179a',
  'X179A' => 'X179a',
  'absinthii herba 1.2 g pro charta' => "Absinthii Herba",
  'acidum 9,11-linolicum 3.25 mg' => "Acidum 9,11-linolicum",
  'acidum 9,11-linolicum' => "Acidum 9,11-linolicum",
  'antiox.: E 321' => 'E 321',
  'benzoe 40 guttae' => 'Benzoe',
  'benzoe 40 ml' => 'Benzoe',
  'color.: E 160(a)' => 'E 160', # TODO: or E 160(a) ??
  'ethanolum 70-78 % V/V' => "Ethanolum",
  'ginseng extractum corresp. ginsenosidea 3.4 mg' => 'Ginseng Extractum Corresp. Ginsenosidea',
  'moelle épinière' => 'Moelle épinière',
  'pimpinellae radix 15 % ad pulverem' => 'Pimpinellae Radix',
  'retinoli 7900 U.I.' => 'Retinoli',
  'retinoli palmitas 7900 U.I.' => 'Retinoli Palmitas',
  'sennae folium 75 % corresp. hydroxyanthracenae 2.7 %' => 'Sennae Folium',
  'silybum marianum D3 0.3 ml ad solutionem pro 2 ml' => "Silybum Marianum D3",
  'silybum marianum D3 0.3 ml ad solutionem pro 3 ml corresp. ethanolum 30 % V/V' => "line #{__LINE__}",
  'streptococcus pneumoniae 12 %' => 'Streptococcus Pneumoniae',
  'virus NYMC X-179A' => 'Virus Nymc X-179a',
  'virus poliomyelitis typus 1 inactivatum (D-Antigen) 2 mg' => "Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)",
  'virus poliomyelitis typus 1 inactivatum (D-Antigen)' => 'Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)',
  'virus poliomyelitis typus 1 inactivatum D-Antigen' => 'Virus Poliomyelitis Typus 1 Inactivatum D-antigen',
  'virus poliomyelitis typus inactivatum (D-Antigen) 2 mg' => 'Virus Poliomyelitis Typus Inactivatum (d-antigen)',
  'virus poliomyelitis typus inactivatum (D-Antigen)' => 'Virus Poliomyelitis Typus Inactivatum (d-antigen)',
  'virus poliomyelitis typus inactivatum D-Antigen' => 'Virus Poliomyelitis Typus Inactivatum D-antigen',
  'virus poliomyelitis' => 'Virus Poliomyelitis',
  'virus' => 'Virus',
  'xenonum(133-Xe) 74 -740 MBq' => 'Xenonum(133-xe)',
  'yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt 1850 MBq' => 'Yttrii(90-y) Chloridum Zum Kalibrierungszeitpunkt',
  'yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt' => 'Yttrii(90-y) Chloridum Zum Kalibrierungszeitpunkt',
}


composition_tests = [
  "E 160(a)",
  "E 160(a), adeps lanae",
  "achillea millefolium D3 2,2 mg",
  "achillea millefolium D3 2,2 mg, aconitum napellus D2 1,32 mg, arnica montana D2 2,2 mg",
  "achillea millefolium D3 2,2 mg, aconitum napellus D2 1,32 mg, arnica montana D2 2,2 mg, atropa belladonna D2 2,2 mg, bellis perennis D2 1,1 mg, calendula officinalis D2 2,2 mg, chamomilla recutita D3 2,2 mg, echinacea D2 0,55 mg, echinacea purpurea D2 0,55 mg, hamamelis virginiana D1 0,22 mg, hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg, mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "acida oligoinsaturata 8.15 mg",
  "acida oligoinsaturata 8.15 mg, alcoholes adipis lanae, adeps lanae, color.: E 160(a), excipiens ad emulsionem pro 1 g.\n",
  "acidum 9,11-linolicum 3.25 mg",
  "acidum 9,11-linolicum 3.25 mg, acidum 9,12-linolicum 1.3 mg, aromatica, conserv.: E 215, E 218, excipiens ad emulsionem pro 1 g.\n",
  "adeps lanae, E 160",
  "adeps lanae, E 160(a)",
  "adeps lanae, color.: E 160(a)",
  "adeps lanae, color.: E 160(a), excipiens ad emulsionem pro 1 g.\n",
  "adeps lanae, color.: E 160(a), excipiens ad emulsionem pro 1 g.\n",
  "alcoholes adipis lanae, adeps lanae, color.: E 160(a), excipiens ad emulsionem pro 1 g.\n",
  "atropa belladonna D2 2,2 mg, bellis perennis D2 1,1 mg, calendula officinalis D2 2,2 mg, chamomilla recutita D3 2,2 mg, echinacea D2 0,55 mg, echinacea purpurea D2 0,55 mg, hamamelis virginiana D1 0,22 mg, hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg, mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V\n",
  "cholecalciferolum 250 U.I., acidum ascorbicum 20 mg, calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg, arom.: saccharinum natricum, natrii cyclamas, vanillinum et alia, excipiens pro compresso obducto.",
  "color.: E 160(a)",
  "color.: E 160(a)\n",
  "conserv.: E 217, E 219, natrii dehydroacetas",
  "conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi.",
  "extractum ethanolicum et glycerolicum liquidum ex absinthii herba 0.7 mg, cinnamomi cortex 3.8 mg, guaiaci lignum 14.3 mg, millefolii herba 7 mg, rhoeados flos 11 mg, tormentillae rhizoma 9.5 mg, balsamum tolutanum 0.3 mg, benzoe tonkinensis 4.8 mg, myrrha 2.4 mg, olibanum 0.9 mg, excipiens ad solutionem pro 1 ml, corresp. 40 guttae, corresp. ethanolum 37 % V/V",
  "hamamelis virginiana D1 0,22 mg, hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg, mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg",
  "hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg, mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "hyaluronas, conserv.: E 217, E 219",
  "hypericum perforatum D2 0,66 mg, mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "mercurius solubilis hahnemanni D8 1,1 mg, symphytum officinale D6 2,2 mg, aqua ad iniectabilia, natrii chloridum q.s. ad solutionem pro 2,2 ml.\n",
  "natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi.",
  "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg",
  "rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V",
  "sennae folium 75 % corresp. hydroxyanthracenae 2.7 %",
  "viperis antitoxinum equis F(ab')2 corresp. Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50 mus et Vipera ammodytes > 1000 LD50 mus, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml.",
  "xylometazolini hydrochloridum 0.5 mg, natrii hyaluronas, conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi.",
  'gasum inhalationis, pro vitro',
  'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg',
  'xenonum 74 -740 MBq',
]

nr_parsing_tests = excipiens_tests.size + substance_tests.size + composition_tests.size
if RunAllParsingExamples
  puts "Testing includes #{nr_parsing_tests} lines to be parsed"
else
  puts "Skip testing includes #{nr_parsing_tests} lines to be parsed"
end

# Here follow some low level test of the most important parts of the parser
describe CompositionParser do
  let(:parser) { CompositionParser.new }

  context "should return correct dose for 2*10^9 CFU.'" do
    let(:dose_parse) { parser.dose }

    should_pass = [
      "40 U.",
      "50'000 U.I.",
      "1 Mio. U.I.",
      '3 Mg',
      '2 mg',
      '0.3 ml',
      '0.01 mg/ml',
      '3 mg/ml',
      '2*10^9 CFU',
      '10^4.4 U.',
      '20 mg',
      '100 % m/m',
      '308.7 mg/g',
      '0.11 µg/g',
      '2.2 g',
      '2,2 g',
      '59.5 % V/V',
      '50 %',
      '80-120 g',
      ].each {
        |id|
        it "parses dose #{id}" do
          expect(dose_parse).to     parse(id)
        end
      }
    should_not_pass = [
      '10 2*10^9 CFU',
      '20 20 mg',
      '50%', # This can be part of a name like ferrum-quarz 50%
      ].each {
        |id|
        it "parses dose #{id}" do
          expect(dose_parse).to_not     parse(id)
        end
      }
  end

  context "identifier parsing" do
    let(:identifier_parser) { parser.identifier }

    it "parses identifier" do
      expect(identifier_parser).to     parse("calcium")
      expect(identifier_parser).to     parse("D2")
      expect(identifier_parser).to     parse("9,11-linolicum")
      expect(identifier_parser).to     parse("xenonum(133-Xe)")
      expect(identifier_parser).to_not parse("10")
      expect(identifier_parser).to_not parse("pro asdf")
      expect(identifier_parser).to_not parse("calcium,")
    end
  end

  context "identifier_with_comma parsing" do
    let(:identifier_with_comma_parser) { parser.identifier_with_comma }

    it "parses identifier_with_comma" do
      expect(identifier_with_comma_parser).to     parse("calcium")
    end
    it "parses identifier_with_comma" do
      expect(identifier_with_comma_parser).to     parse("9,11-linolicum")
      expect(identifier_with_comma_parser).to     parse("a_bart_c")
      expect(identifier_with_comma_parser).to     parse("éxcuäseé")
    end
    it "parses identifier_with_comma" do
      expect(identifier_with_comma_parser).to_not parse("10")
      expect(identifier_with_comma_parser).to_not parse("9,11-lino licum")
    end
    it "parses identifier_with_comma no comma at end allowed" do
      expect(identifier_with_comma_parser).to_not parse("calcium9,")
    end
    it "parses identifier_with_comma no comma at end allowed" do
      expect(identifier_with_comma_parser).to_not parse("calcium,")
    end
    it "parses identifier_with_comma no comma at end allowed" do
      expect(identifier_with_comma_parser).to_not parse("9,11-lino licum,")
    end
    it "parses identifier_with_comma" do
      expect(identifier_with_comma_parser).to_not parse("9,11-linolicum;")
    end
  end

  context "label parsing" do
    let(:label_parser) { parser.label }

    should_pass = [
      'A):',
      'II)',
      'V)',
      'A): acari allergeni extractum 50 U.: ',
      ].each {
        |id|
        it "parses label #{id}" do
          expect(label_parser).to     parse(id)
        end
      }
    should_not_pass = [
      'I): albuminum humanum colloidale 0.5 mg,',
      ].each {
        |id|
        it "parses label #{id}" do
          expect(label_parser).to_not   parse(id)
        end
      }
  end

  context "substance parsing" do
    let(:substance_parser) { parser.substance }

    should_pass = [
      'calcium',
      'calcium 10 mg',
      'ferrum-quarz 50% 20 mg',
      'macrogolum 3350',
      'pollinis allergeni extractum (Phleum pratense) 10 U.',
      'phenoxymethylpenicillinum kalicum 1 U.I.',
      'phenoxymethylpenicillinum kalicum 1 Mio. U.I.',
      'DER: 1:4',
      'DER: 3-5:1',
      'DER: 6-8:1',
      'DER: 4.0-9.0:1',
      'retinoli palmitas 7900 U.I.',
      ].each {
        |id|
        it "parses substance #{id}" do
          expect(substance_parser).to     parse(id)
        end
      }
    it "parses substance calcium, zwei" do      expect(substance_parser).to_not parse("calcium, zwei")    end
  end

  context "excipiens parsing" do
    let(:excipiens_parser) { parser.excipiens }

    puts "Testing whether #{excipiens_tests.size} excipiens can be parsed"
    let(:excipiens_parser) { parser.excipiens }
    excipiens_tests.each{
      |value, name|
      it "parses excipiens #{value}" do expect(excipiens_parser).to parse(value) end
    }

  end

  context "substance_name parsing" do
    let(:substance_name_parser) { parser.substance_name }

    should_pass = [
      'calcium',
      'calendula officinalis D2',
      'pollinis allergeni extractum (Phleum pratense)',
      'retinoli palmitas',
      ].each {
        |id|
        it "parses substance_name #{id}" do
          expect(substance_name_parser).to     parse(id)
        end
      }

    should_not_pass = [
      'calcium 10 mg',
      'ferrum-quarz 50% 20 mg',
      'calendula officinalis D2 2.2 mg',
      'macrogolum 3.2',
      'macrogolum 3350 10 mg',
      'pollinis allergeni extractum (Phleum pratense) 10 U.',
      'retinoli palmitas 7900 U.I.',
      ].each {
        |id|
        it "parses substance_name #{id}" do
          expect(substance_name_parser).not_to     parse(id)
        end
      }

  end

  context "simple_substance parsing" do
    let(:simple_substance_parser) { parser.simple_substance }
    should_pass = [
      "2,2'-methylen-bis(6-tert.-butyl-4-methyl-phenolum)",
      "calcium part_b",
      "calcium 10",
      "calcium 10 mg",
#      'macrogolum 3350 10 mg',
      "F(ab')2",
      ].each {
        |id|
        it "parses simple_substance #{id}" do
          expect(simple_substance_parser).to     parse(id)
        end
      }
    should_not_pass = [
        "calcium corresp. 10 ml",
        "excipiens",
        "calcium ut magnesium",
        "calcium et magnesium",
      ].each {
        |id|
        it "parses simple_substance #{id} should fail" do
          expect(simple_substance_parser).to_not   parse(id)
        end
      }
  end

  context "substance_name parsing" do
    should_pass = [
      'calcium',
      'calcium par_2 Part_C',
      'semecarpus anacardium D12',
      'virus poliomyelitis typus inactivatum',
      'virus poliomyelitis typus inactivatum (D-Antigen)',
      'virus poliomyelitis typus 1 inactivatum (D-Antigen)',
      'stanni(II) chloridum dihydricum',
      'ethanol.',
      'calendula officinalis D2',
#      "Viperis Antitoxinum Equis F(ab')2", swissmedic patch, as only one occurrence
      "xenonum(133-Xe)",
      ].each {
        |id|
        let(:substance_name_parser) { parser.substance_name }
        it "parses substance_name #{id}" do
          expect(substance_name_parser).to     parse(id)
        end
      }
    should_not_pass = [
      'calendula officinalis D2 2,2 mg',
      'calcium corresp. xx',
      'calcium residui: xx',
      'calcium ut xx',
      'calcium et xx',
      'calcium,',
      'calcium9,',
      'excipiens pro',
      'albuminum humanum colloidale, stanni(II) chloridum dihydricum',
      ].each {
        |id|
        let(:substance_name_parser) { parser.substance_name }
        it "parses substance_name #{id} should fail" do
          expect(substance_name_parser).to_not   parse(id)
        end
      }
  end

  context "composition parsing" do
    let(:composition_parser) { parser.composition }
    should_pass = [
      'calcium',
      'calcium par_2 Part_C',
      'virus poliomyelitis typus inactivatum',
      'virus poliomyelitis typus inactivatum (D-Antigen)',
      'virus poliomyelitis typus 1 inactivatum (D-Antigen)',
      'toxoidum pertussis 25 µg et haemagglutininum filamentosum 15 µg',
      ].each {
        |id|
        it "parses composition #{id}" do
          expect(composition_parser).to     parse(id)
        end
      }


    puts "Testing whether #{composition_tests.size} compositions can be parsed"
    composition_tests.each{
      |value, name|
      let(:composition_parser) { parser.composition }
      it "parses composition #{value}" do
        expect(composition_parser).to parse(value)
      end
    }
    puts "Testing whether #{substance_tests.size} substances can be parsed as composition"
    substance_tests.each{
      |value, name|
      it "parses substance #{value}" do
        expect(composition_parser).to parse(value)
      end
    }

    if RunAllParsingExamples
      specify { expect( File.exists?(AllCompositionLines)).to eq true }
      composition_lines = IO.readlines(AllCompositionLines)
      puts "Testing whether all #{composition_lines.size} lines in #{File.basename(AllCompositionLines)} can be parsed"
      composition_lines.each{
        |value, name|
        let(:composition_parser) { parser.composition }
        it "parses composition #{value}" do   expect(composition_parser).to parse(value)     end
      }
    else
      puts "Skip testing whether #{composition_tests.size} compositions and #{substance_tests.size} substances can be parsed"
    end

  end

end
end