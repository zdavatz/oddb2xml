# encoding: utf-8

require 'pp'
require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/galenic"
include Oddb2xml

describe Oddb2xml::Galenic do

  context 'should find galenic_group for Kaugummi' do
    result = Galenic.get_galenic_group('Kaugummi')
    specify { expect(result.class).to eq  GalenicGroup }
    specify { expect(result.description).to eq 'Kaugummi' }
  end

  context 'should find galenic_form for Infusionslösung / Injektionslösung' do
    value = 'Infusionslösung / Injektionslösung'
    result = Galenic.get_galenic_form(value)
    specify { expect(result.class).to eq  GalenicForm }
    specify { expect(result.description).to eq 'Infusionslösung/Injektionslösung' }
  end

  context 'should return galenic_group unknown for galenic_group Dummy' do
    result = Galenic.get_galenic_group('Dummy')
    specify { expect(result.class).to eq  GalenicGroup }
    specify { expect(result.oid).to eq  1 }
    specify { expect(result.descriptions['de']).to eq 'unbekannt' }
    specify { expect(result.description).to eq 'unbekannt' }
  end

  TestExample = Struct.new("TestExample", :test_description, :iksnr, :seqnr, :pack, :package_size, :einheit, :name, :composition)

  example1 = TestExample.new('Das ist eine Injektionslösung von einer Packung mit 5 x 100 ml',
                             54015, 01, 100, '1 x 5 x 100', 'ml',
                             "Naropin 0,2 %, Infusionslösung / Injektionslösung",
                             'ropivacaini hydrochloridum 2 mg, natrii chloridum, aqua ad iniectabilia q.s. ad solutionem pro 1 ml.',
                            )
  class TestExample
    def url
      "http://ch.oddb.org/de/gcc/drug/reg/#{sprintf('%05d' % iksnr)}/seq/#{sprintf('%02d' % seqnr)}/pack/#{sprintf('%03d' % pack)}"
    end
  end

  context 'find correct result for Injektionslösung' do
    info = Galenic.new(example1.name, example1.package_size, example1.einheit, example1.composition)
    specify { expect(example1.url).to eq 'http://ch.oddb.org/de/gcc/drug/reg/54015/seq/01/pack/100' }
    specify { expect(info.galenic_form.description).to eq  'Infusionslösung/Injektionslösung' }
    specify { expect(info.galenic_group.description).to eq  'Injektion/Infusion' }
    specify { expect(info.count).to eq  1 }
    specify { expect(info.multi).to eq  5 }
    specify { expect(info.measure).to eq  '100 ml' }
    specify { expect(info.addition).to eq 0 }
    specify { expect(info.scale).to eq  1 }
    specify { expect(info.pkg_size).to eq '1 x 5 x 100' }
  end

  context 'convert mg/l into ml/mg for solutions' do
    result = Galenic.new('50', 'g/l')
    specify { expect(result).to eq  'xxx' }
  end if false

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

