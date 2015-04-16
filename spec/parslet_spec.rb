# encoding: utf-8

begin
require 'pry'
rescue LoadError
end
require 'pp'
require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'

RunAllCompositionsTests = true # takes over two minutes!
RunAllParsingExamples = false
RunFailingSpec = false
RunExcipiensTest = false
RunDoseTests = true
RunSpecificTests = true
RunMostImportantParserTests = false
TryRun = false
SkipExcipiensTest = true
RunCompositionExamples = false
RunSubstanceExamples = false

excipiens_tests = {
#  'aqua ad iniectabilia q.s. ad solutionem pro 1 ml' => "aqua ad iniectabilia q.s. ad solutionem",
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
  'ginseng extractum 40 mg corresp. ginsenosidea 1.6 mg' => 'Ginseng Extractum',
  'pyrazinamidum' => 'Pyrazinamidum',
}

substance_tests = {
  "U = Histamin Equivalent Prick" => 'U = Histamin Equivalent Prick', # 58566
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80, Aqua Ad Iniectabilia Ad Solutionem Pro 4 Ml",
  "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80, Aqua Ad Iniectabilia q.s. Ad Solutionem Pro 4 Ml",
  "acari allergeni extractum (acarus siro) 50'000 U." => 'Acari Allergeni Extractum (acarus Siro)',
  "acari allergeni extractum 50'000 U." => 'Acari Allergeni Extractum',
  "acari allergeni extractum 50'000 U.:" => 'Acari Allergeni Extractum',
  "antitoxinum equis Fab'" => "Antitoxinum Equis Fab'",
  "antitoxinum equis Fab'x" => "Antitoxinum Equis Fab'x",
  "aqua ad iniectabilia ad solutionem pro 4 ml" => "Aqua Ad Iniectabilia Ad Solutionem Pro",
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
  "corresp. ethanolum 59.5 % V/V" => 'Corresp. Ethanolum',
  "ethanolum 59.5 % V/V" => 'Ethanolum',
  "excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "Excipiens Ad Solutionem Pro 1 Ml Corresp. 50 µg Pro Dosi",
  "excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "line #{__LINE__}",
  "globulina equina (immunisé')" => "Globulina Equina (immunisé')",
  "globulina equina (immunisé)" => 'Globulina Equina (immunisé)',
  "globulina equina'" => "Globulina Equina'",
  "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg" => 'Haemagglutininum Influenzae B (virus-stamm B/massachusetts/2/2012-like: B/massachusetts/2/2012)',
  "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg" => "Osseinum-hydroxyapatit",
  "viperis antitoxinum equis F(ab')" => "Viperis Antitoxinum Equis F(ab')",
  "viperis antitoxinum equis F(ab')2" => "Viperis Antitoxinum Equis F(ab')2",
  "viperis antitoxinum equis F(ab)" => "Viperis Antitoxinum Equis F(ab)",
  "xylometazolini hydrochloridum 0.5 mg, natrii hyaluronas, conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "line #{__LINE__}",
  '1-Chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine 75 mg' => '1-chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine',
  '9,11-linolicum acidum' => "9,11-linolicum ",
  '9,11-linolicum' => "9,11-linolicum",
  'A/California/7/2009 virus NYMC X-179A' => 'A/california/7/2009 Virus Nymc X-179a',
  'DER: 1:4' => 'Der: 1:4',
  'DER: 3.5:1' => 'Der: 3.5:1',
  'DER: 6-8:1' => 'Der: 6-8:1',
  'DTPa-IPV-Komponente (Suspension)' => 'Dtpa-ipv-komponente (suspension)',
  'DTPa-IPV-Komponente' => 'Dtpa-ipv-komponente',
  'E 160(a)' => 'E 160(a)',
  'E 270' => 'E 270',
  'Praeparatio cryodesiccata: virus rabiei inactivatum (Stamm: Wistar Rabies PM/WI 38-1503-3M) min. 2.5 U.I.' => "line #{__LINE__}",
  'X-179A' => 'X-179a',
  'X179A' => 'X179a',
  'absinthii herba 1.2 g pro charta' => "Absinthii Herba",
  'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %  et dermatophagoides pteronyssinus 50 %' => 'Acari Allergeni Extractum',
  'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %' => 'Acari Allergeni Extractum',
  'acari allergeni extractum 5000 U.: dermatophagoides farinae' => 'Acari Allergeni Extractum',
  'acari allergeni extractum 5000 U.:' => 'Acari Allergeni Extractum',
  'acidum 9,11-linolicum 3.25 mg' => "Acidum 9,11-linolicum",
  'acidum 9,11-linolicum' => "Acidum 9,11-linolicum",
  'antiox.: E 321' => 'E 321',
  'benzoe 40 guttae' => 'Benzoe',
  'benzoe 40 ml' => 'Benzoe',
  'color.: E 160(a)' => 'E 160', # TODO: or E 160(a) ??
  'ethanolum 70-78 % V/V' => "Ethanolum",
  'excipiens ad solutionem pro 1 ml' => "Ad Solutionem Pro",
  'ginseng extractum corresp. ginsenosidea 3.4 mg' => 'Ginseng Extractum Corresp. Ginsenosidea',
  'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg' => 'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)',
  'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins)' => 'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)',
  'globulina equina (immunisé de, tissu pulmonaire)' => 'Globulina Equina (immunisé De, Tissu Pulmonaire)',
  'globulina equina (immunisé de, tissu)' => "Globulina Equina (immunisé De, Tissu)",
  'globulina equina (immunisé)' => 'Globulina Equina (immunisé)',
  'globulina equina (immunisé, tissu pulmonaire)' => 'Globulina Equina (immunisé, Tissu Pulmonaire)',
  'globulina equina (immunisé, tissu)' => 'Globulina Equina (immunisé, Tissu)',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009  xx) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009  Xx)',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) ) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) )',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) like reassortant virus NYMC X-179A)'  => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) Like Reassortant Virus Nymc X-179a)',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) xx) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) Xx)',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like ) 15 µg' => "line #{__LINE__}",
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1)-like: Reassortant Virus Nymc X-179a)',
  'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A)' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1)-like: Reassortant Virus Nymc X-179a)',
  'haemagglutininum influenzae A reassortant (Virus-Stamm virus NYMC X-179A) 15 µg' => 'Haemagglutininum Influenzae A Reassortant (virus-stamm Virus Nymc X-179a)',
  'moelle épinière' => 'Moelle épinière',
  'pimpinellae radix 15 % ad pulverem' => 'Pimpinellae Radix',
  'procainum 10 mg ut procaini hydrochloridum' => 'Procaini Hydrochloridum',
  'retinoli 7900 U.I.' => 'Retinoli',
  'retinoli 7900' => "Retinoli",
  'retinoli palmitas 7900 U.I.' => 'Retinoli Palmitas',
  'retinoli' => 'Retinoli',
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
  "A): acari allergeni extractum 50 U.: dermatophagoides farinae 50",
  "E 160(a)",
  "E 160(a), adeps lanae",
  "I) DTPa-IPV-Komponente: toxoidum diphtheriae, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum",
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
  "excipiens ad emulsionem pro 1 g.\n",
  "excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi.",
  "extractum ethanolicum et glycerolicum liquidum ex absinthii herba 0.7 mg, cinnamomi cortex 3.8 mg, guaiaci lignum 14.3 mg, millefolii herba 7 mg, rhoeados flos 11 mg, tormentillae rhizoma 9.5 mg, balsamum tolutanum 0.3 mg, benzoe tonkinensis 4.8 mg, myrrha 2.4 mg, olibanum 0.9 mg, excipiens ad solutionem pro 1 ml, corresp. 40 guttae, corresp. ethanolum 37 % V/V",
  "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg",
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
  'A): acari allergeni extractum 50 U.: dermatophagoides farinae 50 %',
  'V): mannitolum 40 mg pro dosi.',
  'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %, aluminium, aluminii hydroxidum hydricum ad adsorptionem, natrii chloridum, conserv.: phenolum 4.0 mg, aqua q.s. ad suspensionem pro 1 ml.',
  'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %',
  'excipiens ad pulverem corresp. suspensio reconstituta 1 ml',
  'gasum inhalationis, pro vitro',
  'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.',
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

  context "identifier parsing" do
    let(:identifier_parser) { parser.identifier }

    it "parses identifier" do
      expect(identifier_parser).to     parse("calcium")
      expect(identifier_parser).to_not parse("10")
      expect(identifier_parser).to_not parse("pro asdf")
      expect(identifier_parser).to_not parse("calcium,")
      expect(identifier_parser).to_not parse("xenonum(133-Xe)")
      expect(identifier_parser).to_not parse("9,11-linolicum")
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

  context "substance parsing" do
    let(:substance_parser) { parser.substance }

    should_pass = [
      'calcium',
      'calcium 10 mg',
      'pollinis allergeni extractum (Phleum pratense) 10 U.',
      'retinoli palmitas 7900 U.I.',
#      "Praeparatio cryodesiccata: pollinis allergeni extractum 25'000 U.: urtica dioica"
      ].each {
        |id|
        it "parses substance #{id}" do
          expect(substance_parser).to     parse(id)
        end
      }
    it "parses substance calcium, zwei" do      expect(substance_parser).to_not parse("calcium, zwei")    end

    if RunAllParsingExamples
      puts "Testing whether #{excipiens_tests.size} excipiens can be parsed"
      let(:substance_parser) { parser.substance }
      excipiens_tests.each{
        |value, name|
        it "parses substance #{value}" do expect(substance_parser).to parse(value)
      end
      }
    else
      puts "Skip testing whether #{excipiens_tests.size} excipiens can be parsed"
    end

    if RunAllParsingExamples
      puts "Testing whether #{substance_tests.size} substances can be parsed"
      substance_tests.each{
        |value, name|
        it "parses substance #{value}" do   expect(substance_parser).to parse(value)   end
      }
    else
      puts "Skip testing whether #{substance_tests.size} substances can be parsed"
    end
  end

  context "simple_substance parsing" do
    let(:simple_substance_parser) { parser.simple_substance }
    should_pass = [
      "calcium part_b",
      "calcium 10",
      "calcium 10 mg",
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
      'virus poliomyelitis typus inactivatum',
      'virus poliomyelitis typus inactivatum (D-Antigen)',
      'virus poliomyelitis typus 1 inactivatum (D-Antigen)',
      'DER: 1:4',
      'DER: 3-5:1',
      'DER: 6-8:1',
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
      'calcium corresp. xx',
      'calcium residui: xx',
      'calcium ut xx',
      'calcium et xx',
      'calcium 10',
      'calcium,',
      'calcium9,',
      'excipiens pro',
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
#      'A) Rote Filmtablette: estradiolum 1 mg ut estradiolum hemihydricum, excipiens pro compresso obducto',
#      'I) Fibrinogen-Konzentrat: fibrinogenum humanum 45 mg, factor XIII 30 U.I., albuminum humanum, arginini hydrochloridum, isoleucinum, natrii hydrogenoglutamas monohydricus, natrii chloridum, natrii citras dihydricus, pro vitro'
      ].each {
        |id|
        it "parses composition #{id}" do
          expect(composition_parser).to     parse(id)
        end
      }

    if RunAllParsingExamples
      puts "Testing whether #{composition_tests.size} compositions can be parsed"
      composition_tests.each{
        |value, name|
        let(:composition_parser) { parser.composition }
        it "parses composition #{value}" do   expect(composition_parser).to parse(value)     end
      }
    else
      puts "Skip testing whether #{composition_tests.size} compositions can be parsed"
    end

  end

