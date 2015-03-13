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

  after(:each) do
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.*')))
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, 'downloads', '*')))
  end
  before(:each) do
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.xml')))
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.csv')))
  end

  # after each name you find the column of swissmedic_package.xlsx file
  TestExample = Struct.new("TestExample", :test_description, :iksnr_A, :seqnr_B, :pack_K, :name_C, :package_size_L, :einheit_M, :active_substance_0, :composition_P,
                           :values_to_compare)

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
                                56089, 1, 1, 'Nutriflex Lipid plus ohne Elektrolyte, Infusionsemulsion 1250ml',
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
      XPath.match( doc, "//ARTICLE[GTIN='7680545250363']/COMPOSITIONS/COMPONENT/NAME").last.text.should eq 'Alprostadilum'
      XPath.match( doc, "//ARTICLE[GTIN='7680458820202']/NAME").last.text.should eq 'Magnesiumchlorid 0,5 molar B. Braun, Zusatzampulle für Infusionslösungen'
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
    skip "Nutriflex Infusionsemulsion"
    # specify { expect(info.galenic_form.description).to eq  "Infusionsemulsion" }
  end

  context 'should handle CFU' do
    result = Calc.new(nil, nil, nil, 'lactobacillus acidophilus cryodesiccatus, bifidobacterium infantis',
                      'lactobacillus acidophilus cryodesiccatus min. 10^9 CFU, bifidobacterium infantis min. 10^9 CFU, color.: E 127, E 132, E 104, excipiens pro capsula.')
    skip "Infloran, capsule mit cryodesiccatus min. 10^9 CFU"
  end

  context 'find correct result compositions' do
    text = 'I) Glucoselösung: glucosum anhydricum 80 g ut glucosum monohydricum, natrii dihydrogenophosphas dihydricus 1.17 g glycerolum, zinci acetas dihydricus 6.625 mg, natrii oleas, aqua q.s. ad emulsionem pro 250 ml.
