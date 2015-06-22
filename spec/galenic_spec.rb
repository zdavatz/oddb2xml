# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'
require 'parslet/convenience'
require 'csv'

RunAllParsingExamples = false #  RunAllParsingExamples /travis|localhost/i.match(hostname) != nil # takes about one minute to run

galenic_tests = {

  '1001 Blattgrün Dragées' =>  { :prepation_name=>'1001 Blattgrün ', :galenic_form=> 'Dragées' },
  '3TC 150 mg, Filmtabletten'                 => { :prepation_name=>'3TC 150 mg', :galenic_form=>'Filmtabletten' },
  'Acetocaustin, Lösung'                      => { :prepation_name=>'Acetocaustin', :galenic_form=>'Lösung' },
  'Alustal 3-Bäume, Injektionssuspension' =>    {:prepation_name=>'Alustal 3-Bäume', :galenic_form=> 'Injektionssuspension'  },
  'Alustal Bäume, Injektionssuspension' =>    {:prepation_name=>'Alustal Bäume', :galenic_form=> 'Injektionssuspension'  },
  'Amoxicillin Streuli, Granulat zur Herstellung einer Suspension' => { :prepation_name=>'Amoxicillin Streuli', :galenic_form=> 'Granulat zur Herstellung einer Suspension', },
  'Arkocaps Passiflore/Passionsblume, 300 mg, capsules'=> { :prepation_name=>'Arkocaps Passiflore/Passionsblume', :galenic_form=>'capsules' },
  'Atenativ, Antithrombin III 500 I.E., Injektionspräparat' => { :prepation_name=>'Atenativ', :galenic_form=>'Injektionspräparat' },
  'Atorvastatin Helvepharm, 10 mg Filmtabletten' => {:prepation_name=>'Atorvastatin Helvepharm', :galenic_form=> 'Filmtabletten'  },
  'Atorvastax-Drossapharm 20 mg'              => {:prepation_name=> 'Atorvastax-Drossapharm 20 mg', :galenic_form=> nil},
  'Co-Losartan Spirig HC 50/12,5 mg'   => { :prepation_name=>'Co-Losartan Spirig HC 50/12,5 mg', :galenic_form=> nil, },
  'Dicloabak 0,1% Augentropfen' => { :prepation_name=>'Dicloabak 0,1% ', :galenic_form=>'Augentropfen' },
  'Kaliumchlorid 14,9 % B. Braun, Zusatzampullen'=> { :prepation_name=>'Kaliumchlorid 14,9 % B. Braun', :galenic_form=>'Zusatzampullen' },
  'Methrexx 7.5 mg / 0.75 ml,Injektionslösung in Fertigspritzen'=> { :prepation_name=>'Methrexx 7.5 mg / 0.75 ml', :galenic_form=> 'Injektionslösung in Fertigspritzen' },
  'Nitroderm TTS 10' => { :prepation_name=>'Nitroderm TTS 10', :galenic_form=> nil },
  'Ondansetron Labatec, 8mg/4ml, concentré pour perfusion' =>   {:prepation_name=>'Ondansetron Labatec', :galenic_form=> 'concentré pour perfusion'  },
  'Paronex 20, Filmtabletten'=> { :prepation_name=>'Paronex 20', :galenic_form=>'Filmtabletten' },
  'Physioneal 35 Clear-Flex 3,86 % Peritonealdialyselösung' => { :prepation_name=>'Physioneal 35 Clear-Flex 3,86 % ', :galenic_form=>'Peritonealdialyselösung' },
  'Phytopharma foie et bile capsules/Leber-Galle Kapseln'  => { :prepation_name=>'Phytopharma foie et bile capsules', :galenic_form=> 'Leber-Galle Kapseln' },
  'Plak-out Spray 0,1 %' => { :prepation_name=>'Plak-out Spray 0,1 %', :galenic_form=> nil },
  'Sandostatin 0,2 mg/mL, Injektionslösung'   => { :prepation_name=>'Sandostatin 0,2 mg/mL', :galenic_form=>'Injektionslösung' },
  'Sulfure de Rhénium (186Re)-RE-186-MM-1 Cis bio International,       Suspension' => { :prepation_name=>'Sulfure de Rhénium (186Re)-RE-186-MM-1 Cis bio International', :galenic_form=> 'Suspension' },
  'Tramal 100, Injektionslösung (i.m., i.v.)' => { :prepation_name=>'Tramal 100', :galenic_form=>'Injektionslösung (i.m., i.v.)' },
  'Uman Albumin Kedrion 20%'  => { :prepation_name=>'Uman Albumin Kedrion 20%', :galenic_form=> nil },
  }

  todo = %(
Testlösung zur Allergiediagnose Teomed Kaninchen  (Fell) Lösung
Testlösung zur Allergiediagnose Teomed Hund   (Haare) Lösung
Pandemrix   (Pandemic Influenza Vaccine H1N1)
Phytopharma dragées pour la détente et le sommeil   / Entspannungs- und Schlafdragées
Phytopharma dragées pour le coeur   / Herz Dragées
Best Friend Katzenhalsband  / Katzenhalsband Reflex ad us.vet.
Amlodipin Helvepharm  10 Tabletten
Salbu Orion Easyhaler 100 ug Inhalationspulver
TISSEEL 10 ml 2 Fertigspritzen
TISSEEL 2 ml  2 Fertigspritzen
TISSEEL 4 ml  2 Fertigspritzen
Norprolac Starter-pack  25 ug + 50 ug, Tabletten
Phostal 5-Gräser  4-Getreidemischung 10IR, Injektionssuspension
Alustal 5-Gräser  4-Getreidemischung Kombipackung, Injektionssuspension
Staloral Beifuss  5-Gräser 100IR, Injektionssuspension
Phostal Beifuss 5-Gräser 10IR, Injektionssuspension
Alustal Beifuss 5-Gräser 10IR, Injektionssuspension
Seebri Breezhaler 50 Mikrogramm, Pulver zur Inhalation, Hartkapseln
Nplate  500 mcg Pulver und Lösungsmittel zur Herstellung einer Injektionslösung
Bayvantage ad us.vet. 80 für Katzen, Lösung
Ondansetron-Teva  8mg, Filmtabletten
Soluprick SQ 3-Bäumemischung (Alnus glutinosa Betula verrucosa, Corylus avellana), Lösung
BicaVera 2,3% Glucose Calcium, Peritonealdialyselösung
Telfastin Allergo 120 comprimés pelliculés 120 mg
Multaq  comprimés pelliculés de 400 mg de dronédarone
KCL 7,45% Sintetica concentrato per soluzione per infusione (fiala di 20 ml)
Alk7 Frühblühermischung Depotsuspension zur s.c. Injektion "1 Flasche B"
Alk7 Gräsermischung und Roggen  Depotsuspension zur s.c. Injektion "1 Flasche B"
Relenza 5 mg  Disk (Pulverinhalation)
Ventolin  Dosier-Aerosol (FCKW-frei)
Axotide 0,125 mg  Dosier-Aerosol (FCKW-frei)
Axotide 0,250 mg  Dosier-Aerosol (FCKW-frei)
Axotide 0,050 mg  Dosier-Aerosol (FCKW-frei)
Serevent  Dosier-Aerosol FCKW-frei
Bronchialpastillen  Dr. Welti
Conoxia Druckgasflasche 300 bar
Staloral Pollen 3-Bäume Esche 100IR, Lösung zur sublingualen Anwendung
Staloral Pollen Birke Esche 100IR, Lösung zur sublingualen Anwendung
Phostal Birke Esche 10IR, Injektionssuspension
Alustal Birke Esche 10IR, Injektionssuspension
Alustal 3-Bäume Esche Kombipackung , Injektionssuspension
Phostal 3-Bäume Esche Kombipackung, Injektionssuspension
Fisherman's Friend  Eucalyptus-Menthol, sans sucre, avec sorbitol, nouvelle formule, pastilles
Victoza 6 mg/ml Fertigpen (Triple-Dose)
Fluimucil Erkältungshusten  Fertigsirup mit Himbeergeschmack
Rebif Neue Formulierung 22  Fertigspritzen, Injektionslösung
Rebif Neue Formulierung 44  Fertigspritzen, Injektionslösung
Rebif Neue Formulierung 8.8 Fertigspritzen, Injektionslösung
Bonherba rocks Kräuterzucker, Kräuterbonbon 2,7   g
Ricola Kräuter, Kräuterbonbons ohne Zucker, 2,5   g
Testlösung zur Allergiediagnose Teomed Ei ganz,  Lösung
Helena's Fenchelfruchttee ganze Droge
Intron A 10 Mio. I.E./1 mL  gebrauchsfertige, HSA-freie Injektionslösung
Picato  Gel 500 mcg/g
Duodopa Gel zur intestinalen Anwendung
Weleda Arnica-Gel Gel, anthroposophisches Arzneimittel
Burgerstein Vitamin E-Kapseln 400   I.E.
Solmucol 10 % local i.v., i.m., soluzione iniettabile
Synacthen (i.m. i.v.), Injektionslösung
Nutriflex Lipid plus ohne Elektrolyte Infusionsemulsion 1250ml
Nutriflex Omega plus  Infusionsemulsion 1875 ml
SmofKabiven Infusionsemulsion 1970 ml
SmofKabiven EF  Infusionsemulsion 1970 ml
Nutriflex Omega special Infusionsemulsion 2500 ml
Nutriflex Lipid special ohne Elektrolyte  Infusionsemulsion 2500ml
Nutriflex Lipid peri  Infusionsemulsion, 1250ml
Nutriflex Lipid plus  Infusionsemulsion, 1250ml
Nutriflex Lipid special Infusionsemulsion, 1250ml
Dexdor  Infusionskonzentrat 1000ug/10ml
Peditrace Infusionskonzentrat, Zusatzampulle
M Classic Eucalyptus Gummipastillen zuckerfrei
M Classic Halsbonbons   zuckerfrei
Salbisan Halspastillen  zuckerfrei
Madopar LIQ 125 Tabletten zur Herstellung einer Suspension zum Einnehmen
Anginazol forte tablettes à sucer
Tisane provençale No 1  tisane laxative, plantes coupées
)

