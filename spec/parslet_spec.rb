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
RunFailingSpec = true
RunAllCompositionsTests = true

describe ParseDose do

  tests = {
#    "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg" => "Osseinum-Hydroxyapatit",
    "calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Lactas Pentahydricus',
    "calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Hydrogenophosphas Anhydricus',
    "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
    "calcii gluconas corresp. calcium 100 mg" => 'Calcii Gluconas Corresp. Calcium',
    "calcii gluconas 100 mg corresp. calcium 100 mg" => 'Calcii Gluconas',
    "calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg" => 'Calcii Gluconas',
    'pimpinellae radix 15 % ad pulverem' => 'Pimpinellae Radix',
    'excipiens ad pulverem pro 1000 mg' => 'Excipiens Ad Pulverem Pro 1000 Mg',
    'excipiens ad pulverem pro charta' => 'Excipiens Ad Pulverem Pro Charta',
    'excipiens ad pulverem' => 'Excipiens Ad Pulverem',
    'antiox.: E 321' => 'E 321',
    'color.: E 160(a)' => 'E 160', # TODO: or E 160(a) ??
    'E 160(a)' => 'E 160(a)',
    'ethanolum 70-78 % V/V' => "Ethanolum",
    'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V' => 'Excipiens Ad Solutionem Pro',
    'procainum 10 mg ut procaini hydrochloridum' => 'Procaini Hydrochloridum',
    'excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V' => 'Excipiens Ad Solutionem Pro',
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
#    'Praeparatio cryodesiccata: virus rabiei inactivatum (Stamm: Wistar Rabies PM/WI 38-1503-3M) min. 2.5 U.I.' => 'tmp',
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
#    'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like ) 15 µg' => 'tmp',
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
#    'retinoli 7900' => 'Retinoli 7900',
    'retinoli 7900 U.I.' => 'Retinoli',
    'retinoli palmitas 7900 U.I.' => 'Retinoli Palmitas',
    'excipiens pro compresso' => 'Compresso',
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
    'virus poliomyelitis typus 1 inactivatum (D-Antigen) 2 mg' => 'Virus Poliomyelitis Typus 1 Inactivatum (d-antigen)',
    'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg' => 'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)',
   }
#   tests = { 'sennae folium 75 % corresp. hydroxyanthracenae 2.7 %' => 'Sennae Folium', }
    tests.each{ | string, name|
      context "should consume #{string}" do
        substance = ParseSubstance.from_string(string)
        # pp substance; binding.pry
        puts "SOLL: "+ substance.name unless name.eql? substance.name
        specify { expect(substance.class).to eq ParseSubstance }
        specify { expect(substance.name).to eq name } if substance.is_a?(ParseSubstance)
      end
    } if true

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

  context "should return correct dose for '80-120 g'" do
    string = "80-120 g"
    dose = ParseDose.from_string(string)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 80 }
    specify { expect(dose.unit).to eq 'g' }
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
end


describe ParseSubstance do
# ParseSubstance     = Struct.new("ParseSubstance",    :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose)
 if RunAllTests

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
    specify { expect(substance.name).to eq 'Compresso' }
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
  end if RunFailingSpec and false
  context "should parse a complex composition" do
    source = 'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg'
    composition = ParseSubstance.from_string(source)
  end if RunFailingSpec
 end
  context "should return correct substance for 'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg'" do
    string = "toxoidum pertussis 25 µg et haemagglutininum filamentosum 15 µg"
    substance = ParseSubstance.from_string(string)
    pp substance
    binding.pry
    specify { expect(substance.name).to eq 'Toxoidum Pertussis' }
    specify { expect(substance.qty).to eq 25.0}
    specify { expect(substance.unit).to eq 'µg' }
    specify { expect(substance.chemical_substance).to eq 'Haemagglutininum Filamentosum' }
    specify { expect(substance.cdose.qty).to eq 15.0}
    specify { expect(substance.cdose.unit).to eq 'µg' }
    specify { expect(substance.chemical_qty).to eq '15'}
    specify { expect(substance.chemical_unit).to eq 'µg' }
  end if false
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

  context "should parse more toxoidum et haemagglutininum " do
    source = 'toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg'
    composition = ParseComposition.from_string(source)
    specify { expect(composition.source).to eq source }
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
 end
  context "should parse a complex composition 2" do
    puts "xxx\n\n\n"
    source =
#  "haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml."
#  "haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml."
#  oky "natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml."
#  "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml."
  "haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg"
    composition = ParseComposition.from_string(source)
  end

  context "should parse a complex composition 1" do
    source =
"viperis antitoxinum equis F(ab')2 corresp. Vipera aspis > 1000 LD50 mus et Vipera berus > 500 LD50 mus et Vipera ammodytes > 1000 LD50 mus, natrii chloridum, polysorbatum 80, aqua ad iniectabilia q.s. ad solutionem pro 4 ml."
    composition = ParseComposition.from_string(source)
  end

  context "should parse a complex composition 3" do
    source =