end

def run_composition_tests(strings)
  strings.each {
    |source|
    context "should parse #{source}" do
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
    end
  }
end

def run_substance_tests(hash_string_to_name)
  hash_string_to_name.each{ |string, name|
    context "should consume #{string}" do
      SubstanceTransformer.clear_substances
      substance = ParseSubstance.from_string(string)
      unless substance and substance.respond_to?(:name) and name.eql? substance.name
        puts "SOLL: #{name} #{substance.inspect}"
        # pp substance; binding.pry
      end
      specify { expect(substance.class).to eq ParseSubstance }
      specify { expect(substance.name).to eq name } if substance and substance.is_a?(ParseSubstance)
    end
  }
end

describe ParseSubstance do

  run_substance_tests(substance_tests) if RunSubstanceExamples
    context "should testlabor'" do
      source =
# "berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V"
# "silybum marianum D3 0.3 ml ad solutionem pro 2 ml"
#'haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg'
#'haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012)'
# "berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, "
#"berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V"
#'adrenalinum 150 µg ut adrenalini tartras, natrii chloridum, antiox.: E 223 86 µg, aqua ad iniectabilia pro dosi.'
#aluminium, aluminii hydroxidum hydricum ad adsorptionem, natrii chloridum, conserv.: phenolum 4.0 mg, aqua q.s. ad suspensionem pro 1 ml.\n"
# 'antiox.: E 223 86 µg'
# 'acidum fusidicum 10 mg, excipiens ad gelatum pro 1 g.'
#'acidum salicylicum 10 mg, triclosanum 2.5 mg, color.: E 171, E 172, excipiens ad praeparationem pro 1 g.'
#'acidum fusidicum 20 mg, antiox.: E 320, conserv.: E 202, excipiens ad unguentum pro 1 g.'
#'excipiens ad solutionem pro 1 g, corresp. ethanolum 40 % V/V.'
# 'excipiens ad solutionem pro 1 g'
#'acidum silicicum D11, arctostaphylos uva-ursi D5, calcium carbonicum hahnemanni D11, cina D5, ferrum phosphoricum D11, sepia officinalis D11 ana partes 16.67 mg, excipiens ad solutionem pro 1 g, corresp. ethanolum 40 % V/V.'
#"acidum silicicum D12, arnica montana D6, carbo vegetabilis D12, echinacea D3, graphites D6, myristica sebifera D6, sulfuris iodidum D6 ana partes 100 mg, alcohol cetylicus, arachidis oleum hydrogenatum, polysorbatum 60, propylenglycolum, aqua q.s. ad unguentum pro 1 g.\n"
#'magnesii hydrogenophosphas trihydricus D15 ana partes 8.33 mg, excipiens pro compresso.'
#'magnesii hydrogenophosphas trihydricus D15 ana partes 8.33 mg'

