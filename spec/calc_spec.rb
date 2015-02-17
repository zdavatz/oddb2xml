# encoding: utf-8

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
  TestExample = Struct.new("TestExample", :test_description, :iksnr_A, :seqnr_B, :pack_K, :name_C, :package_size_L, :einheit_M, :composition_P  ,
                           :values_to_compare)

  tst_fluorglukose = TestExample.new('Fluorglukose',
                                51908, 2, 16, "2-Fluorglukose (18-F), Injektionslösung",
                                '0,1 - 80', 'GBq',
                                'fludeoxyglucosum(18-F) zum Kalibrierungszeitpunkt 0.1-8 GBq, dinatrii phosphas dihydricus, natrii dihydrogenophosphas dihydricus, natrii chloridum, antiox.: natrii thiosulfas 1.3-1.9 mg, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 1,
                                  :measure => 'GBq',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_bicaNova = TestExample.new('bicaNova',
                                58277, 1, 1, "bicaNova 1,5 % Glucose, Peritonealdialyselösung",
                                '1500 ml', '',
                                'I) et II) corresp.: natrii chloridum 5.5 g, natrii hydrogenocarbonas 3.36 g, calcii chloridum dihydricum 184 mg, magnesii chloridum hexahydricum 102 mg, glucosum anhydricum 15 g ut glucosum monohydricum, aqua ad iniectabilia q.s. ad solutionem pro 1000 ml.',
                                { :selling_units => 1500,
                                  :measure => 'ml',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_kamillin = TestExample.new('Kamillin Medipharm, Bad',
                                43454, 1, 101, "Kamillin Medipharm, Bad",
                                '25 x 40', 'ml',
                                'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml.',
                                { :selling_units => 25,
                                  :measure => 'ml',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_infloran = TestExample.new('Test Infloran, capsule',
                                679, 2, 12, "Infloran, capsule",
                                '2x10', 'Kapsel(n)',
                                'lactobacillus acidophilus cryodesiccatus min. 10^9 CFU, bifidobacterium infantis min. 10^9 CFU, color.: E 127, E 132, E 104, excipiens pro capsula.',
                                { :selling_units => 20,
                                  :measure => 'Kapsel(n)',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )
  tst_mutagrip = TestExample.new('Test Mutagrip (Fertigspritzen)',
                                373, 23, 10, "Mutagrip, Suspension zur Injektion",
                                '10 x 0.5 ml', 'Fertigspritze(n)',
                                'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 10,
                                  :measure => 'Fertigspritze(n)',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )

  tst_diamox = TestExample.new('Diamox. Tabletten',
                                21191, 1, 19, 'Diamox, comprimés',
                                '1 x 25', 'Tablette(n)',
                                'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml.',
                                { :selling_units => 25,
                                  :measure => 'Tablette(n)',
                                  #:count => 25, :multi => 1
                                  }
                              )

  tst_naropin = TestExample.new('Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml',
                             54015, 01, 100, "Naropin 0,2 %, Infusionslösung / Injektionslösung",
                             '1 x 5 x 100', 'ml',
                             'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                             { :selling_units => 5,
                               :measure => 'ml',
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
        info = Calc.new(tst.name_C, tst.package_size_L, tst.einheit_M, tst.composition_P)
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
    info = Calc.new(tst_naropin.name_C, tst_naropin.package_size_L, tst_naropin.einheit_M, tst_naropin.composition_P)
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
    info = Calc.new(tst_infloran.name_C, tst_infloran.package_size_L, tst_infloran.einheit_M, tst_infloran.composition_P)
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
      doc = REXML::Document.new xml
      gtin = '7680540151191'
      tst_naropin.values_to_compare.each{
        | key, value |
          result = XPath.match( doc, "//ARTICLE[GTIN='#{gtin}']/#{key.to_s.upcase}").first.text
          puts "Testing key #{key.inspect} #{value.inspect} against #{result} seems to fail" unless result == value.to_s
          result.should eq value.to_s
      }
   end
  end
  context 'find correct result for Kamillin' do
    info = Calc.new(tst_kamillin.name_C, tst_kamillin.package_size_L, tst_kamillin.einheit_M, tst_kamillin.composition_P)
    specify { expect(info.selling_units).to eq  25 }
  end

  context 'find correct result for bicaNova' do
    info = Calc.new(tst_bicaNova.name_C, tst_bicaNova.package_size_L, tst_bicaNova.einheit_M, tst_bicaNova.composition_P)
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

end

  missing_tests = "
1. Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml
1 x 5 x 100

2. Hier muss man schauen ob es sich um ein Injektionspräparat handelt
oder um ein Tabletten, Kapseln, etc.
2 x 100

a) Beim Injektionspräparat sind es wohl 2 Ampullen à 100 ml
b) Bei den Tabletten sind es wohl total 200 Stück.

3. Das ist ein klarer Fall von einer Lösung, idR wohl Ampullen:
10 x 2 mL

4. Das sind 10 Teebeutel à 1.5g
10 x 1.5g

5. Das sind 20 mg Wirkstoff  in einer 10 ml Lösung. 'ml' steht dann in
der Spalte M
20 mg / 10. Könnte auch so geschrieben sein: 1000mg/50ml oder auch so:
1 x 50mg/100ml

6. 1x1 Urethrastab ist einmal ein Stab. ;)

7. 30 (3x10) sind Total 30 Tabletten verteilt auf 3 Blister à 10
Tabletten. Könnte auch so geschrieben sein: 84 (4 x 21)

8. 10 + 10 Das sind zehn Ampullen mit einer Trockensubstanz und
nochmals zehn Ampullen mit der Lösung. Das ist ein Kombipräparat.

9. 20 x 0.5 g sind zwanzig Einzeldosen à 0.5g.

10. Das ist eine Gaze: 1 x 7,5 x 10 cm

11. 100 (2 x 50) das sind total 100 Beutel, d.h. zweimal fünfzig Stück.

12. 0,1 - 80 GBq Das ist eine Injektionslösung.

13. 10 cm x 10 cm imprägnierter Verband. Das ist eine Salbengaze.

14. Das ist ein Sauerstofftank: 9000-10000 l

15. 360x1 Das ist eine Packung mit 360 Durchstechflaschen.

16. 5 + 5 Das sind 10 Durchstechflaschen à 1 Stück.
"