# "I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I., toxoidum pertussis 25 µg, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum, streptomycinum, polymyxini B sulfas, medium199, aqua q.s. ad suspensionem pro 0.5 ml."
"I) DTPa-IPV-Komponente: toxoidum diphtheriae, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition" do
    source = 'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.'
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition 4" do
    source = "extractum ethanolicum et glycerolicum liquidum ex absinthii herba 0.7 mg, cinnamomi cortex 3.8 mg, guaiaci lignum 14.3 mg, millefolii herba 7 mg, rhoeados flos 11 mg, tormentillae rhizoma 9.5 mg, balsamum tolutanum 0.3 mg, benzoe tonkinensis 4.8 mg, myrrha 2.4 mg, olibanum 0.9 mg, excipiens ad solutionem pro 1 ml, corresp. 40 guttae, corresp. ethanolum 37 % V/V"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition 5" do
    source =
#  "malvae flos 1 %, calcatrippae flos 1 %, menthae piperitae folium 7 %, sennae folium 75 % corresp. hydroxyanthracenae 2.7 %, carvi fructus 10 %, liquiritiae radix 6 %"
#  "sennae folium 75 % corresp. hydroxyanthracenae 2.7 %, carvi fructus 10 %, liquiritiae radix 6 %"
  "sennae folium 75 % corresp. hydroxyanthracenae 2.7 %"
#  "liquiritiae radix 6 %"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec
  context "should parse a complex composition 6" do
    source =
# "rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, DER: 6-8:1, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
# "rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
#"rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
# "corresp. ethanolum 59.5 % V/V"
"rhei extractum ethanolicum siccum 50 mg corresp. glycosida anthrachinoni 5 mg, acidum salicylicum 10 mg, excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition 7" do
    source =
"berberidis corticis extractum ethanolicum liquidum 35 mg, DER: 6:1, combreti extractum aquosum liquidum 18 mg, DER: 1:4, cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V\n"
#"cynarae extractum ethanolicum liquidum 36 mg, DER: 1:1, orthosiphonis folii extractum ethanolicum liquidum 18 mg, DER: 3.5:1, excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V\n"
#"excipiens ad solutionem pro 1 ml, corresp. ethanolum 74 % V/V\n"
#"corresp. ethanolum 74 % V/V\n"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition 7" do
    source =
#"Tela cum unguento: acidum salicylicum 19.25 mg, acidum lacticum 671 µg, adeps lanae, color.: E 141, excipiens ad praeparationem pro 105.911 mg.\n"
#"acidum salicylicum 19.25 mg, acidum lacticum 671 µg, adeps lanae, color.: E 141, excipiens ad praeparationem pro 105.911 mg.\n"
#"thylis salicylas 100 mg, acidum salicylicum 20 mg, camphora racemica 4 mg, acidum formicicum concentratum 3 mg, spicae aetheroleum 10 mg, adeps lanae, color.: E 160(a), excipiens ad unguentum pro 1 g.\n"
#"color.: E 160(a), excipiens ad unguentum pro 1 g.\n"
"color.: E 160(a)\n"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec

  context "should parse a complex composition 8" do
    source =
"cholecalciferolum 250 U.I., acidum ascorbicum 20 mg, calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg, arom.: saccharinum natricum, natrii cyclamas, vanillinum et alia, excipiens pro compresso obducto."
#"calcii gluconas 100 mg et calcii lactas pentahydricus 25 mg et calcii hydrogenophosphas anhydricus 300 mg corresp. calcium 100 mg"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec
  context "should parse a complex composition 8" do
    source =
# "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg et phosphorus ruber 20 mg et proteina 18 mg, excipiens pro compresso obducto"
#"osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg"
# "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg et phosphorus ruber 20 mg et proteina 18 mg"
 "osseinum-hydroxyapatit 200 mg corresp. collagena 52 mg et calcium 43 mg"
    composition = ParseComposition.from_string(source)
  end  if RunFailingSpec and false
end
describe ParseComposition do
  context "should parse a complex composition" do
    filename = File.expand_path("#{__FILE__}/../data/compositions.txt")
    specify { expect( File.exists?(filename)).to eq true }
    inhalt = IO.readlines(filename)
    nr = 0
    @nrErrors = 0
    inhalt.each{
      |line|
      nr += 1
      puts "#{File.basename(filename)}:#{nr} #{@nrErrors} errors: #{line}"
      begin
        composition = ParseComposition.from_string line
    rescue Parslet::ParseFailed
      @nrErrors += 1
      puts "  error #{@nrErrors} in line #{File.basename(filename)}:#{nr}"
      puts line
#      binding.pry if nr > 300
    end
    }
    puts "Parsed #{nr} lines with #{@nrErrors} errors"

  end  if RunAllCompositionsTests
end