#'symphytum officinale D6 ana partes ad solutionem, corresp. ethanolum 50 % V/V.'
#'acidum silicicum D12, argenti nitras D30, arnica montana D6, aurum metallicum D30, calcium carbonicum hahnemanni D12, magnesii subcarbonas D10, stillingia silvatica D4, symphytum officinale D6 ana partes ad solutionem, corresp. ethanolum 50 % V/V.'

#"acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %"
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 6 }
      specify { expect(composition.substances.first.name).to eq 'Pollinis Allergeni Extractum (phleum Pratense)' }
    end if false
  run_substance_tests(excipiens_tests) if RunExcipiensTest
end

describe ParseDose do

if RunSpecificTests

  context "should return correct dose for 40 U.'" do
    dose = ParseDose.from_string("40 U.")
    specify { expect(dose.qty).to eq 40.0 }
    specify { expect(dose.unit).to eq 'U.' }
  end

  context "should return correct dose for '50'000 U.I.' (number has ')" do
    dose = ParseDose.from_string("50'000 U.I.")
    specify { expect(dose.qty).to eq 50000.0 }
    specify { expect(dose.unit).to eq 'U.I.' }
  end if RunMostImportantParserTests

  context "should return correct dose for '3,45' (number has comma, no decimal point)" do
    dose = ParseDose.from_string("3,45")
    specify { expect(dose.qty).to eq 3.45 }
    specify { expect(dose.unit).to eq nil }
  end if RunMostImportantParserTests

  context "should return correct dose for '20 %'" do
    string = "20 %"
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 20 }
    specify { expect(dose.unit).to eq '%' }
  end

  context "should return correct dose for 'mg'" do
    dose = ParseDose.from_string('mg')
    specify { expect(dose.qty).to eq 1.0 }
    specify { expect(dose.unit).to eq 'mg' }
  end

  context "should return correct dose for '3 Mg'" do
    dose = ParseDose.from_string('3 Mg')
    specify { expect(dose.qty).to eq 3.0 }
    specify { expect(dose.unit).to eq 'Mg' }
  end

  context "should return correct dose for 'ml'" do
    dose = ParseDose.from_string('ml')
    specify { expect(dose.qty).to eq 1.0 }
    specify { expect(dose.unit).to eq 'ml' }
  end

  context "should return correct dose for '123'" do
    dose = ParseDose.from_string("123")
    specify { expect(dose.qty).to eq 123 }
    specify { expect(dose.unit).to eq nil }
  end

  context "should return correct dose for '123.45'" do
    dose = ParseDose.from_string("123.45")
    specify { expect(dose.qty).to eq 123.45 }
    specify { expect(dose.unit).to eq nil }
  end

  context "should return correct dose for '2 mg'" do
    dose = ParseDose.from_string('2 mg')
    specify { expect(dose.qty).to eq 2.0 }
    specify { expect(dose.unit).to eq 'mg' }
  end

  context "should return correct dose for '0.3 ml'" do
    dose = ParseDose.from_string('0.3 ml')
    specify { expect(dose.qty).to eq 0.3 }
    specify { expect(dose.unit).to eq 'ml' }
  end

  context "should return correct dose for '0.01 mg/ml'" do
    dose = ParseDose.from_string('0.01 mg/ml')
    specify { expect(dose.qty).to eq 0.01 }
    specify { expect(dose.unit).to eq 'mg/ml' }
  end

  context "should return correct dose for '3 mg/ml'" do
    dose = ParseDose.from_string('3 mg/ml')
    specify { expect(dose.qty).to eq 3.0 }
    specify { expect(dose.unit).to eq 'mg/ml' }
  end

  context "should return correct dose for '7900 U.I.'" do
    string = "7900 U.I."
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 7900 }
    specify { expect(dose.unit).to eq 'U.I.' }
  end

  context "should return correct dose for '20 %'" do
    string = "20 %"
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 20 }
    specify { expect(dose.unit).to eq '%' }
  end
  context "should return correct dose for '59.5 % V/V'" do
    string = "59.5 % V/V"
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 59.5}
    specify { expect(dose.unit).to eq '% V/V' }
  end