describe ParseGalenicForm do
  context "parse_column_c should work" do
    name, gal_form =  ParseGalenicForm.from_string(galenic_tests.first.first)
    specify { expect(name).to eq galenic_tests.first.last[:prepation_name].strip }
    specify { expect(gal_form).to eq galenic_tests.first.last[:galenic_form] }
  end

  galenic_tests.each{
    |string, expected|
      context "should handle #{string}" do
        name, form = ParseGalenicForm.from_string(string)
        specify { expect(name).to eq expected[:prepation_name].strip }
        specify { expect(form).to eq expected[:galenic_form] }
      end
  }

  { 'Phytopharma dragées pour le coeur / Herz Dragées' =>
    { :prepation_name=>'Phytopharma dragées pour le coeur', :galenic_form=> 'Herz Dragées' },
    }.each {
    |string, expected|
      context "should handle #{string}" do
        name, form = ParseGalenicForm.from_string(string)
        specify { expect(name).to eq expected[:prepation_name].strip }
        specify { expect(form).to eq expected[:galenic_form] }
      end
  }
end

def test_one_string(parser, string, expected)
  res1 = parser.parse_with_debug(string)
  res1.delete(:qty)   if res1
  res1.delete(:unit)  if res1
  stringified = res1 ? res1.to_s.gsub(/@\d+/, '') : nil
  if res1 == nil or ! stringified.eql? expected.to_s
    puts "Failed testing: #{string}"; binding.pry
  end
  expect(stringified).to eq expected.to_s if expected
