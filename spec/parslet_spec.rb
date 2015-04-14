# encoding: utf-8

begin
require 'pry'
rescue LoadError
end
require 'pp'
require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'

RunAllTests = true
RunFailingSpec = false
RunAllCompositionsTests = true

def run_composition_tests(strings)
  strings.each {
    |source|
    context "should parse #{source}" do
      composition = ParseComposition.from_string(source)
      # pp composition; binding.pry
      specify { expect(composition.source).to eq source }
    end
  }
end

def run_substance_tests(hash_string_to_name)
  hash_string_to_name.each{ |string, name|
    context "should consume #{string}" do
      substance = ParseSubstance.from_string(string)
      pp substance
      # pp substance; binding.pry
      puts "SOLL: "+ substance.name unless name.eql? substance.name
      specify { expect(substance.class).to eq ParseSubstance }
      specify { expect(substance.name).to eq name } if substance.is_a?(ParseSubstance)
    end
  }
end

describe ParseDose do

if RunAllTests

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

end


describe ParseSubstance do
   excipiens_tests = {

    'excipiens pro compresso' => 'Pro Compresso',
    'excipiens ad pulverem' => 'Ad Pulverem',
    'excipiens ad pulverem pro charta' => 'Ad Pulverem Pro Charta',
    'excipiens ad pulverem pro 1000 mg' => 'Ad Pulverem Pro',
    'excipiens ad solutionem pro 2 ml' => 'Ad Solutionem Pro',
    'excipiens ad pulverem corresp. suspensio reconstituta' => 'Ad Pulverem Corresp. Suspensio Reconstituta',
    'excipiens ad pulverem corresp. suspensio reconstituta 1 ml' => 'Ad Pulverem Corresp. Suspensio Reconstituta',

    'excipiens ad solutionem pro 3 ml corresp. 50 µg' => 'Excipiens Ad Solutionem Pro 3 Ml Corresp. 50 µg',
    'excipiens ad solutionem pro 4 ml corresp. 50 µg pro dosi' => 'Excipiens Ad Solutionem Pro 4 Ml Corresp. 50 µg Pro Dosi',
    'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V' => 'Excipiens Ad Solutionem Pro 1 Ml Corresp. Ethanolum 59.5 % V/v',

    }

   tests = {
    'retinoli 7900' => "Retinoli",
    'excipiens ad solutionem pro 1 ml' => "Ad Solutionem Pro",
    'ginseng extractum corresp. ginsenosidea 3.4 mg' => 'Ginseng Extractum Corresp. Ginsenosidea',
    'yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt' => 'Yttrii(90-y) Chloridum Zum Kalibrierungszeitpunkt',
    'yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt 1850 MBq' => 'Yttrii(90-y) Chloridum Zum Kalibrierungszeitpunkt',
    "U = Histamin Equivalent Prick" => 'U = Histamin Equivalent Prick',
    "acari allergeni extractum 50'000 U.:" => 'Acari Allergeni Extractum',
    "acari allergeni extractum (acarus siro) 50'000 U." => 'Acari Allergeni Extractum (acarus Siro)',
    'acari allergeni extractum 5000 U.:' => 'Acari Allergeni Extractum',
    'acari allergeni extractum 5000 U.: dermatophagoides farinae' => 'Acari Allergeni Extractum',
    'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %' => 'Acari Allergeni Extractum',
    'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %  et dermatophagoides pteronyssinus 50 %' => 'Acari Allergeni Extractum',
    'absinthii herba 1.2 g pro charta' => "Absinthii Herba",
    '1-Chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine 75 mg' => '1-chloro-2,2,5,5-tetramethyl-4-oxoimidazolidine',
    'xenonum(133-Xe) 74 -740 MBq' => 'Xenonum(133-xe)',
    "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg" => "Osseinum-hydroxyapatit",
    "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Lactas Pentahydricus',
    "calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Hydrogenophosphas Anhydricus',
    "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
    "calcii gluconas corresp. calcium 100 mg" => 'Calcii Gluconas Corresp. Calcium',
    "calcii gluconas 100 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
    "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg" => 'Calcii Gluconas',
    'pimpinellae radix 15 % ad pulverem' => 'Pimpinellae Radix',
    'antiox.: E 321' => 'E 321',
    'color.: E 160(a)' => 'E 160', # TODO: or E 160(a) ??
    'E 160(a)' => 'E 160(a)',
    'ethanolum 70-78 % V/V' => "Ethanolum",
    'procainum 10 mg ut procaini hydrochloridum' => 'Procaini Hydrochloridum',
    'DER: 6-8:1' => 'Der: 6-8:1',
    'DER: 1:4' => 'Der: 1:4',
    'DER: 3.5:1' => 'Der: 3.5:1',
    "ethanolum 59.5 % V/V" => 'Ethanolum',
    "corresp. ethanolum 59.5 % V/V" => 'Corresp. Ethanolum',
    'sennae folium 75 % corresp. hydroxyanthracenae 2.7 %' => 'Sennae Folium',
    'retinoli' => 'Retinoli',
    'benzoe 40 ml' => 'Benzoe',
    'benzoe 40 guttae' => 'Benzoe',
    'streptococcus pneumoniae 12 %' => 'Streptococcus Pneumoniae',
    'X179A' => 'X179a',
    'X-179A' => 'X-179a',
    'virus NYMC X-179A' => 'Virus Nymc X-179a',
    'DTPa-IPV-Komponente' => 'Dtpa-ipv-komponente',
    'A/California/7/2009 virus NYMC X-179A' => 'A/california/7/2009 Virus Nymc X-179a',
    "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg" => 'Haemagglutininum Influenzae B (virus-stamm B/massachusetts/2/2012-like: B/massachusetts/2/2012)',
    "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum",
    "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80",
    "aqua ad iniectabilia ad solutionem pro 4 ml" => "Aqua Ad Iniectabilia Ad Solutionem Pro",
    "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80, Aqua Ad Iniectabilia Ad Solutionem Pro 4 Ml",
    "Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml" => "Vipera Aspis > 1000 Ld50 Mus Et Vipera Berus > 500 Ld50, Natrii Chloridum, Polysorbatum 80, Aqua Ad Iniectabilia Q.s. Ad Solutionem Pro 4 Ml",
    'haemagglutininum influenzae A reassortant (Virus-Stamm virus NYMC X-179A) 15 µg' => 'Haemagglutininum Influenzae A Reassortant (virus-stamm Virus Nymc X-179a)',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009  xx) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009  Xx)',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) xx) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) Xx)',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) ) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) )',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1) like reassortant virus NYMC X-179A)'  => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1) Like Reassortant Virus Nymc X-179a)',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A)' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1)-like: Reassortant Virus Nymc X-179a)',
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg' => 'Haemagglutininum Influenzae A (h1n1) (virus-stamm A/california/7/2009 (h1n1)-like: Reassortant Virus Nymc X-179a)',
    "globulina equina'" => "Globulina Equina'",
    "globulina equina (immunisé)" => 'Globulina Equina (immunisé)',
    "globulina equina (immunisé')" => "Globulina Equina (immunisé')",
    "antitoxinum equis Fab'" => "Antitoxinum Equis Fab'",
    "antitoxinum equis Fab'x" => "Antitoxinum Equis Fab'x",
    "viperis antitoxinum equis F(ab)" => "Viperis Antitoxinum Equis F(ab)",
    "viperis antitoxinum equis F(ab')" => "Viperis Antitoxinum Equis F(ab')",
    "viperis antitoxinum equis F(ab')2" => "Viperis Antitoxinum Equis F(ab')2",
    'globulina equina (immunisé)' => 'Globulina Equina (immunisé)',
    'globulina equina (immunisé, tissu)' => 'Globulina Equina (immunisé, Tissu)',
    'globulina equina (immunisé de, tissu)' => "Globulina Equina (immunisé De, Tissu)",
    'globulina equina (immunisé, tissu pulmonaire)' => 'Globulina Equina (immunisé, Tissu Pulmonaire)',
    'globulina equina (immunisé de, tissu pulmonaire)' => 'Globulina Equina (immunisé De, Tissu Pulmonaire)',
    'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins)' => 'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)',
    'retinoli 7900 U.I.' => 'Retinoli',
    'retinoli palmitas 7900 U.I.' => 'Retinoli Palmitas',
    'virus' => 'Virus',
    'E 270' => 'E 270',
    'moelle épinière' => 'Moelle épinière',
    'DTPa-IPV-Komponente (Suspension)' => 'Dtpa-ipv-komponente (suspension)',
    'virus poliomyelitis' => 'Virus Poliomyelitis',
    'virus poliomyelitis typus inactivatum D-Antigen' => 'Virus Poliomyelitis Typus Inactivatum D-antigen',
    'virus poliomyelitis typus inactivatum (D-Antigen)' => 'Virus Poliomyelitis Typus Inactivatum (d-antigen)',
    'virus poliomyelitis typus 1 inactivatum D-Antigen' => 'Virus Poliomyelitis Typus 1 Inactivatum D-antigen',
    'virus poliomyelitis typus 1 inactivatum (D-Antigen)' => 'Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)',
    'virus poliomyelitis typus inactivatum (D-Antigen) 2 mg' => 'Virus Poliomyelitis Typus Inactivatum (d-antigen)',
    'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg' => 'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)',
   }
  failing_tests = {
    "xylometazolini hydrochloridum 0.5 mg, natrii hyaluronas, conserv.: E 217, E 219, natrii dehydroacetas, excipiens ad solutionem pro 1 ml corresp. 50 µg pro dosi" => "line #{__LINE__}",
    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like ) 15 µg' => "line #{__LINE__}",
    'Praeparatio cryodesiccata: virus rabiei inactivatum (Stamm: Wistar Rabies PM/WI 38-1503-3M) min. 2.5 U.I.' => "line #{__LINE__}",
    'silybum marianum D3 0.3 ml ad solutionem pro 2 ml' => "line #{__LINE__}",
    'silybum marianum D3 0.3 ml ad solutionem pro 3 ml corresp. ethanolum 30 % V/V' => "line #{__LINE__}",
    'virus poliomyelitis typus 1 inactivatum (D-Antigen) 2 mg' => "Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)",
    }
  run_substance_tests(failing_tests)   if RunFailingSpec
  run_substance_tests(excipiens_tests) if RunAllTests
  run_substance_tests(tests)           if RunAllTests

  context "should return correct substance for 'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V'" do
    string = "excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Excipiens Ad Solutionem Pro 1 Ml Corresp. Ethanolum 59.5 % V/v' }
    specify { expect(substance.chemical_substance.name).to eq 'Ethanolum' }
    specify { expect(substance.cdose.to_s).to eq ParseDose.new('59.5', '% V/V').to_s }
    specify { expect(substance.qty).to eq 1.0}
    specify { expect(substance.unit).to eq 'ml' }
  end if RunFailingSpec

  if RunAllTests

  context "should return correct substance for 'excipiens pro compresso'" do
    string = "excipiens pro compresso"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Pro Compresso' }
    specify { expect(substance.qty).to eq nil}
    specify { expect(substance.unit).to eq nil }
  end
  context "should return correct substance for 'excipiens ad solutionem pro 3 ml corresp. 50 µg'" do
    string = "excipiens ad solutionem pro 3 ml corresp. 50 µg"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Excipiens Ad Solutionem Pro 3 Ml Corresp. 50 µg' }
    specify { expect(substance.qty).to eq 3.0}
    specify { expect(substance.unit).to eq 'ml' }
  end

  context "should return correct substance for 'excipiens ad pulverem pro 1000 mg'" do
    string = "excipiens ad pulverem pro 1000 mg"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Ad Pulverem Pro' }
    specify { expect(substance.qty).to eq 1000.0 }
    specify { expect(substance.unit).to eq 'mg' }
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

  context "should return correct substance for 'pyrazinamidum 500 mg'" do
    string = "pyrazinamidum 500 mg"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Pyrazinamidum' }
    specify { expect(substance.qty).to eq 500.0 }
    specify { expect(substance.unit).to eq 'mg' }
  end

  context "should return correct substance for 'excipiens pro compresso'" do
    string = "excipiens pro compresso"
    substance = ParseSubstance.from_string(string)
    specify { expect(substance.name).to eq 'Pro Compresso' }
    specify { expect(substance.qty).to eq nil}
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
    specify { expect(substance.name).to eq 'Aqua Q.s. Ad Suspensionem Pro' }
    specify { expect(substance.qty).to eq 0.5}
    specify { expect(substance.unit).to eq 'ml' }
  end

  context "should parse a complex composition" do
    source = 'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg'
    composition = ParseSubstance.from_string(source)
  end
 end
  context "should return correct substance for 'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg'" do
    string = "toxoidum pertussis 25 µg et haemagglutininum filamentosum 15 µg"
    substance = ParseSubstance.from_string(string)
    pp substance
    binding.pry
    specify { expect(substance.name).to eq 'Toxoidum Pertussis' }
    specify { expect(substance.qty).to eq 25.0}
    specify { expect(substance.unit).to eq 'µg' }
    specify { expect(substance.chemical_substance.name).to eq 'Haemagglutininum Filamentosum' }
    specify { expect(substance.cdose.qty).to eq 15.0}
    specify { expect(substance.cdose.unit).to eq 'µg' }
    specify { expect(substance.chemical_qty).to eq '15'}
    specify { expect(substance.chemical_unit).to eq 'µg' }
  end if RunFailingSpec