end

  context "should return correct dose for '80-120 g'" do
    string = "80-120 g"
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 80 }
    specify { expect(dose.unit).to eq 'g' }
  end if RunFailingSpec

end if RunDoseTests


describe ParseSubstance do
    context "should return correct composition for 'DER: 6:1'" do
      source =
# "berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V"
"DER: 6:1"
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 6 }
      specify { expect(composition.substances.first.name).to eq 'Pollinis Allergeni Extractum (phleum Pratense)' }
    end if RunMostImportantParserTests

    context "should return correct composition for 'excipiens ad emulsionem'" do
      source =
'excipiens ad emulsionem pro 1 g"'
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 0 }
      # specify { expect(composition.substances.first.name).to eq 'Pollinis Allergeni Extractum (phleum Pratense)' }
    end

    context "should return correct composition for containing Histamin Equivalent Pric. (e.g IKSNR 58566)" do
      # 58566 1   Soluprick SQ Phleum pratense, Lösung
      source =
'pollinis allergeni extractum (Phleum pratense) 10 U., natrii chloridum, phenolum, glycerolum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml, U = Histamin Equivalent Prick.'
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 6 }
      specify { expect(composition.substances.first.name).to eq 'Pollinis Allergeni Extractum (phleum Pratense)' }
    end if TryRun

    context "should return correct composition for containing 'ad pulverem'" do
      source =
#"acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %, aluminium, aluminii hydroxidum hydricum ad adsorptionem, natrii chloridum, conserv.: phenolum 4.0 mg, aqua q.s. ad suspensionem pro 1 ml.\n"
# "dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %" # okay
# "acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %"
#"acari allergeni extractum 5000 U.: dermatophagoides farinae"
# "acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %,"
'A): acari allergeni extractum 50 U.: dermatophagoides farinae 50'
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 2 }
      specify { expect(composition.substances.first.more_info).to eq "acari allergeni extractum 5000 U." }
      specify { expect(composition.substances.first.name).to eq 'Dermatophagoides Farinae' }
      specify { expect(composition.substances.last.name).to eq  'Dermatophagoides Pteronyssinus' }
      specify { expect(composition.substances.last.more_info).to eq nil }
    end if TryRun

    context "should return correct composition for containing 'ad pulverem'" do
      source =
