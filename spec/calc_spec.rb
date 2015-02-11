# encoding: utf-8

require 'pp'
require 'spec_helper'
require "rexml/document"
include REXML
require "#{Dir.pwd}/lib/oddb2xml/calc"
include Oddb2xml

describe Oddb2xml::Calc do

  before(:each) do
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.xml')))
    FileUtils.rm(Dir.glob(File.join(Oddb2xml::WorkDir, '*.csv')))
  end

  context 'should return correct value for liquid' do
    pkg_size_L = '1 x 5 x 200'
    einheit_M  = 'ml'
    part_from_name_C = 'Infusionslösung / Injektionslösung'

    result = Calc.get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
    specify { expect(result).to eq 5 }
  end

  context 'should return correct value for W-Tropfen' do
    pkg_size_L = '10'
    einheit_M  = 'ml'
    part_from_name_C = nil
    result = Calc.get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
    specify { expect(result).to eq 10 }
  end

  context 'should return correct value for tablet' do
    pkg_size_L = '1 x 25'
    einheit_M  = 'Tablette(n)'
    part_from_name_C = 'comprimés'

    result = Calc.get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
    specify { expect(result).to eq 25 }
  end

  context 'should return correct value for Perindopril' do
    pkg_size_L = '90'
    einheit_M  = 'Tablette(n)'
    part_from_name_C = 'comprimés pelliculés'

    result = Calc.get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
    specify { expect(result).to eq 90 }
  end


  context 'should return correct value for mutagrip' do
    pkg_size_L = '10 x 0.5 ml'
    einheit_M  = 'Fertigspritze(n)'
    part_from_name_C = 'Suspension zur Injektion'

    result = Calc.get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
    res = Calc.report_conversion
    specify { expect(res.class).to eq Array }
    specify { expect(res.first.class).to eq String }
    specify { expect(result).to eq 10 }
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

  # after each name you find the column of swissmedic_package.xlsx file
  TestExample = Struct.new("TestExample", :test_description, :iksnr_A, :seqnr_B, :pack_K, :name_C, :package_size_L, :einheit_M, :composition_P  ,
                           :values_to_compare)

  tst_mutagrip = TestExample.new('Test Mutagrip (Fertigspritzen)',
                                373, 23, 10, "Mutagrip, Suspension zur Injektion",
                                '10 x 0.5 ml', 'Fertigspritze(n)',
                                'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 10,
                                  :measure => '0.5 ml',
                                  # :count => 10, :multi => 1,  :dose => ''
                                  }
                            )

  tst_diamox = TestExample.new('Diamox. Tabletten',
                                21191, 1, 19, 'Diamox, comprimés',
                                '1 x 25', 'Tablette(n)',
                                'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml.',
                                { :selling_units => 25, :measure => '250 mg',
                                  #:count => 25, :multi => 1
                                  }
                              )

  tst_naropin = TestExample.new('Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml',
                             54015, 01, 100, "Naropin 0,2 %, Infusionslösung / Injektionslösung",
                             '1 x 5 x 100', 'ml',
                             'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                             { :selling_units => 5, :measure => '100 ml',
                               #:count => 5, :multi => 1
                               }
                            )
# 00372 1 Muscles lisses Sérocytol, suppositoire  Sérolab, société anonyme  08.07.  J06AA Blutprodukte  26.04.10  26.04.10  25.04.15  001 3 Suppositorien B globulina equina (immunisé avec muscles lisses porcins) globulina equina (immunisé avec muscles lisses porcins) 8 mg, propylenglycolum, conserv.: E 216, E 218, excipiens pro suppositorio. "Traitement immunomodulant  selon le Dr Thomas
# Possibilités d'emploi voir information professionnelle"
  # measure 8 mg
  # nur ampullen

# 00638 1 Infanrix DTPa-IPV, Injektionssuspension GlaxoSmithKline AG  08.08.  J07CA02 Impfstoffe  20.08.99  20.08.99  19.08.19  001 1 Spritze(n)  B toxoidum diphtheriae, toxoidum tetani, toxoidum pertussis, haemagglutininum filamentosum (B. pertussis), pertactinum (B. pertussis), virus poliomyelitis typus 1 inactivatum (Mahoney), virus poliomyelitis typus 2 inactivatum (MEF1), virus poliomyelitis typus 3 inactivatum (Saukett) toxoidum diphtheriae min. 30 U.I., toxoidum tetani min. 40 U.I., toxoidum pertussis 25 µg, haemagglutininum filamentosum (B. pertussis) 25 µg, pertactinum (B. pertussis) 8 µg, virus poliomyelitis typus 1 inactivatum (Mahoney) 40 U.I., virus poliomyelitis typus 2 inactivatum (MEF1) 8 U.I., virus poliomyelitis typus 3 inactivatum (Saukett) 32 U.I., aluminium ut aluminii hydroxidum hydricum ad adsorptionem, natrii chloridum, medium199, residui: kalii chloridum et dinatrii phosphas anhydricus et kalii phosphates et polysorbatum 80 et glycinum et formaldehydum et neomycini sulfas et polymyxini B sulfas nihil, aqua ad iniectabilia ad suspensionem pro 0.5 ml.  Grundimmunisierung und Auffrischimpfung, gegen Diphtherie, Tetanus, Pertussis und Poliomyelitis, ab dem vollendeten 2. Lebensmonat
# mehrere
  class TestExample
    def url
      "http://ch.oddb.org/de/gcc/drug/reg/#{sprintf('%05d' % iksnr_A)}/seq/#{sprintf('%02d' % seqnr_B)}/pack/#{sprintf('%03d' % pack_K)}"
    end
  end
  [tst_naropin,
   tst_diamox,
   tst_mutagrip,
  ].each {
    |tst|
      context "verify #{tst.iksnr_A}: #{tst.url}" do
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
    specify { expect(info.measure).to eq  '100 ml' }
    # specify { expect(info.count).to eq  5 }
    # specify { expect(info.multi).to eq  1 }
    # specify { expect(info.addition).to eq 0 }
    # specify { expect(info.scale).to eq  1 }
  end

  context 'convert mg/l into ml/mg for solutions' do
    result = Calc.new('50', 'g/l')
    specify { expect(result.measure).to eq  50 }
  end

  run_time_options = '--calc --skip-download'
  context "when passing #{run_time_options}" do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!(run_time_options.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    src = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'swissmedic_package-galenic.xlsx'))
    specify { expect(File.exists?(src)).to eq true }
    dest =  File.join(Oddb2xml::WorkDir, 'swissmedic_package.xlsx')
    FileUtils.cp(src, dest, { :verbose => true, :preserve => true})
    specify { expect(File.exists?(dest)).to eq true }
    it 'should create a correct xml and a csv file' do
      cli.run
      expected = [
        'oddb_calc.xml',
        'oddb_calc.csv',
      ].each { |file| full = File.join(Oddb2xml::WorkDir, file)
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