end

describe ParseComposition do
# ParseComposition   = Struct.new("ParseComposition",  :source, :label, :label_description, :substances, :galenic_form, :route_of_administration)
 if RunAllTests
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
  composition_examples = [
    # 'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 % et dermatophagoides pteronyssinus 50 %, aluminium, aluminii hydroxidum hydricum ad adsorptionem, natrii chloridum, conserv.: phenolum 4.0 mg, aqua q.s. ad suspensionem pro 1 ml.',
    "color.: E 160(a)\n",
    'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg',
    "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg",
    'acari allergeni extractum 5000 U.: dermatophagoides farinae 50 %',
    "A): acari allergeni extractum 50 U.: dermatophagoides farinae 50",
    'V): mannitolum 40 mg pro dosi.',
    'gasum inhalationis, pro vitro',
    'A): acari allergeni extractum 50 U.: dermatophagoides farinae 50 %',
    'xenonum 74 -740 MBq',
    'xenonum(133-Xe) 74 -740 MBq',
    'xenonum(133-Xe) 74 -740 MBq, gasum inhalationis, pro vitro',
    "sennae folium 75 % corresp. hydroxyanthracenae 2.7 %",
    'excipiens ad pulverem corresp. suspensio reconstituta 1 ml.',
    "viperis antitoxinum equis F(ab')2 corresp. Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50 mus et Vipera ammodytes > 1000 LD50 mus, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml.",
    "I) DTPa-IPV-Komponente: toxoidum diphtheriae, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum",
    'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.',
    "extractum ethanolicum et glycerolicum liquidum ex absinthii herba 0.7 mg, cinnamomi cortex 3.8 mg, guaiaci lignum 14.3 mg, millefolii herba 7 mg, rhoeados flos 11 mg, tormentillae rhizoma 9.5 mg, balsamum tolutanum 0.3 mg, benzoe tonkinensis 4.8 mg, myrrha 2.4 mg, olibanum 0.9 mg, excipiens ad solutionem pro 1 ml, corresp. 40 guttae, corresp. ethanolum 37 % V/V",
    "rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V",
    "berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V\n",
    "cholecalciferolum 250 U.I., acidum ascorbicum 20 mg, calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg, arom.: saccharinum natricum, natrii cyclamas, vanillinum et alia, excipiens pro compresso obducto.",
    "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg",
  ]
  run_composition_tests(composition_examples)
 end
end

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
    puts "Parsed #{nr} lines with #{@nrErrors} errors in #{(Time.now - start_time).to_i} seconds"

  end  if RunAllCompositionsTests
end