"absinthii herba 15 %, anisi fructus 15 %, carvi fructus 15 %, foeniculi fructus 15 %, iuniperi pseudofructus 10 %, millefolii herba 15 %, pimpinellae radix 15 % ad pulverem.\n"
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 7 }
      specify { expect(composition.substances.first.name).to eq 'Absinthii Herba' }
    end

    context "should return correct composition for containing 'excipiens ad globulos" do
      source = "abrus precatorius C6, aconitum napellus C6, atropa belladonna C6, calendula officinalis C6, chelidonium majus C6, viburnum opulus C6 ana partes, excipiens ad globulos.\n"
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 6 }
      specify { expect(composition.substances.first.name).to eq 'Abrus Precatorius C6' }
    end

    context "should return correct composition for containing 'arom.: E 104'" do
      source = 'gentianae radix 12 mg, primulae flos 36 mg, rumicis acetosae herba 36 mg, sambuci flos 36 mg, verbenae herba 36 mg, color.: E 104 et E 132, excipiens pro compresso obducto.'
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 8 }
      specify { expect(composition.substances.first.name).to eq 'Gentianae Radix' }
    end

   context "should return correct composition for containing 'color.: E 160(a)'" do
      source = 'color.: E 160(a), E 171'
      composition = ParseComposition.from_string(source)
      specify { expect(composition.source).to eq source }
      specify { expect(composition.substances.size).to eq 2 }
      specify { expect(composition.substances.first.name).to eq 'E 160' }
      specify { expect(composition.substances.last.name).to eq 'E 171' }
    end


  if RunMostImportantParserTests

    context "should return correct substance for 'Xenonum(133-xe) 74 -740 Mb'" do
      string = "Xenonum(133-Xe) 74 -740 MBq"
      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'Xenonum(133-xe)' }
      specify { expect(substance.qty).to eq 74 }
      specify { expect(substance.unit).to eq 'MBq' }
    end

    context "should parse a Praeparatio with a label/galenic form?" do
      source = "Praeparatio cryodesiccata: pollinis allergeni extractum 25'000 U.: urtica dioica"
      composition = ParseComposition.from_string(source)
      substance = composition.substances.first
      specify { expect(substance.name).to eq 'Pollinis Allergeni Extractum' }
      specify { expect(substance.description).to eq 'Praeparatio cryodesiccata' }
    end

    context "should return correct substance for equis F(ab')2" do
      string = "viperis antitoxinum equis F(ab')2"
      composition = ParseComposition.from_string(string)
      substance = composition.substances.first
      specify { expect(substance.name).to eq "Viperis Antitoxinum Equis F_ab_2" }
    end

    context "should return correct substance for with two et substances corresp" do
      string = "viperis antitoxinum equis F(ab')2 corresp. Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50 mus et Vipera ammodytes > 1000 LD50 mus"
      composition = ParseComposition.from_string(string)
      substance = composition.substances.last
      specify { expect(substance.name).to eq "Vipera Ammodytes > 1000 Ld50 Mus" }
    end

    context "should return correct substance for 'excipiens ad solutionem pro 3 ml corresp. 50 µg'" do
      string = "excipiens ad solutionem pro 3 ml corresp. 50 µg"
      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'Excipiens' }unless SkipExcipiensTest

      specify { expect(substance.qty).to eq 3.0} unless SkipExcipiensTest
      specify { expect(substance.unit).to eq 'ml' } unless SkipExcipiensTest
      specify { expect(substance.cdose.qty).to eq 50.0}
      specify { expect(substance.cdose.unit).to eq 'µg' }
    end

      context "should return correct substance for 'pyrazinamidum 500 mg'" do
        string = "pyrazinamidum 500 mg"
        SubstanceTransformer.clear_substances
        substance = ParseSubstance.from_string(string)

        specify { expect(substance.name).to eq 'Pyrazinamidum' }
        specify { expect(substance.qty).to eq 500.0 }
        specify { expect(substance.unit).to eq 'mg' }
      end

    context "should return correct substance for 'excipiens ad pulverem pro 1000 mg'" do
      string = "excipiens ad pulverem pro 1000 mg"
      SubstanceTransformer.clear_substances
      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'Excipiens' } unless SkipExcipiensTest
      specify { expect(substance.qty).to eq 1000.0 }
      specify { expect(substance.unit).to eq 'mg' }
    end

    context "should return correct substance for given with et and corresp. (IKSNR 11879)" do
      string = "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg"

      composition = ParseComposition.from_string(string)
      specify { expect(composition.substances.size).to eq 2 }
      calcii = composition.substances.find{ |x| /calcii/i.match(x.name) }
      pentahydricus = composition.substances.find{ |x| /pentahydricus/i.match(x.name) }
      anhydricus    = composition.substances.find{ |x| /anhydricus/i.match(x.name) }
      specify { expect(pentahydricus.name).to eq 'Calcii Lactas Pentahydricus' }
      specify { expect(pentahydricus.qty).to eq 25.0}
      specify { expect(pentahydricus.unit).to eq 'mg' }
      specify { expect(anhydricus.name).to eq 'Calcii Hydrogenophosphas Anhydricus' }
      specify { expect(anhydricus.qty).to eq 300.0 }
      specify { expect(anhydricus.unit).to eq 'mg' }
      specify { expect(anhydricus.chemical_substance.name).to eq 'Calcium' }
      specify { expect(anhydricus.chemical_substance.qty).to eq 100.0 }
      specify { expect(anhydricus.chemical_substance.unit).to eq 'mg' }
    end

    context "should return correct substance for 'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V'" do
      string = "excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
      composition = ParseComposition.from_string(string)
      substance = composition.substances.first
      # TODO: what should we report here? dose = pro 1 ml or 59.5 % V/V, chemical_substance = ethanolum?
      # or does it only make sense as part of a composition?
      # pp substance; binding.pry
      specify { expect(substance.name).to eq 'Ethanolum' }
      specify { expect(substance.cdose).to eq nil }
      specify { expect(substance.qty).to eq 59.5}
      specify { expect(substance.unit).to eq '% V/V' }
    end

    context "should return correct substances for Nutriflex IKSNR 42847" do
      string = "I) Glucoselösung: glucosum anhydricum 240 g ut glucosum monohydricum, calcii chloridum dihydricum 600 mg, acidum citricum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml.