end

if true then describe GalenicFormParser do
  let(:parser) { GalenicFormParser.new }
  context "identifier parsing" do
    let(:galenic_parser) { parser.galenic }
    let(:qty_unit_parser) { parser.qty_unit }

    galenic_tests.each{
        |string, expected|
        puts string
        it "parses galenic #{string}" do
          test_one_string(galenic_parser, string, expected)
        end
    }
  end
end end

if RunAllParsingExamples then describe GalenicFormParser do
  context "should parse all lines in #{File.basename(AllColumn_C_Lines)}" do
    let(:galenic_parser) { GalenicFormParser.new.galenic }
    ausgabe = {}
    count = 0
    galenic_parser = GalenicFormParser.new.galenic
    IO.readlines(AllColumn_C_Lines).each {
      |string|
        count += 1
        # break if count > 100
        puts string.strip
        it "parses galenic #{string}" do
          res1 = galenic_parser.parse_with_debug(string.strip)
          if res1
            ausgabe[res1[:prepation_name].to_s] = res1[:galenic_form] if res1
          else
            puts "Failed testing: #{string}"
            pp res1
#            binding.pry
          end
        end
    }
    csv_name = File.join(Oddb2xml::WorkDir, 'galenic.csv')
    at_exit do CSV.open(csv_name, "w+", :col_sep => ';') do |csv|
        ausgabe.each do |key, value|
          csv <<  [key, value]
        end
      end
    end
  end
