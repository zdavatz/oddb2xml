# encoding: utf-8

begin
require 'pry'
rescue LoadError
end
require 'pp'
require 'spec_helper'
require "rexml/document"
include REXML
require "#{Dir.pwd}/lib/oddb2xml/calc"
include Oddb2xml

describe Oddb2xml::Calc do
  RunAllTests = true


  after(:each) do
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.*')))
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, 'downloads', '*')))
  end
  before(:each) do
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.xml')))
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.csv')))
  end

  Line_1 = 'I) Glucoselösung: glucosum anhydricum 150 g ut glucosum monohydricum, natrii dihydrogenophosphas dihydricus 2.34 g, zinci acetas dihydricus 6.58 mg, aqua ad iniectabilia q.s. ad solutionem pro 500 ml.'
  Line_2 = 'II) Fettemulsion: sojae oleum 25 g, triglycerida saturata media 25 g, lecithinum ex ovo 3 g, glycerolum, natrii oleas, aqua q.s. ad emulsionem pro 250 ml.'
  Line_3 = 'III) Aminosäurenlösung: isoleucinum 2.34 g, leucinum 3.13 g, lysinum anhydricum 2.26 g ut lysini hydrochloridum, methioninum 1.96 g, aqua ad iniectabilia q.s. ad solutionem pro 400 ml.'
  Line_4 = 'I) et II) et III) corresp.: aminoacida 32 g/l, acetas 32 mmol/l, acidum citricum monohydricum, in emulsione recenter mixta 1250 ml.'
  Line_5 = 'Corresp. 4000 kJ.'

  # after each name you find the column of swissmedic_package.xlsx file
  TestExample = Struct.new("TestExample", :test_description, :iksnr_A, :seqnr_B, :pack_K, :name_C, :package_size_L, :einheit_M, :active_substance_0, :composition_P,
                           :values_to_compare)

  tst_grains_de_valse = TestExample.new('Grains de Vals',
                                55491, 1, 1, "Grains de Vals, comprimés ",
                                '20', 'Tablette(n)',
                                'sennae folii extractum methanolicum siccum',
                                'sennae folii extractum methanolicum siccum 78-104 mg corresp. sennosidum B 12.5 mg, DER: 18:1, excipiens pro compresso.',
                                { :selling_units => 20,
                                  :measure => 'Tablette(n)',
                                  }
                            )
  tst_cardio_pumal = TestExample.new('Cardio-Pulmo-Rénal Sérocytol',
                                274, 1, 1, "Cardio-Pulmo-Rénal Sérocytol, suppositoire",
                                '3', 'Suppositorien',
                                'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins)',
                                'globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio.',
                                { :selling_units => 3,
                                  :measure => 'Suppositorien',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )

  tst_fluorglukose = TestExample.new('Fluorglukose',
                                51908, 2, 16, "2-Fluorglukose (18-F), Injektionslösung",
                                '0,1 - 80', 'GBq',
                                'fludeoxyglucosum(18-F) zum Kalibrierungszeitpunkt',
                                'fludeoxyglucosum(18-F) zum Kalibrierungszeitpunkt 0.1-8 GBq, dinatrii phosphas dihydricus, natrii dihydrogenophosphas dihydricus, natrii chloridum, antiox.: natrii thiosulfas 1.3-1.9 mg, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 1,
                                  :measure => 'GBq',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_bicaNova = TestExample.new('bicaNova',
                                58277, 1, 1, "bicaNova 1,5 % Glucose, Peritonealdialyselösung",
                                '1500 ml', '',
                                'natrii chloridum, natrii hydrogenocarbonas, calcii chloridum dihydricum, magnesii chloridum hexahydricum, glucosum anhydricum, natrium, calcium, magnesium, chloridum, hydrogenocarbonas, glucosum',
                                'I) et II) corresp.: natrii chloridum 5.5 g, natrii hydrogenocarbonas 3.36 g, calcii chloridum dihydricum 184 mg, magnesii chloridum hexahydricum 102 mg, glucosum anhydricum 15 g ut glucosum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 1000 ml.',
                                { :selling_units => 1500,
                                  :measure => 'ml',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_kamillin = TestExample.new('Kamillin Medipharm, Bad',
                                43454, 1, 101, "Kamillin Medipharm, Bad",
                                '25 x 40', 'ml',
                                'matricariae extractum isopropanolicum liquidum',
                                'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml.',
                                { :selling_units => 25,
                                  :measure => 'ml',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_infloran = TestExample.new('Test Infloran, capsule',
                                679, 2, 12, "Infloran, capsule",
                                '2x10', 'Kapsel(n)',
                                'lactobacillus acidophilus cryodesiccatus, bifidobacterium infantis',
                                'lactobacillus acidophilus cryodesiccatus min. 10^9 CFU, bifidobacterium infantis min. 10^9 CFU, color.: E 127, E 132, E 104, excipiens pro capsula.',
                                { :selling_units => 20,
                                  :measure => 'Kapsel(n)',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_mutagrip = TestExample.new('Test Mutagrip (Fertigspritzen)',
                                373, 23, 10, "Mutagrip, Suspension zur Injektion",
                                '10 x 0.5 ml', 'Fertigspritze(n)',
                                'ropivacainum',
                                'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 10,
                                  :measure => 'Fertigspritze(n)',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_nutriflex = TestExample.new('Nutriflex Lipid plus ohne Elektrolyte, Infusionsemulsion 1250ml',
                                56089, 1, 1, 'Nutriflex Lipid plus, Infusionsemulsion, 1250ml',
                                '5 x 1250', 'ml',
                                'glucosum anhydricum, isoleucinum, leucinum, lysinum anhydricum, methioninum, phenylalaninum, threoninum, tryptophanum, valinum, argininum, histidinum, alaninum, acidum asparticum, acidum glutamicum, glycinum, prolinum, serinum, aminoacida, carbohydrata, materia crassa, sojae oleum, triglycerida saturata media',
                                "I) Glucoselösung: glucosum anhydricum 150 g ut glucosum monohydricum, acidum citricum anhydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml.
II) Fettemulsion: sojae oleum 25 g, triglycerida saturata media 25 g, lecithinum ex ovo, glycerolum, natrii oleas, aqua q.s. ad emulsionem.
III) Aminosäurenlösung: isoleucinum 2.82 g, leucinum 3.76 g, lysinum anhydricum 2.73 g ut lysinum monohydricum, methioninum 2.35 g, phenylalaninum 4.21 g, threoninum 2.18 g, tryptophanum 0.68 g, valinum 3.12 g, argininum 3.24 g, histidinum 1.50 g, alaninum 5.82 g, acidum asparticum 1.80 g, acidum glutamicum 4.21 g, glycinum 1.98 g, prolinum 4.08 g, serinum 3.60 g, acidum citricum anhydricum, aqua ad iniectabilia q.s. ad solutionem pro 500 ml.
.
I) et II) et III) corresp.: aminoacida 48 g/l, carbohydrata 150 g/l, materia crassa 50 g/l, in emulsione recenter mixta 1250 ml.
Corresp. 5300 kJ.",
                                { # :selling_units => 5,
                                  # :measure => 'Infusionsemulsion',
                                  #:count => 25, :multi => 1
                                  }
                              )
  tst_diamox = TestExample.new('Diamox. Tabletten',
                                21191, 1, 19, 'Diamox, comprimés',
                                '1 x 25', 'Tablette(n)',
                                'acetazolamidum',
                                'acetazolamidum 250 mg, excipiens pro compresso.',
                                { :selling_units => 25,
                                  :measure => 'Tablette(n)',
                                  #:count => 25, :multi => 1
                                  }
                              )

  tst_naropin = TestExample.new('Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml',
                             54015, 01, 100, "Naropin 0,2 %, Infusionslösung / Injektionslösung",
                             '1 x 5 x 100', 'ml',
                             'ropivacainum',
                             'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                             { # :selling_units => 5, TODO:
                               # :measure => 'ml',
                               #:count => 5, :multi => 1
                               }
                            )

if RunAllTests
  context 'should return correct value for liquid' do
    pkg_size_L = '1 x 5 x 200'
    einheit_M  = 'ml'
    name_C = 'Naropin 0,2 %, Infusionslösung / Injektionslösung'
    result = Calc.new(name_C, pkg_size_L, einheit_M, nil)
    specify { expect(result.selling_units).to eq 5 }
    specify { expect(result.measure).to eq 'ml' }
  end

  context 'should return correct value for W-Tropfen' do
    pkg_size_L = '10'
    einheit_M  = 'ml'
    name_C = 'W-Tropfen'
    result = Calc.new(name_C, pkg_size_L, einheit_M, nil)
    specify { expect(result.selling_units).to eq 10 }
    specify { expect(result.measure).to eq 'ml' }
  end

  context 'should return correct value for Diamox, comprimés' do
    pkg_size_L = '1 x 25'
    einheit_M  = 'Tablette(n)'
    name_C = 'Diamox, comprimés'

    result = Calc.new(name_C, pkg_size_L, einheit_M, nil)
    specify { expect(result.selling_units).to eq 25 }
    specify { expect(result.measure).to eq 'Tablette(n)' }

    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
  end

  context 'should return correct value for Perindopril' do
    pkg_size_L = '90'
    einheit_M  = 'Tablette(n)'
    name_C = 'comprimés pelliculés'

    result = Calc.new(name_C, pkg_size_L, einheit_M, nil)
    specify { expect(result.selling_units).to eq 90 }
    specify { expect(result.measure).to eq einheit_M }

    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
  end


  context 'should find galenic_group for Kaugummi' do
    result = Calc.get_galenic_group('Kaugummi')
    specify { expect(result.class).to eq  GalenicGroup }
    specify { expect(result.description).to eq 'Kaugummi' }
  end

  context 'should find galenic_form for Infusionslösung / Injektionslösung' do
    value = 'Infusionslösung / Injektionslösung'
    result = Calc.get_galenic_form(value)
    specify { expect(result.class).to eq  GalenicForm }
    specify { expect(result.description).to eq 'Infusionslösung/Injektionslösung' }
  end

  context 'should return galenic_group unknown for galenic_group Dummy' do
    result = Calc.get_galenic_group('Dummy')
    specify { expect(result.class).to eq  GalenicGroup }
    specify { expect(result.oid).to eq  1 }
    specify { expect(result.descriptions['de']).to eq 'unbekannt' }
    specify { expect(result.description).to eq 'unbekannt' }
  end

  class TestExample
    def url
      "http://ch.oddb.org/de/gcc/drug/reg/#{sprintf('%05d' % iksnr_A)}/seq/#{sprintf('%02d' % seqnr_B)}/pack/#{sprintf('%03d' % pack_K)}"
    end
  end
  [tst_fluorglukose,
   tst_kamillin,
   tst_naropin,
   tst_diamox,
   tst_mutagrip,
  ].each {
    |tst|
      context "verify #{tst.iksnr_A} #{tst.name_C}: #{tst.url}" do
        info = Calc.new(tst.name_C, tst.package_size_L, tst.einheit_M, tst.active_substance_0, tst.composition_P)
        tst.values_to_compare.each do
          |key, value|
          context key do
            cmd = "expect(info.#{key}.to_s).to eq '#{value.to_s}'"
            specify { eval(cmd) }
          end
        end
      end
  }

  context 'find correct result for Injektionslösung' do
    info = Calc.new(tst_naropin.name_C, tst_naropin.package_size_L, tst_naropin.einheit_M, tst_naropin.active_substance_0, tst_naropin.composition_P)
    specify { expect(tst_naropin.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/54015/seq/01/pack/100' }
    specify { expect(info.galenic_form.description).to eq  'Infusionslösung/Injektionslösung' }
    specify { expect(info.galenic_group.description).to eq  'Injektion/Infusion' }
    specify { expect(info.pkg_size).to eq '1 x 5 x 100' }
    skip    { expect(info.measure).to eq  '100 ml' }
    # specify { expect(info.count).to eq  5 }
    # specify { expect(info.multi).to eq  1 }
    # specify { expect(info.addition).to eq 0 }
    # specify { expect(info.scale).to eq  1 }
  end

  context 'find correct result for Inflora, capsule' do
    info = Calc.new(tst_infloran.name_C, tst_infloran.package_size_L, tst_infloran.einheit_M, tst_infloran.active_substance_0, tst_infloran.composition_P)
    specify { expect(tst_infloran.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/00679/seq/02/pack/012' }
    specify { expect(info.galenic_form.description).to eq 'capsule' }
    skip { expect(info.galenic_group.description).to eq  'Injektion/Infusion' }
    specify { expect(info.pkg_size).to eq '2x10' }
    specify { expect(info.selling_units).to eq  20 }
    skip { expect(info.measure).to eq  '0' }
    # specify { expect(info.count).to eq  5 }
    # specify { expect(info.multi).to eq  1 }
    # specify { expect(info.addition).to eq 0 }
    # specify { expect(info.scale).to eq  1 }
  end

  context 'convert mg/l into ml/mg for solutions' do
    result = Calc.new('50', 'g/l')
    skip { expect(result.measure).to eq  50 }
  end

  run_time_options = '--calc --skip-download'
  context "when passing #{run_time_options}" do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!(run_time_options.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it 'should create a correct xml and a csv file' do
      src = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'swissmedic_package-galenic.xlsx'))
      dest =  File.join(Oddb2xml::WorkDir, 'swissmedic_package.xlsx')
      FileUtils.makedirs(Oddb2xml::WorkDir)
      FileUtils.cp(src, dest, { :verbose => true, :preserve => true})
      FileUtils.cp(File.expand_path(File.join(File.dirname(__FILE__), 'data', 'XMLPublications.zip')),
                  File.join(Oddb2xml::WorkDir, 'downloads'),
                  { :verbose => true, :preserve => true})
      cli.run
      expected = [
        'oddb_calc.xml',
        'oddb_calc.csv',
      ].each { |file|
              full = File.join(Oddb2xml::WorkDir, file)
              expect(File.exists?(full)).to eq true
             }
      xml = File.read(File.join(Oddb2xml::WorkDir, 'oddb_calc.xml'))
      m = />.*  /.match(xml)
      m.should eq nil
      doc = REXML::Document.new xml
#      puts xml; binding.pry
      gtin = '7680540151009'
      ean12 = '7680' + sprintf('%05d',tst_naropin.iksnr_A) + sprintf('%03d',tst_naropin.pack_K)
      ean13 = (ean12 + Oddb2xml.calc_checksum(ean12))
      ean13.should eq gtin

      tst_naropin.values_to_compare.each{
        | key, value |
          result = XPath.match( doc, "//ARTICLE[GTIN='#{gtin}']/#{key.to_s.upcase}").first.text
          puts "Testing key #{key.inspect} #{value.inspect} against #{result} seems to fail" unless result == value.to_s
          result.should eq value.to_s
      }

      gtin = '7680560890018'
      ean12 = '7680' + sprintf('%05d',tst_nutriflex.iksnr_A) + sprintf('%03d',tst_nutriflex.pack_K)
      ean13 = (ean12 + Oddb2xml.calc_checksum(ean12))
      ean13.should eq gtin
      tst_nutriflex.values_to_compare.each{
        | key, value |
          result = XPath.match( doc, "//ARTICLE[GTIN='#{gtin}']/#{key.to_s.upcase}").first.text
          puts "Testing key #{key.inspect} #{value.inspect} against #{result} seems to fail" unless result == value.to_s
          result.should eq value.to_s
      }
      matri_name = 'Matricariae Extractum Isopropanolicum Liquidum'
      XPath.match( doc, "//ARTICLE[GTIN='7680545250363']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/SUBSTANCE_NAME").
        find{|x| x.text.eql?("Alprostadilum")}.text.should eq 'Alprostadilum'
      XPath.match( doc, "//ARTICLE[GTIN='7680458820202']/NAME").last.text.should eq 'Magnesiumchlorid 0,5 molar B. Braun, Zusatzampulle für Infusionslösungen'
      XPath.match( doc, "//ARTICLE[GTIN='7680555940018']/COMPOSITIONS/COMPOSITION/LABEL").first.text.should eq 'I'
      XPath.match( doc, "//ARTICLE[GTIN='7680555940018']/COMPOSITIONS/COMPOSITION/LABEL_DESCRIPTION").first.text.should eq 'Glucoselösung'
      XPath.match( doc, "//ARTICLE[GTIN='7680555940018']/COMPOSITIONS/COMPOSITION/LABEL").each{ |x| puts x.text }
      XPath.match( doc, "//ARTICLE[GTIN='7680555940018']/COMPOSITIONS/COMPOSITION/LABEL").last.text.should eq 'III'
      XPath.match( doc, "//ARTICLE[GTIN='7680555940018']/COMPOSITIONS/COMPOSITION/CORRESP").last.text.should eq '4240 kJ pro 1 l'

      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/SUBSTANCE_NAME").
        find{|x| x.text.eql?(matri_name)}.text.should eq matri_name
      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/CHEMICAL_SUBSTANCE").last.text.should eq 'Levomenolum'
      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/QTY").first.text.should eq '98.9'
      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/MORE_INFO").first.text.should eq 'ratio: 1:2-2.8'
      XPath.match( doc, "//ARTICLE[GTIN='7680300150105']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/SUBSTANCE_NAME").first.text.should eq 'Lidocaini Hydrochloridum'
      XPath.match( doc, "//ARTICLE[GTIN='7680300150105']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/UNIT").first.text.should eq 'mg/ml'

      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/CHEMICAL_QTY").first.text.should eq '10-50'
      XPath.match( doc, "//ARTICLE[GTIN='7680434541015']/COMPOSITIONS/COMPOSITION/SUBSTANCES/SUBSTANCE/CHEMICAL_UNIT").first.text.should eq 'mg/100 g'

    end
  end

  context 'find correct result for Kamillin' do
    info = Calc.new(tst_kamillin.name_C, tst_kamillin.package_size_L, tst_kamillin.einheit_M, tst_kamillin.active_substance_0, tst_kamillin.composition_P)
    specify { expect(info.selling_units).to eq  25 }
  end

  context 'find correct result for bicaNova' do
    info = Calc.new(tst_bicaNova.name_C, tst_bicaNova.package_size_L, tst_bicaNova.einheit_M, tst_bicaNova.active_substance_0, tst_bicaNova.composition_P)
    specify { expect(info.selling_units).to eq  1500 }
    specify { expect(info.measure).to eq 'ml' }
  end

  context 'should return correct value for mutagrip' do
    pkg_size_L = '10 x 0.5 ml'
    einheit_M  = 'Fertigspritze(n)'
    name_C = 'Suspension zur Injektion'

    result = Calc.new(name_C, pkg_size_L, einheit_M, nil)
    specify { expect(result.selling_units).to eq 10 }
    specify { expect(result.measure).to eq einheit_M }

    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
  end

  context 'find correct result for Nutriflex' do
    info = Calc.new(tst_nutriflex.name_C, tst_nutriflex.package_size_L, tst_nutriflex.einheit_M, tst_nutriflex.active_substance_0, tst_nutriflex.composition_P)
    specify { expect(info.selling_units).to eq  5 }
    specify { expect(info.galenic_form.description).to eq  "Infusionsemulsion" }
  end

  context 'should handle CFU' do
    result = Calc.new(nil, nil, nil, 'lactobacillus acidophilus cryodesiccatus, bifidobacterium infantis',
                      'lactobacillus acidophilus cryodesiccatus min. 10^9 CFU, bifidobacterium infantis min. 10^9 CFU, color.: E 127, E 132, E 104, excipiens pro capsula.')
    skip "Infloran, capsule mit cryodesiccatus min. 10^9 CFU"
  end
  context 'find correct result compositions' do
    result = Calc.new(nil, nil, nil, 'rutosidum trihydricum, aescinum', 'rutosidum trihydricum 20 mg, aescinum 25 mg, aromatica, excipiens pro compresso.')
    specify { expect(result.compositions.first.substances.first.name).to eq  'Rutosidum Trihydricum' }
    specify { expect(result.compositions.first.substances.first.qty.to_f).to eq  20}
    specify { expect(result.compositions.first.substances.first.unit).to eq  'mg'}
    specify { expect(result.compositions.first.substances[1].name).to eq  'Aescinum' }
    specify { expect(result.compositions.first.substances[1].qty.to_f).to eq  25}
    specify { expect(result.compositions.first.substances[1].unit).to eq  'mg'}
  end

  context 'find correct result for Inflora, capsule' do
    info = Calc.new(tst_infloran.name_C, tst_infloran.package_size_L, tst_infloran.einheit_M, tst_infloran.active_substance_0, tst_infloran.composition_P)
    # specify { expect(tst_infloran.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/00679/seq/02/pack/012' }
    specify { expect(info.galenic_form.description).to eq 'capsule' }
    skip { expect(info.galenic_group.description).to eq  'Injektion/Infusion' }
    specify { expect(info.pkg_size).to eq '2x10' }
    specify { expect(info.selling_units).to eq  20 }
    skip { expect(info.measure).to eq  '0' }
    bifidobacterium =  info.compositions.first.substances.find{ |x| x.name.match(/Bifidobacterium/i) }
    specify { expect(bifidobacterium).not_to eq nil}
    if bifidobacterium
      specify { expect(bifidobacterium.name).to eq  'Bifidobacterium Infantis' }
      skip { expect(bifidobacterium.qty.to_f).to eq  '10^9'}
      skip { expect(bifidobacterium.unit).to eq  'CFU'}
    end
    e_127 =  info.compositions.first.substances.find{ |x| x.name.match(/E 127/i) }
    skip { expect(e_127).not_to eq nil}
    if e_127
      specify { expect(e_127.name).to eq  'E 127' }
      specify { expect(e_127.unit).to eq  nil}
    end
  end
end
  context 'find correct result for 274 Cardio-Pulmo-Rénal Sérocytol, suppositoire' do
    info = Calc.new(tst_cardio_pumal.name_C, tst_cardio_pumal.package_size_L, tst_cardio_pumal.einheit_M, tst_cardio_pumal.active_substance_0, tst_cardio_pumal.composition_P)
    specify { expect(info.galenic_form.description).to eq 'suppositoire' }
    specify { expect(info.galenic_group.description).to eq  'unbekannt' }
    specify { expect(info.pkg_size).to eq '3' }
    specify { expect(info.selling_units).to eq  3 }
    specify { expect(info.name).to eq 'Cardio-Pulmo-Rénal Sérocytol, suppositoire'}
    specify { expect(info.measure).to eq  'Suppositorien' }
    globulina =  info.compositions.first.substances.find{ |x| x.name.match(/porcins|globulina/i) }
    specify { expect(globulina).not_to eq nil}
    if globulina
      specify { expect(globulina.name.downcase).to eq  'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)'.downcase }
      specify { expect(globulina.qty.to_f).to eq  8.0}
      specify { expect(globulina.unit).to eq  'mg'}
    end
    e_216 =  info.compositions.first.substances.find{ |x| x.name.match(/E 216/i) }
    specify { expect(e_216).not_to eq nil}
    if e_216
      specify { expect(e_216.name).to eq  'E 216' }
      specify { expect(e_216.unit).to eq  nil}
    end
    e_218 =  info.compositions.first.substances.find{ |x| x.name.match(/E 218/i) }
    specify { expect(e_218).not_to eq nil}
  end

if RunAllTests

  context 'find correct result compositions for 00613 Pentavac' do
    line_1 = "I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I., toxoidum tetani 40 U.I., toxoidum pertussis 25 µg et haemagglutininum filamentosum 25 µg, virus poliomyelitis typus 1 inactivatum (D-Antigen) 40 U., virus poliomyelitis typus 2 inactivatum (D-Antigen) 8 U., virus poliomyelitis typus 3 inactivatum (D-Antigen) 32 U., aluminium ut aluminii hydroxidum hydricum ad adsorptionem, formaldehydum 10 µg, conserv.: phenoxyethanolum 2.5 µl, residui: neomycinum, streptomycinum, polymyxini B sulfas, medium199, aqua q.s. ad suspensionem pro 0.5 ml."
    line_2 = "II) Hib-Komponente (Lyophilisat): haemophilus influenzae Typ B polysaccharida T-conjugatum 10 µg, trometamolum, saccharum, pro praeparatione."
    txt = "#{line_1}\n#{line_2}"
    info = ParseUtil.parse_compositions(txt)
    specify { expect(info.first.label).to eq  'I' }
    specify { expect(info.size).to eq  2 }
    specify { expect(info.first.substances.size).to eq  14 }
    toxoidum =  info.first.substances.find{ |x| x.name.match(/Toxoidum Diphtheriae/i) }
    specify { expect(toxoidum.class).to eq  ParseSubstance }
    if toxoidum
      specify { expect(toxoidum.name).to eq  'Toxoidum Diphtheriae' }
      specify { expect(toxoidum.qty.to_f).to eq  30.0 }
      specify { expect(toxoidum.unit).to eq  'U.I./0.5 ml' }
    end
  end

  context 'find correct result compositions for fluticasoni with chemical_dose' do
    info = ParseUtil.parse_compositions('fluticasoni-17 propionas 100 µg, lactosum monohydricum q.s. ad pulverem pro 25 mg.')
    specify { expect(info.size).to eq  1 }
    specify { expect(info.first.substances.size).to eq  2 }
    fluticasoni =  info.first.substances.find{ |x| x.name.match(/Fluticasoni/i) }
    specify { expect(fluticasoni.name).to eq  'Fluticasoni-17 Propionas' }
    specify { expect(fluticasoni.qty.to_f).to eq  100.0 }
    specify { expect(fluticasoni.unit).to eq  'µg/25 mg' }
    specify { expect(fluticasoni.dose.to_s).to eq  "100 µg/25 mg" }
    lactosum =  info.first.substances.find{ |x| x.name.match(/Lactosum/i) }
    specify { expect(lactosum.name).to eq "Lactosum Monohydricum" }
    specify { expect(lactosum.dose.to_s).to eq  "25 mg" }
  end

  context 'find correct result compositions for stuff with percents' do
    txt = 'calcium carbonicum hahnemanni C7 5 %, chamomilla recutita D5 22.5 %, magnesii hydrogenophosphas trihydricus C5 50 %, passiflora incarnata D5 22.5 %, xylitolum, excipiens ad globulos.'
    info = ParseUtil.parse_compositions(txt)
    specify { expect(info.size).to eq  1 }
    specify { expect(info.first.substances.size).to eq ExcipiensIs_a_Substance ? 6 : 5 }
    recutita =  info.first.substances.find{ |x| x.name.match(/recutita/i) }
    specify { expect(recutita.name).to eq  'Chamomilla Recutita D5' }
    specify { expect(recutita.qty.to_f).to eq  22.5 }
    specify { expect(recutita.unit).to eq  '%' }
  end

  context 'find correct result compositions for procainum with chemical_dose' do
    txt = 'procainum 10 mg ut procaini hydrochloridum, phenazonum 50 mg, Antiox.: E 320, glycerolum q.s. ad solutionem pro 1 g.'
    info = ParseUtil.parse_compositions(txt)
    specify { expect(info.size).to eq  1 }
    specify { expect(info.first.substances.size).to eq  4 }
    procainum =  info.first.substances.find{ |x| x.name.match(/procain/i) }
    specify { expect(procainum.name).to eq  'Procainum' }
    specify { expect(procainum.qty.to_f).to eq  10.0 }
    specify { expect(procainum.unit).to eq  'mg/g' }
  end

  context 'find correct result compositions for poloxamerum' do
    line_1 = "I): albuminum humanum colloidale 0.5 mg, stanni(II) chloridum dihydricum 0.2 mg, glucosum anhydricum, dinatrii phosphas monohydricus, natrii fytas (9:1), poloxamerum 238, q.s. ad pulverem pro vitro."
    line_2 = "II): pro usu: I) recenter radioactivatum 99m-technetio ut natrii pertechnetas."
    text = "#{line_1}\n#{line_2}"
    info = Calc.new('Nanocoll, Markierungsbesteck', nil, nil,
                      'albuminum humanum colloidale, stanni(II) chloridum dihydricum',
                      text
                      )
    specify { expect(info.compositions.size).to eq  2 }
    specify { expect(info.compositions.first.substances.size).to eq ExcipiensIs_a_Substance ? 7 : 6 }
    poloxamerum =  info.compositions.first.substances.find{ |x| x.name.match(/poloxamerum/i) }
    skip { expect(poloxamerum.name).to eq  'Poloxamerum 238' }
    skip { expect(poloxamerum.qty.to_f).to eq  "" }
    specify { expect(poloxamerum.unit).to eq  "" }
  end

  context 'find correct result for 61676 Phostal 3-Bäume A): ' do
    text = "A): pollinis allergeni extractum 0.01 U.: betula pendula Roth 25 % et alnus glutinosa 25 % et corylus avellana 25 % et fraxinus excelsior 25 %, natrii chloridum, glycerolum, tricalcii phosphas, conserv.: phenolum 4.0 mg, aqua q.s. ad suspensionem pro 1 ml"
    info = Calc.new('Phostal 3-Bäume', nil, nil,
                      'pollinis allergeni extractum',
                      text
                      )
    specify { expect(info.compositions.size).to eq  1 }
    specify { expect(info.compositions.first.label).to eq  'A' }
  end

  context 'find correct result for 47837 Ecodurex' do
    text = "amiloridi hydrochloridum dihydricum 5.67 mg corresp. amiloridi hydrochloridum anhydricum 5 mg, hydrochlorothiazidum 50 mg, excipiens pro compresso."
    info = Calc.new('Ecodurex', nil, nil,
                      'amiloridi hydrochloridum anhydricum, hydrochlorothiazidum',
                      text
                      )
    specify { expect(info.compositions.size).to eq  1 }
    specify { expect(info.compositions.first.label).to eq  nil }
    substance1 =  info.compositions.first.substances.find{ |x| x.name.match(/hydrochlorothiazidum/i) }
    specify { expect(substance1.name).to eq  'Hydrochlorothiazidum' }
    substance3 =  info.compositions.first.substances.find{ |x| x.name.match(/amiloridi hydrochloridum/i) }
    specify { expect(substance3.class).to eq  ParseSubstance }
    if substance3
      specify { expect(substance3.name).to eq                            'Amiloridi Hydrochloridum Dihydricum' }
      specify { expect(substance3.chemical_substance.name).to eq         'Amiloridi Hydrochloridum Anhydricum' }
      specify { expect(substance3.qty.to_f).to eq  5.67 }
      specify { expect(substance3.unit).to eq  'mg' }
      specify { expect(substance3.chemical_substance.qty.to_f).to eq  5.67 }
      specify { expect(substance3.chemical_substance.unit).to eq  'mg' }
      specify { expect(substance3.is_active_agent).to eq true }
    end

  end

  context 'find correct result for 45079 Dr. Reckeweg R 51 Thyreosan, gouttes homéopathiques' do
    text = "atropa belladonna D30, iodum D30, lapis albus D12, lycopus virginicus D12, natrii chloridum D30 ana partes 0.1 ml, excipiens ad solutionem pro 1 ml, corresp. ethanolum 35 % V/V."
    info = Calc.new('Dr. Reckeweg R 51 Thyreosan, gouttes homéopathiques', nil, nil,
                      'atropa belladonna D30, iodum D30, lapis albus D12, lycopus virginicus D12, natrii chloridum D30',
                      text
                      )
    specify { expect(info.compositions.size).to eq  1 }
    specify { expect(info.compositions.first.label).to eq  nil }
    substance1 =  info.compositions.first.substances.find{ |x| x.name.match(/atropa belladonna/i) }
    specify { expect(substance1.name).to eq  'Atropa Belladonna D30' }
    substance2 =  info.compositions.first.substances.find{ |x| x.name.match(/lycopus virginicus/i) }
    specify { expect(substance2.class).to eq  ParseSubstance }
    substance3 =  info.compositions.first.substances.find{ |x| x.name.match(/lapis albus/i) }
    specify { expect(substance3.class).to eq  ParseSubstance }
    if substance3
      specify { expect(substance3.name).to eq                'Lapis Albus D12' }
    end
  end

  context 'find correct result for 00417 Tollwut Impfstoff Mérieu' do
    text = "Praeparatio cryodesiccata: virus rabiei inactivatum (Stamm: Wistar Rabies PM/WI 38-1503-3M) min. 2.5 U.I., albuminum humanum, neomycini sulfas, residui: phenolsulfonphthaleinum.
Solvens: aqua ad iniectabilia q.s. ad suspensionem pro 1 ml."
    info = Calc.new('Tollwut Impfstoff Mérieu', nil, nil,
                      'virus rabiei inactivatum (Stamm: Wistar Rabies PM/WI 38-1503-3M) ',
                      text
                      )
    specify { expect(info.compositions.size).to eq  2 }
    specify { expect(info.compositions.first.label).to eq  nil }
    substance1 =  info.compositions.first.substances.find{ |x| x.name.match(/virus rabiei inactivatu/i) }
    specify { expect(substance1).should_not be  nil }
    if substance1
      specify { expect(substance1.name).to eq  'Virus Rabiei Inactivatum (stamm: Wistar Rabies Pm/wi 38-1503-3m)' }
    end
    substance2 =  info.compositions.first.substances.find{ |x| x.name.match(/albuminum humanu/i) }
    if substance2
      specify { expect(substance2.name).to eq  'Albuminum Humanum' }
    end
    specify { expect(substance2.class).to eq  ParseSubstance }
    substance3 =  info.compositions.first.substances.find{ |x| x.name.match(/neomycini sulfas/i) }
    specify { expect(substance3.class).to eq  ParseSubstance }
    if substance3
      specify { expect(substance3.name).to eq  'Neomycini Sulfas' }
    end
  end

  context "find correct result compositions for #{tst_grains_de_valse.composition_P} with chemical_dose" do
    info = Calc.new(tst_grains_de_valse.name_C, tst_grains_de_valse.package_size_L, tst_grains_de_valse.einheit_M, tst_grains_de_valse.active_substance_0, tst_grains_de_valse.composition_P)
    sennosidum =  info.compositions.first.substances.find{ |x| x.name.match(/Senn/i) }
    specify { expect(sennosidum).not_to eq nil}
    if sennosidum
      specify { expect(sennosidum.name).to eq  'Sennae Folii Extractum Methanolicum Siccum' }
      specify { expect(sennosidum.dose.to_s).to eq  '78-104 mg' }
      specify { expect(sennosidum.qty.to_f).to eq  78.0}
      specify { expect(sennosidum.unit).to eq  'mg'}
      specify { expect(sennosidum.chemical_substance.name).to eq  'Sennosidum B' }
      specify { expect(sennosidum.chemical_substance.qty.to_f).to eq  12.5 }
      specify { expect(sennosidum.chemical_substance.unit).to eq  'mg' }
    end
  end

  context 'find correct result compositions for 56829 sequence 3 Iscador M 0,01 mg' do
    comment_from_email_good_7_juni_2011 = %(
    Ausgedeutscht heisst das:
Der Extrakt ist ein Auszug aus der Frischpflanze im Verhältnis 1:5, also ‚extractum 0.05 mg’ entspricht 0.01 mg frischem Mistelkraut.
Es handelt sich um EINEN Wirkstoff, also „in Kombination“ ist falsch formuliert.
Die HILFSSTOFFE sind Aqua ad iniectabilia und Natrii chloridum.
)
    text = 'extractum aquosum liquidum fermentatum 0.05 mg ex viscum album (mali) recens 0.01 mg, natrii chloridum, aqua q.s. ad solutionem pro 1 ml.'
    info = Calc.new("Iscador M 0,01 mg, Injektionslösung", '2 x 7', 'Ampulle(n)',
                    'viscum album (mali) recens',
                    text)
    specify { expect(info.pkg_size).to eq '2 x 7' }
    specify { expect(info.selling_units).to eq 14 }
    specify { expect(info.compositions.first.substances.size).to eq ExcipiensIs_a_Substance ? 3 : 2 }
    viscum =  info.compositions.first.substances.find{ |x| x.name.match(/viscum/i) }
    specify { expect(viscum).not_to eq nil}
    natrii =  info.compositions.first.substances.find{ |x| x.name.match(/natrii chloridum/i) }
    specify { expect(natrii).not_to eq nil}
    if viscum
      specify { expect(viscum.name).to eq  'Viscum Album (mali) Recens' }
      specify { expect(viscum.is_active_agent).to eq  true }
      specify { expect(viscum.dose.to_s).to eq  '0.01 mg/ml' }
      specify { expect(viscum.qty.to_f).to eq  0.01}
      specify { expect(viscum.unit).to eq  'mg/ml'}
      specify { expect(viscum.chemical_substance).to eq  nil }
    end
  end
  context 'find correct result compositions for 56829 sequence 23 Iscador Ag 0,01 mg' do
    text = 'extractum aquosum liquidum fermentatum 0.05 mg ex viscum album (mali) recens 0.01 mg, natrii chloridum, argenti carbonas (0,01 ug pro 100 mg herba recente), aqua q.s. ad solutionem pro 1 ml.'
    info = Calc.new("Iscador M c. Arg. 0,01 mg, Injektionslösung, anthroposophisches Arzneimittel", '2 x 7', 'Ampulle(n)',
                    'viscum album (mali) recens, argenti carbonas (0,01 ug pro 100 mg herba recente)',
                    text)
    specify { expect(info.pkg_size).to eq '2 x 7' }
    specify { expect(info.selling_units).to eq 14 }
    specify { expect(info.compositions.first.substances.size).to eq ExcipiensIs_a_Substance ? 4 : 3 }
    viscum =  info.compositions.first.substances.find{ |x| x.name.match(/viscum/i) }
    specify { expect(viscum).not_to eq nil}
    if viscum
      specify { expect(viscum.name).to eq  'Viscum Album (mali) Recens' }
      specify { expect(viscum.dose.to_s).to eq  '0.01 mg/ml' }
      specify { expect(viscum.qty.to_f).to eq  0.01}
      specify { expect(viscum.unit).to eq  'mg/ml'}
      specify { expect(viscum.chemical_substance).to eq  nil }
    end
    argenti =  info.compositions.first.substances.find{ |x| x.name.match(/Argenti/i) }
    specify { expect(argenti).not_to eq nil}
    if argenti
      specify { expect(argenti.name).to eq  'Argenti Carbonas' }
      skip  { expect(argenti.dose.to_s).to eq  '0.01 mg/ml' } # 100 mg/ml
      skip  { expect(argenti.qty.to_f).to eq  0.01}
      skip  { expect(argenti.unit).to eq  'mg/ml'}
      specify { expect(argenti.chemical_substance).to eq  nil }
    end
  end
end
  end