.
II) Aminosäurelösung: aminoacida: isoleucinum 4.11 g, leucinum 5.48 g, lysinum anhydricum 3.98 g ut lysinum monohydricum, methioninum 3.42 g, phenylalaninum 6.15 g, threoninum 3.18 g, tryptophanum 1 g, valinum 4.54 g, argininum 4.73 g, histidinum 2.19 g ut histidini hydrochloridum monohydricum, alaninum 8.49 g, acidum asparticum 2.63 g, acidum glutamicum 6.14 g, glycinum 2.89 g, prolinum 5.95 g, serinum 5.25 g, mineralia: magnesii acetas tetrahydricus 1.08 g, natrii acetas trihydricus 1.63 g, kalii dihydrogenophosphas 2 g, kalii hydroxidum 620 mg, natrii hydroxidum 1.14 g, acidum citricum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml.
.
I) et II) corresp.: aminoacida 70 g, nitrogenia 10 g, natrium 40.5 mmol, kalium 25.7 mmol, calcium 4.1 mmol, magnesium 5 mmol, chloridum 49.5 mmol, phosphas 14.7 mmol, acetas 22 mmol, in solutione recenter reconstituta 1000 ml.
Corresp. 5190 kJ pro 1 l."
      line_1 = "I) Glucoselösung: glucosum anhydricum 240 g ut glucosum monohydricum, calcii chloridum dihydricum 600 mg, acidum citricum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml."
      line_2 = "."
      line_3 = "II) Aminosäurelösung: aminoacida: isoleucinum 4.11 g, leucinum 5.48 g, lysinum anhydricum 3.98 g ut lysinum monohydricum, methioninum 3.42 g, phenylalaninum 6.15 g, threoninum 3.18 g, tryptophanum 1 g, valinum 4.54 g, argininum 4.73 g, histidinum 2.19 g ut histidini hydrochloridum monohydricum, alaninum 8.49 g, acidum asparticum 2.63 g, acidum glutamicum 6.14 g, glycinum 2.89 g, prolinum 5.95 g, serinum 5.25 g, mineralia: magnesii acetas tetrahydricus 1.08 g, natrii acetas trihydricus 1.63 g, kalii dihydrogenophosphas 2 g, kalii hydroxidum 620 mg, natrii hydroxidum 1.14 g, acidum citricum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml."
      line_4 = "."
      line_5 = "I) et II) corresp.: aminoacida 70 g, nitrogenia 10 g, natrium 40.5 mmol, kalium 25.7 mmol, calcium 4.1 mmol, magnesium 5 mmol, chloridum 49.5 mmol, phosphas 14.7 mmol, acetas 22 mmol, in solutione recenter reconstituta 1000 ml."
      line_6 = "Corresp. 5190 kJ pro 1 l."
      tst = 'glucosum anhydricum 240 g ut glucosum monohydricum, calcii chloridum dihydricum 600 mg, acidum citricum monohydricum'
      tst2 = 'glucosum anhydricum 240 g ut glucosum monohydricum, calcii chloridum dihydricum 600 mg'
      tst_ut = 'glucosum anhydricum 240 g ut glucosum monohydricum'
      # binding.pry
      composition = ParseComposition.from_string(line_2)
      line_3 = "II) Aminosäurelösung: aminoacida: isoleucinum 4.11 g, leucinum 5.48 g, lysinum anhydricum 3.98 g ut lysinum monohydricum, methioninum 3.42 g, phenylalaninum 6.15 g, threoninum 3.18 g, tryptophanum 1 g, valinum 4.54 g, argininum 4.73 g, histidinum 2.19 g ut histidini hydrochloridum monohydricum, alaninum 8.49 g, acidum asparticum 2.63 g, acidum glutamicum 6.14 g, glycinum 2.89 g, prolinum 5.95 g, serinum 5.25 g, mineralia: magnesii acetas tetrahydricus 1.08 g, natrii acetas trihydricus 1.63 g, kalii dihydrogenophosphas 2 g, kalii hydroxidum 620 mg, natrii hydroxidum 1.14 g, acidum citricum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml."
      line_3 = "II) Aminosäurelösung: aminoacida: isoleucinum 4.11 g, leucinum 5.48 g"
      line_3 = "aminoacida: isoleucinum 4.11 g, leucinum 5.48 g"
      composition = ParseComposition.from_string(line_3)
      composition = ParseComposition.from_string(line_1)

      composition = ParseComposition.from_string(line_1)
      specify { expect(composition.substances.size).to eq 4}
      specify { expect(composition.label).to eq 'I' }
      specify { expect(composition.label_description).to eq 'Glucoselösung' }
      dihydricum = composition.substances.find{ |x| /dihydricum/i.match(x.name) }
      monohydricum = composition.substances.find{ |x| /monohydricum/i.match(x.name) }

      specify { expect(dihydricum.name).to eq 'Calcii Chloridum Dihydricum' }
      specify { expect(dihydricum.chemical_substance).to eq  nil }
      specify { expect(dihydricum.qty).to eq 600.0}
      specify { expect(dihydricum.unit).to eq 'mg' }

      specify { expect(monohydricum.name).to eq 'Acidum Citricum Monohydricum' }
      specify { expect(monohydricum.chemical_substance).to eq nil }
      specify { expect(monohydricum.cdose).to eq nil }
      specify { expect(monohydricum.qty).to eq nil}
      specify { expect(monohydricum.unit).to eq nil }
    end

    context "should return correct substance for 9,11-linolicum " do
      substance = nil; composition = nil
      [ "9,11-linolicum",
        "9,11-linolicum 3.25 mg"
      ].each {
          |string|
          substance = ParseSubstance.from_string(string)
          specify { expect(substance.name).to eq '9,11-linolicum' }
          specify { expect(substance.chemical_substance).to eq nil }
          SubstanceTransformer.clear_substances
          composition = ParseComposition.from_string(string)
        }

      specify { expect(substance.qty).to eq 3.25}
      specify { expect(substance.unit).to eq 'mg' }
    end

    context "should return correct substance for 'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V'" do
      string = "excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"

      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'Excipiens' } unless SkipExcipiensTest
      specify { expect(substance.chemical_substance.name).to eq 'Ethanolum' } unless SkipExcipiensTest
      specify { expect(substance.cdose.to_s).to eq ParseDose.new('59.5', '% V/V').to_s } unless SkipExcipiensTest
      specify { expect(substance.qty).to eq 1.0} unless SkipExcipiensTest
      specify { expect(substance.unit).to eq 'ml' } unless SkipExcipiensTest
    end

    context "should handle aqua ad iniectabilia" do
      string = "aqua ad iniectabilia q.s. ad solutionem pro 5 ml"
      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'aqua ad iniectabilia q.s. ad solutionem' }
      specify { expect(substance.chemical_substance).to eq nil }
      specify { expect(substance.qty).to eq 5.0}
      specify { expect(substance.unit).to eq 'ml' }
    end

    context "should return correct substance ut (IKSNR 44744)" do
      string = "zuclopenthixolum 2 mg ut zuclopenthixoli dihydrochloridum, excipiens pro compresso obducto."
      composition = ParseComposition.from_string(string)
      specify { expect(composition.substances.size).to eq 2}
      specify { expect(composition.substances.first.name).to eq 'Zuclopenthixolum' }
      specify { expect(composition.substances.first.qty).to eq 2.0}
      specify { expect(composition.substances.first.salts.size).to eq 1}
      salt = composition.substances.first.salts.first
      specify { expect(salt.name).to eq 'Zuclopenthixoli Dihydrochloridum' }
      specify { expect(salt.qty).to eq nil}
      specify { expect(salt.unit).to eq nil }
    end

    context "should return correct substance for given with et (IKSNR 11879)" do
      string = "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg"
      composition = ParseComposition.from_string(string)
      specify { expect(composition.substances.size).to eq 2 }
      pentahydricus = composition.substances.find{ |x| /pentahydricus/i.match(x.name) }
      anhydricus    = composition.substances.find{ |x| /anhydricus/i.match(x.name) }
      specify { expect(pentahydricus.name).to eq 'Calcii Lactas Pentahydricus' }
      specify { expect(pentahydricus.qty).to eq 25.0}
      specify { expect(pentahydricus.unit).to eq 'mg' }
      specify { expect(anhydricus.name).to eq 'Calcii Hydrogenophosphas Anhydricus' }
      specify { expect(anhydricus.qty).to eq 300.0 }
      specify { expect(anhydricus.unit).to eq 'mg' }
    end

    context "should parse a complex composition" do
      source = 'globulina equina (immunisé avec coeur) 8 mg'
      source = 'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg'
    end

    context "should return correct substance for 'Xenonum(133-xe) 74 -740 Mb'" do
      string = "Xenonum(133-Xe) 74 -740 MBq"
      substance = ParseSubstance.from_string(string)
      specify { expect(substance.name).to eq 'Xenonum(133-xe)' }
      specify { expect(substance.qty).to eq 74 }
      specify { expect(substance.unit).to eq 'MBq' }
    end

  context "should return correct substance for 'pyrazinamidum'" do
    string = "pyrazinamidum"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Pyrazinamidum' }
    specify { expect(substance.qty).to eq nil }
    specify { expect(substance.unit).to eq nil }
  end

  context "should return correct substance for 'E 120'" do
    string = "E 120"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq string }
    specify { expect(substance.qty).to eq nil }
    specify { expect(substance.unit).to eq nil }
  end

  context "should return correct substance for 'retinoli palmitas 7900 U.I.'" do
    string = "retinoli palmitas 7900 U.I."
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Retinoli Palmitas' }
    specify { expect(substance.qty).to eq 7900.0}
    specify { expect(substance.unit).to eq 'U.I.' }
  end

  context "should return correct substance for 'toxoidum pertussis 8 µg'" do
    string = "toxoidum pertussis 8 µg"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Toxoidum Pertussis' }
    specify { expect(substance.qty).to eq 8.0}
    specify { expect(substance.unit).to eq 'µg' }
  end

  context "should return correct substance for 'aqua q.s. ad suspensionem pro 0.5 ml'" do
    string = "aqua q.s. ad suspensionem pro 0.5 ml"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'aqua q.s. ad suspensionem' }
    specify { expect(substance.qty).to eq 0.5}
    specify { expect(substance.unit).to eq 'ml' }
  end if RunExcipiensTest

 end