II) Fettemulsion: sojae oleum 25 g, triglycerida saturata media 25 g, lecithinum ex ovo 3 g, glycerolum, natrii oleas, aqua q.s. ad emulsionem pro 250 ml.
III) Aminosäurenlösung: isoleucinum 2.34 g, leucinum 3.13 g, lysinum anhydricum 2.26 g ut lysini hydrochloridum, methioninum 1.96 g, aqua ad iniectabilia q.s. ad solutionem pro 400 ml.
.
I) et II) et III) corresp.: aminoacida 32 g/l, acetas 32 mmol/l, acidum citricum monohydricum, in emulsione recenter mixta 1250 ml.
Corresp. 4000 kJ.'
    result = Calc.new('Nutriflex Lipid peri, Infusionsemulsion, 1250ml', nil, nil,
                      'glucosum anhydricum, zinci acetas dihydricus, isoleucinum, leucinum',
                      text
                      )
    specify { expect(result.compositions.first.name).to eq  'Glucosum Anhydricum' }
    specify { expect(result.compositions.first.qty).to eq  80.0}
    specify { expect(result.compositions.first.unit).to eq  'g/250 ml'}
    specify { expect(result.compositions.first.label).to eq 'I Glucoselösung' }

    # from II)
    lecithinum =  result.compositions.find{ |x| x.name.match(/lecithinum/i) }
    specify { expect(lecithinum).not_to eq nil}
    if lecithinum
      specify { expect(lecithinum.name).to eq  'Lecithinum Ex Ovo' }
      specify { expect(lecithinum.qty).to eq   3.0}
      specify { expect(lecithinum.unit).to eq  'g/250 ml'}
      specify { expect(lecithinum.label).to eq 'II Fettemulsion' }
    end

    # From III
    leucinum =  result.compositions.find{ |x| x.name.eql?('Leucinum') and x.label.match(/^III /) }
    specify { expect(leucinum).not_to eq nil}
    if leucinum
      specify { expect(leucinum.name).to eq  'Leucinum' }
      specify { expect(leucinum.qty).to eq  3.13}
      specify { expect(leucinum.unit).to eq  'g/400 ml'}
      specify { expect(leucinum.label).to eq 'III Aminosäurenlösung' }
    end
    leucinum_I =  result.compositions.find{ |x| x.name.eql?('Leucinum') and x.label.match(/^I /) }
    specify { expect(leucinum_I).to eq nil}
    leucinum_II =  result.compositions.find{ |x| x.name.eql?('Leucinum') and x.label.match(/^II /) }
    specify { expect(leucinum_II).to eq nil}
  end

  context 'find correct result compositions' do
    result = Calc.new(nil, nil, nil, 'rutosidum trihydricum, aescinum', 'rutosidum trihydricum 20 mg, aescinum 25 mg, aromatica, excipiens pro compresso.')
    specify { expect(result.compositions.first.name).to eq  'Rutosidum Trihydricum' }
    specify { expect(result.compositions.first.qty).to eq  20}
    specify { expect(result.compositions.first.unit).to eq  'mg'}
    specify { expect(result.compositions[1].name).to eq  'Aescinum' }
    specify { expect(result.compositions[1].qty).to eq  25}
    specify { expect(result.compositions[1].unit).to eq  'mg'}
  end

  context 'find correct result for Inflora, capsule' do
    info = Calc.new(tst_infloran.name_C, tst_infloran.package_size_L, tst_infloran.einheit_M, tst_infloran.active_substance_0, tst_infloran.composition_P)
    # specify { expect(tst_infloran.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/00679/seq/02/pack/012' }
    specify { expect(info.galenic_form.description).to eq 'capsule' }
    skip { expect(info.galenic_group.description).to eq  'Injektion/Infusion' }
    specify { expect(info.pkg_size).to eq '2x10' }
    specify { expect(info.selling_units).to eq  20 }
    skip { expect(info.measure).to eq  '0' }
    bifidobacterium =  info.compositions.find{ |x| x.name.match(/Bifidobacterium/i) }
    specify { expect(bifidobacterium).not_to eq nil}
    if bifidobacterium
      specify { expect(bifidobacterium.name).to eq  'Bifidobacterium Infantis Min.' }
      skip { expect(bifidobacterium.qty).to eq  '10^9'}
      skip { expect(bifidobacterium.unit).to eq  'CFU'}
    end
    e_127 =  info.compositions.find{ |x| x.name.match(/E 127/i) }
    skip { expect(e_127).not_to eq nil}
    if e_127
      specify { expect(e_127.name).to eq  'E 127' }
      specify { expect(e_127.unit).to eq  ''}
    end
  end

  context 'find correct result for Cardio-Pulmo-Rénal Sérocytol, suppositoire' do
    info = Calc.new(tst_cardio_pumal.name_C, tst_cardio_pumal.package_size_L, tst_cardio_pumal.einheit_M, tst_cardio_pumal.active_substance_0, tst_cardio_pumal.composition_P)
    specify { expect(info.galenic_form.description).to eq 'suppositoire' }
    specify { expect(info.galenic_group.description).to eq  'unbekannt' }
    specify { expect(info.pkg_size).to eq '3' }
    specify { expect(info.selling_units).to eq  3 }
    specify { expect(info.name).to eq 'Cardio-Pulmo-Rénal Sérocytol, suppositoire'}
    specify { expect(info.measure).to eq  'Suppositorien' }
    globulina =  info.compositions.find{ |x| x.name.match(/porcins|globulina/i) }
    specify { expect(globulina).not_to eq nil}
    if globulina
      specify { expect(globulina.name).to eq  'Globulina Equina (immunisé Avec Coeur, Tissu Pulmonaire, Reins De Porcins)' }
      specify { expect(globulina.qty).to eq  8.0}
      specify { expect(globulina.unit).to eq  'mg'}
    end
    e_216 =  info.compositions.find{ |x| x.name.match(/E 216/i) }
    specify { expect(e_216).not_to eq nil}
    if e_216
      specify { expect(e_216.name).to eq  'E 216' }
      specify { expect(e_216.unit).to eq  ''}
    end
    e_218 =  info.compositions.find{ |x| x.name.match(/E 218/i) }
    specify { expect(e_218).not_to eq nil}
  end

end