end end

describe GalenicFormParser do
  let(:parser) { GalenicFormParser.new }
  context "gal_form parsing" do
    let(:gal_form_parser) { parser.gal_form }

    should_pass = [
      ', Lösung',
      ', 100mg Lösung',
      'Lösung',
      '100mg Lösung',
      'Injektionslösung (i.m., i.v.)',
      ].each {
        |id|
        it "parses gal_form #{id}" do
          expect(gal_form_parser).to     parse(id)
        end
      }
    should_not_pass = [
      ].each {
        |id|
        it "parses gal_form #{id}" do
          expect(gal_form_parser).to_not   parse(id)
        end
      }
  end
  context "name_gal_form parsing" do
    let(:name_gal_form_parser) { parser.name_gal_form }

    should_pass = [
      'Dicloabak 0,1% Augentropfen',
      '35 Clear-Flex 3,86 % Peritonealdialyselösung',
      'Esmeron 100mg/10ml Injektionslösung',
      ].each {
        |id|
        it "parses name_gal_form #{id}" do
          expect(name_gal_form_parser).to     parse(id)
        end
      }
    should_not_pass = [
      ].each {
        |id|
        it "parses name_gal_form #{id}" do
          expect(name_gal_form_parser).to_not   parse(id)
        end
      }
  end

  context "prepation_name parsing" do
    let(:prepation_name_parser) { parser.prepation_name }

    should_pass = [
      'name',
      'name more',
      'name more and more',
      'Dicloabak 0,1% Augentropfen',
      ].each {
        |id|
        it "parses prepation_name #{id}" do
          expect(prepation_name_parser).to     parse(id)
        end
      }
    should_not_pass = [
      ].each {
        |id|
        it "parses prepation_name #{id}" do
          expect(prepation_name_parser).to_not   parse(id)
        end
      }
  end
  context "standard_galenic parsing" do
    let(:standard_galenic_parser) { parser.standard_galenic }

    should_pass = [
     'Antithrombin III 500 I.E., Injektionspräparat',
      'Ondansetron Labatec, 8mg/4ml, concentré pour perfusion',
      ].each {
        |id|
        it "parses standard_galenic #{id}" do
          expect(standard_galenic_parser).to     parse(id)
        end
      }
    should_not_pass = [
      'Dicloabak 0,1% Augentropfen',
      '35 Clear-Flex 3,86 % Peritonealdialyselösung',
      'Esmeron 100mg/10ml Injektionslösung',
      ].each {
        |id|
        it "parses standard_galenic #{id}" do
          expect(standard_galenic_parser).to_not   parse(id)
        end
      }
  end
  context "dose_with_pro parsing" do
    let(:dose_with_pro_parser) { parser.dose_with_pro }

    should_pass = [
     '100mg/10ml',
      '8mg/4ml',
      ].each {
        |id|
        it "parses dose_with_pro #{id}" do
          expect(dose_with_pro_parser).to     parse(id)
        end
      }
    should_not_pass = [
     '100mgx10ml',
      '8mgX4ml',
      ].each {
        |id|
        it "parses dose_with_pro #{id}" do
          expect(dose_with_pro_parser).to_not   parse(id)
        end
      }
  end


end

