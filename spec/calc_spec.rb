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

  TestExample = Struct.new("TestExample", :test_description, :iksnr, :seqnr, :pack, :name, :package_size, :einheit, :composition,
                           :values_to_compare)

  tst_mutagrip = TestExample.new('Test Mutagrip (Fertigspritzen)',
                                373, 23, 10, "Mutagrip, Suspension zur Injektion",
                                '10 x 0.5 ml', 'Fertigspritze(n)',
                                'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                                { :selling_units => 10 , :count => 10, :multi => 1, :measure => '0.5 ml'}
                            )

  tst_diamox = TestExample.new('Diamox. Tabletten',
                                21191, 1, 19, 'Diamox, comprimés',
                                '1 x 25', 'Tablette(n)',
                                'haemagglutininum influenzae A (H1N1) (Virus-Stamm A/California/7/2009 (H1N1)-like: reassortant virus NYMC X-179A) 15 µg, haemagglutininum influenzae A (H3N2) (Virus-Stamm A/Texas/50/2012 (H3N2)-like: reassortant virus NYMC X-223A) 15 µg, haemagglutininum influenzae B (Virus-Stamm B/Massachusetts/2/2012-like: B/Massachusetts/2/2012) 15 µg, natrii chloridum, kalii chloridum, dinatrii phosphas dihydricus, kalii dihydrogenophosphas, residui: formaldehydum max. 100 µg, octoxinolum-9 max. 500 µg, ovalbuminum max. 0.05 µg, saccharum nihil, neomycinum nihil, aqua ad iniectabilia q.s. ad suspensionem pro 0.5 ml.',
                                { :selling_units => 25, :count => 25, :multi => 1, :measure => 'Tablette(n)'}
                              )

  tst_naropin = TestExample.new('Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml',
                             54015, 01, 100, "Naropin 0,2 %, Infusionslösung / Injektionslösung",
                             '1 x 5 x 100', 'ml',
                             'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                             { :selling_units => 5, :count => 5, :multi => 1, :measure => '100 ml'}
                            )
  class TestExample
    def url
      "http://ch.oddb.org/de/gcc/drug/reg/#{sprintf('%05d' % iksnr)}/seq/#{sprintf('%02d' % seqnr)}/pack/#{sprintf('%03d' % pack)}"
    end
  end

  [tst_naropin,
   tst_diamox,
   tst_mutagrip,
  ].each {
    |tst|
      context "verify #{tst.iksnr}: #{tst.url}" do
        info = Calc.new(tst.name, tst.package_size, tst.einheit, tst.composition)
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
    info = Calc.new(tst_naropin.name, tst_naropin.package_size, tst_naropin.einheit, tst_naropin.composition)
    specify { expect(tst_naropin.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/54015/seq/01/pack/100' }
    specify { expect(info.galenic_form.description).to eq  'Infusionslösung/Injektionslösung' }
    specify { expect(info.galenic_group.description).to eq  'unbekannt' }
    specify { expect(info.pkg_size).to eq '1 x 5 x 100' }
    specify { expect(info.count).to eq  5 }
    specify { expect(info.multi).to eq  1 }
    specify { expect(info.measure).to eq  '100 ml' }
    specify { expect(info.addition).to eq 0 }
    specify { expect(info.scale).to eq  1 }
  end

  context 'convert mg/l into ml/mg for solutions' do
    result = Calc.new('50', 'g/l')
    specify { expect(result).to eq  'xxx' }
  end if false

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

end