end

describe ParseComposition do
    context "should return correct substance Rote Filmtablett 54819 Beriplast" do
      string = "A) Rote Filmtablette: estradiolum 1 mg ut estradiolum hemihydricum, excipiens pro compresso obducto"
      string = "estradiolum 1 mg ut estradiolum hemihydricum, excipiens pro compresso obducto"
      composition = ParseComposition.from_string(string)
      substance = composition.substances.first
      specify { expect(composition.substances.size).to eq 2 }
      specify { expect(composition.substances.last.name).to eq 'Obducto' }
      specify { expect(substance.name).to eq 'Estradiolum' }
      specify { expect(composition.substances.first.salts.first.name).to eq 'Estradiolum Hemihydricum' }
      specify { expect(substance.cdose.to_s).to eq "" }
      specify { expect(substance.qty).to eq 1.0}
      specify { expect(substance.unit).to eq 'mg' }
    end

  context "should return correct composition for containing ut IKSNR 613" do
    source = 'aluminium ut aluminii hydroxidum hydricum ad adsorptionem'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.substances.size).to eq 1 }
    specify { expect(composition.substances.first.name).to eq 'Aluminium' }
    specify { expect(composition.substances.first.salts.first.name).to eq 'Aluminii Hydroxidum Hydricum Ad Adsorptionem' }
  end

  context "should return correct substance for 'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg'" do
    string = "toxoidum pertussis 25 µg et haemagglutininum filamentosum 15 µg"
    composition = ParseComposition.from_string(string)
    toxoidum = composition.substances.first
    specify { expect(toxoidum.name).to eq 'Toxoidum Pertussis' }
    specify { expect(toxoidum.qty).to eq 25.0}
    specify { expect(toxoidum.unit).to eq 'µg' }
    specify { expect(toxoidum.chemical_substance).to eq nil }
    haemagglutininum = composition.substances.last
    specify { expect(haemagglutininum.name).to eq 'Haemagglutininum Filamentosum' }
    specify { expect(haemagglutininum.qty).to eq 15.0}
    specify { expect(haemagglutininum.unit).to eq 'µg' }
  end

if RunSpecificTests
  context "should return correct composition for containing parenthesis in substance name abd 40 U. (e.g IKSNR 613)" do
    source = 'virus poliomyelitis typus 1 inactivatum (D-Antigen) 40 U.'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.substances.size).to eq 1 }
    specify { expect(composition.substances.first.name).to eq 'Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)' }
  end

  context "should return correct composition for containing parenthesis in substance name (e.g IKSNR 613)" do
    source = 'virus poliomyelitis typus inactivatum (D-Antigen)'
    source = 'virus poliomyelitis typus 1 inactivatum (d-antigen)'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.substances.size).to eq 1 }
    specify { expect(composition.substances.first.name).to eq 'Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)' }
  end

  context "should return correct composition for containing residui (e.g IKSNR 613)" do
    source = 'residui: neomycinum, streptomycinum'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.substances.size).to eq 2 }
    specify { expect(composition.substances.first.more_info).to eq 'residui' }
    specify { expect(composition.substances.first.name).to eq 'Neomycinum' }
    specify { expect(composition.substances.last.name).to  eq 'Streptomycinum' }
  end

  context "should return correct composition for 'conserv.: E 217, E 219' IKSNR 613" do
#    source = 'I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I., toxoidum tetani 40 U.I., toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg, virus poliomyelitis typus 1 inactivatum (D-Antigen) 40 U., virus poliomyelitis typus 2 inactivatum (D-Antigen) 8 U., virus poliomyelitis typus 3 inactivatum (D-Antigen) 32 U., aluminium ut aluminii hydroxidum hydricum ad adsorptionem, formaldehydum 10 µg, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum, streptomycinum, polymyxini B sulfas, medium199, aqua q.s. ad suspensionem pro 0.5 ml.'
    source =
'I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I., toxoidum tetani 40 U.I., toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg, virus poliomyelitis typus 1 inactivatum (D-Antigen) 40 U., virus poliomyelitis typus 2 inactivatum (D-Antigen) 8 U., virus poliomyelitis typus 3 inactivatum (D-Antigen) 32 U., aluminium ut aluminii hydroxidum hydricum ad adsorptionem, formaldehydum 10 µg, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum, streptomycinum, polymyxini B sulfas, medium199, aqua q.s. ad suspensionem pro 0.5 ml.'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq 'I' }
  end

  context "should return correct composition for 'conserv.: E 217, E 219'" do
    source = 'conserv.: E 217, E 219'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
  end

  context "should parse more complicated example" do
    source =
"I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I., toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg"
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }

    specify { expect(composition.label).to eq 'I' }
    specify { expect(composition.label_description).to eq 'DTPa-IPV-Komponente (Suspension)' }

    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }

    toxoidum = composition.substances.find{|x| /toxoidum diphther/i.match(x.name)}
    specify { expect(toxoidum.name).to eq 'Toxoidum Diphtheriae' }
    specify { expect(toxoidum.qty).to eq 30 }
    specify { expect(toxoidum.unit).to eq 'U.I.' }

    haema = composition.substances.find{|x| /Haemagglutininum/i.match(x.name)}
    specify { expect(haema.name).to eq 'Haemagglutininum Filamentosum' }
    specify { expect(haema.qty).to eq 25 }
    specify { expect(haema.unit).to eq 'µg' }
  end

  context "should return correct composition for 'minoxidilum'" do
    source = 'minoxidilum 2.5 mg, pyrazinamidum 500 mg'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }
    substance = composition.substances.first
    specify { expect(substance.name).to eq 'Minoxidilum' }
    specify { expect(substance.qty).to eq 2.5 }
    specify { expect(substance.unit).to eq 'mg' }
  end

  context "should return correct composition for 'terra'" do
    source = 'terra'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }
    specify { expect( composition.substances.first.name).to eq "Terra" }
  end

  context "should return correct composition for 'terra silicea spec..'" do
    source = 'terra silicea spec..'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source}
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }
    specify { expect( composition.substances.first.name).to eq "Terra Silicea Spec" }
  end

  context "should return correct composition for 'minoxidilum'" do
    source = 'minoxidilum 2.5 mg'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }
    substance = composition.substances.first
    specify { expect(substance.name).to eq 'Minoxidilum' }
    specify { expect(substance.qty).to eq 2.5 }
    specify { expect(substance.unit).to eq 'mg' }
  end

  context "should return correct composition for 'minoxidilum'" do
    source = 'minoxidilum'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }
    substance = composition.substances.first
    specify { expect(substance.name).to eq 'Minoxidilum' }
    specify { expect(substance.qty).to eq nil }
    specify { expect(substance.unit).to eq nil }
  end

  context "should return correct composition for 'minoxidilum excipiens'" do
    source = 'minoxidilum 2.5 mg, excipiens pro compresso.'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
    specify { expect(composition.label).to eq nil }
    specify { expect(composition.label_description).to eq nil }
    specify { expect(composition.galenic_form).to eq nil }
    specify { expect(composition.route_of_administration).to eq nil }

    substance = composition.substances.first
    specify { expect(substance.name).to eq 'Minoxidilum' }
    specify { expect(substance.qty).to eq 2.5 }
    specify { expect(substance.unit).to eq 'mg' }
    skip 'what is the correct name for excipiens?'# { expect(composition.substances.last.name).to eq 'Excipiens Pro Compresso' }
  end

end

  run_composition_tests(composition_tests) if RunCompositionExamples
end

describe HandleSwissmedicErrors do
  context 'should handle fixes' do
    replacement = '\1, \2'
    pattern_replacement  = { /(sulfuris D6\s[^\s]+\smg)\s([^,]+)/ => replacement }
    test_string = 'sulfuris D6 2,2 mg hypericum perforatum D2 0,66'
    expected    = 'sulfuris D6 2,2 mg, hypericum perforatum D2 0,66'
    handler = HandleSwissmedicErrors.new(pattern_replacement )
    result = handler.apply_fixes(test_string)
    specify { expect(result).to eq expected }
    specify { expect(handler.report.size).to eq 2 }
    specify { expect(/report/i.match(handler.report[0]).class).to eq MatchData }
    specify { expect(handler.report[1].index(replacement).class).to eq Fixnum }
  end

  context 'should be used when calling ParseComposition' do
    replacement = '\1, \2'
    test_string = 'sulfuris D6 2,2 mg hypericum perforatum D2 0,66'
    report = ParseComposition.reset
    composition = ParseComposition.from_string(test_string).clone
    report = ParseComposition.report
    specify { expect(composition.substances.size).to eq 2 }
    specify { expect(composition.substances.first.name).to eq 'Sulfuris D6' }
    specify { expect(composition.substances.last.name).to eq 'Hypericum Perforatum D2' }
    specify { expect(/report/i.match(report[0]).class).to eq MatchData }
    specify { expect(report[1].index(replacement).class).to eq Fixnum }
  end

end if RunSpecificTests

describe ParseComposition do
  context "should parse a complex composition" do
    start_time = Time.now
    filename = File.expand_path("#{__FILE__}/../data/compositions.txt")
    specify { expect( File.exists?(filename)).to eq true }
    inhalt = IO.readlines(filename)
    nr = 0
    @nrErrors = 0
    inhalt.each{
      |line|
      nr += 1
      next if line.length < 5
      puts "#{File.basename(filename)}:#{nr} #{@nrErrors} errors: #{line}"
      begin
        composition = ParseComposition.from_string line
    rescue Parslet::ParseFailed
      @nrErrors += 1

      puts "  error #{@nrErrors} in line #{File.basename(filename)}:#{nr} XX: #{line}"
      puts line
     # binding.pry if /mannitolum 40 mg pro dosi/.match(line)
#      binding.pry if nr > 300
    end
    }
    at_exit { puts "Testing whether #{nr} composition lines can be parsed. Found #{@nrErrors} errors in #{(Time.now - start_time).to_i} seconds" }

  end  if RunAllCompositionsTests
end
