require "spec_helper"
require "oddb2xml/refdata_cleanup"

describe Oddb2xml::RefdataCleanup do
  describe ".single_substance?" do
    it "returns true for a single Swissmedic substance" do
      expect(described_class.single_substance?("mirtazapinum")).to be true
      expect(described_class.single_substance?("methotrexatum")).to be true
    end

    it "returns false when multiple substances are listed (combo)" do
      expect(described_class.single_substance?("pertuzumabum, trastuzumabum")).to be false
      expect(described_class.single_substance?("atovaquonum, proguanili hydrochloridum")).to be false
    end

    it "returns false when input is nil or empty" do
      expect(described_class.single_substance?(nil)).to be false
      expect(described_class.single_substance?("")).to be false
      expect(described_class.single_substance?("   ")).to be false
    end
  end

  describe ".fix_double_dose" do
    let(:mono) { "mirtazapinum" }
    let(:combo) { "pertuzumabum, trastuzumabum" }

    it "removes the duplicate dose for a mono product" do
      input = "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 Tablette"
      expected = "MIRTAZAPIN Sandoz eco 30 mg / 100 Tablette"
      expect(described_class.fix_double_dose(input, mono)).to eq expected
    end

    it "handles ICATIBANT-style spacing" do
      input = "ICATIBANT Spirig HC 30 mg / 30 mg / 1 x 3 ml"
      expected = "ICATIBANT Spirig HC 30 mg / 1 x 3 ml"
      expect(described_class.fix_double_dose(input, mono)).to eq expected
    end

    it "leaves real combinations untouched (PHESGO 600 mg / 600 mg / 10 ml)" do
      input = "PHESGO Inj Lös 600 mg/600 mg/10 ml Durchstf"
      expect(described_class.fix_double_dose(input, combo)).to eq input
    end

    it "leaves descriptions without the double-dose pattern untouched" do
      input = "LEVOCETIRIZIN Spirig HC Filmtabl 5 mg 10 Stk"
      expect(described_class.fix_double_dose(input, mono)).to eq input
    end

    it "leaves the description untouched when Swissmedic substance is unknown" do
      input = "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 Tablette"
      expect(described_class.fix_double_dose(input, nil)).to eq input
      expect(described_class.fix_double_dose(input, "")).to eq input
    end

    it "is a no-op for nil or empty descriptions" do
      expect(described_class.fix_double_dose(nil, mono)).to be_nil
      expect(described_class.fix_double_dose("", mono)).to eq ""
    end

    it "does not collapse different doses (X mg / Y mg)" do
      input = "FOO 250 mg / 100 mg / 12 Stk"
      expect(described_class.fix_double_dose(input, combo)).to eq input
    end
  end

  describe ".normalize_galenic_form" do
    it "abbreviates the spelled-out 'Retardtabletten' to 'Ret Tabl' (issue #112 #13)" do
      input = "RINVOQ Retardtabletten 30 mg 28 Stk"
      expected = "RINVOQ Ret Tabl 30 mg 28 Stk"
      expect(described_class.normalize_galenic_form(input)).to eq expected
    end

    it "leaves the already-abbreviated house style untouched" do
      input = "TRAMAL retard Ret Tabl 100 mg 30 Stk"
      expect(described_class.normalize_galenic_form(input)).to eq input
    end

    it "is a no-op for FR/IT names (different galenic words)" do
      fr = "RINVOQ comprimé à libération prolong. 30 mg 28 pce"
      it_ = "RINVOQ compresse a rilascio prolungato 30 mg 28 pz"
      expect(described_class.normalize_galenic_form(fr)).to eq fr
      expect(described_class.normalize_galenic_form(it_)).to eq it_
    end

    it "is a no-op for nil or empty descriptions" do
      expect(described_class.normalize_galenic_form(nil)).to be_nil
      expect(described_class.normalize_galenic_form("")).to eq ""
    end

    it "does not touch 'Retardtabletten' embedded in a longer word" do
      input = "FOO Retardtablettenspender 1 Stk"
      expect(described_class.normalize_galenic_form(input)).to eq input
    end
  end

  describe ".dose_for_substance" do
    let(:comp) { "atovaquonum 250 mg, proguanili hydrochloridum 100 mg, cellulosum microcristallinum" }

    it "returns the dose of the named active, normalised to '<n> <unit>'" do
      expect(described_class.dose_for_substance(comp, "atovaquonum")).to eq "250 mg"
      expect(described_class.dose_for_substance(comp, "proguanili hydrochloridum")).to eq "100 mg"
    end

    it "ignores excipient doses outside the substance's segment" do
      cetirizin = "cetirizini dihydrochloridum 10 mg, lactosum monohydricum 65 mg"
      expect(described_class.dose_for_substance(cetirizin, "cetirizini dihydrochloridum")).to eq "10 mg"
    end

    it "returns nil when the substance is absent" do
      expect(described_class.dose_for_substance(comp, "ibuprofenum")).to be_nil
      expect(described_class.dose_for_substance(nil, "atovaquonum")).to be_nil
    end
  end

  describe ".fix_missing_combo_dose (issue #112 #6)" do
    let(:combo) { "atovaquonum, proguanili hydrochloridum" }
    let(:comp) { "atovaquonum 250 mg, proguanili hydrochloridum 100 mg, cellulosum microcristallinum" }

    it "appends the 2nd combo component dose for the catalogued IKSNR (ATOVAQUON, 65280)" do
      input = "ATOVAQUON PLUS Spirig HC Filmtabl 250 mg 12 Stk"
      expect(described_class.fix_missing_combo_dose(input, combo, comp, "65280001"))
        .to eq "ATOVAQUON PLUS Spirig HC Filmtabl 250 mg / 100 mg 12 Stk"
    end

    it "is a no-op for non-catalogued registrations (avoids the KEPPRA sodium misfire)" do
      input = "KEPPRA Filmtabl 1000 mg 100 Stk"
      keppra_comp = "levetiracetamum 1000 mg, ... corresp. natrium 2.8 mg"
      expect(described_class.fix_missing_combo_dose(input, "levetiracetamum, natrium", keppra_comp, "29152001"))
        .to eq input
    end

    it "is a no-op when the 2nd dose is already present" do
      input = "ATOVAQUON PLUS Spirig HC Filmtabl 250 mg / 100 mg 12 Stk"
      expect(described_class.fix_missing_combo_dose(input, combo, comp, "65280001")).to eq input
    end

    it "is a no-op for mono products" do
      input = "X 250 mg 12 Stk"
      expect(described_class.fix_missing_combo_dose(input, "atovaquonum", comp, "65280001")).to eq input
    end
  end

  describe ".fix_missing_dose (issue #112 #4)" do
    let(:comp) { "cetirizini dihydrochloridum 10 mg, lactosum monohydricum 65 mg, talcum" }
    let(:sub) { "cetirizini dihydrochloridum" }

    it "inserts the strength before the pack count for the catalogued IKSNR (CETIRIZIN, 62568)" do
      expect(described_class.fix_missing_dose("CETIRIZIN Spirig HC Filmtabl 30 Stk", sub, comp, "62568007"))
        .to eq "CETIRIZIN Spirig HC Filmtabl 10 mg 30 Stk"
    end

    it "works on French/Italian pack-count units" do
      expect(described_class.fix_missing_dose("CETIRIZINE Spirig HC cpr pellic 30 pce", sub, comp, "62568007"))
        .to eq "CETIRIZINE Spirig HC cpr pellic 10 mg 30 pce"
      expect(described_class.fix_missing_dose("CETIRIZINA Spirig HC cpr riv 30 pz", sub, comp, "62568007"))
        .to eq "CETIRIZINA Spirig HC cpr riv 10 mg 30 pz"
    end

    it "is a no-op for non-catalogued registrations (avoids the IMPORTAL powder misfire)" do
      expect(described_class.fix_missing_dose("IMPORTAL Pulver Btl 50 Stk", "lactitolum", "lactitolum monohydricum 10 g", "43414001"))
        .to eq "IMPORTAL Pulver Btl 50 Stk"
    end

    it "is a no-op when a strength is already present" do
      input = "CETIRIZIN Spirig HC Filmtabl 10 mg 30 Stk"
      expect(described_class.fix_missing_dose(input, sub, comp, "62568007")).to eq input
    end
  end

  describe ".fix_missing_volume (issue #112 #7)" do
    let(:comp) { "tirzepatidum 7.5 mg, ... ad solutionem pro 0.6 ml corresp. natrium 0.6 mg." }

    it "appends the per-pen volume for the catalogued IKSNR (MOUNJARO, 69696)" do
      expect(described_class.fix_missing_volume("MOUNJARO KwikPen Inj Lös 7.5 mg 1 Stk", comp, "69696003"))
        .to eq "MOUNJARO KwikPen Inj Lös 7.5 mg/0.6 ml 1 Stk"
    end

    it "is a no-op for non-catalogued registrations (avoids the CIMZIA concentration misfire)" do
      input = "CIMZIA AutoClicks 200 mg/ml Fertpen 2 Stk"
      expect(described_class.fix_missing_volume(input, "... pro 1 ml ...", "58277001")).to eq input
    end

    it "never double-appends a volume that is already present" do
      input = "MOUNJARO KwikPen Inj Lös 7.5 mg/0.6 ml 1 Stk"
      expect(described_class.fix_missing_volume(input, comp, "69696003")).to eq input
    end
  end

  describe ".fix_truncated_metoject (issue #112 #1)" do
    it "rebuilds the DE name from the prefix plus the Swissmedic size" do
      expect(described_class.fix_truncated_metoject("METOJECT Autoinjektor 10 mg/0.2 ml Inj Lös 10 mg 1", "65672106", "1"))
        .to eq "METOJECT Autoinjektor 10 mg/0.2 ml Fertpen 1 Stk"
    end

    it "localises French (stylo pré/pce) and Italian (penna preriempita/pz)" do
      expect(described_class.fix_truncated_metoject("METOJECT Autoinjektor 10 mg/0.2 ml inj sol 10 mg 1", "65672106", "1"))
        .to eq "METOJECT Autoinjektor 10 mg/0.2 ml stylo pré 1 pce"
      expect(described_class.fix_truncated_metoject("METOJECT Autoinjektor 10 mg/0.2 ml sol inj 10 mg 1", "65672106", "1"))
        .to eq "METOJECT Autoinjektor 10 mg/0.2 ml penna preriempita 1 pz"
    end

    it "uses the Swissmedic size even when the truncated count was cut off" do
      expect(described_class.fix_truncated_metoject("METOJECT Autoinjektor 12.5 mg/0.25 ml Inj Lös 12.5", "65672111", "12"))
        .to eq "METOJECT Autoinjektor 12.5 mg/0.25 ml Fertpen 12 Stk"
    end

    it "is a no-op for other registrations and without a size" do
      other = "FOO Autoinjektor 10 mg/0.2 ml Inj Lös 10 mg 1"
      expect(described_class.fix_truncated_metoject(other, "99999001", "1")).to eq other
      keep = "METOJECT Autoinjektor 10 mg/0.2 ml Inj Lös 10 mg 1"
      expect(described_class.fix_truncated_metoject(keep, "65672106", nil)).to eq keep
    end
  end

  describe ".fix_truncated_volume_unit (issue #112 #3)" do
    it "restores the truncated 'ml' for the VERACTIV Vitamin D3 registration" do
      expect(described_class.fix_truncated_volume_unit("VERACTIV Vitamin D3 Wild Huile Trp 20'000 U.I. 10m", "57690004"))
        .to eq "VERACTIV Vitamin D3 Wild Huile Trp 20'000 U.I. 10ml"
    end

    it "is a no-op when the volume already ends in 'ml'" do
      input = "VERACTIV Vitamin D3 Wild Huile Trp 20'000 U.I. 10ml"
      expect(described_class.fix_truncated_volume_unit(input, "57690004")).to eq input
    end

    it "is a no-op for other registrations" do
      input = "FOO Tropfen 10m"
      expect(described_class.fix_truncated_volume_unit(input, "12345001")).to eq input
    end
  end
end

describe Oddb2xml::Builder do
  describe "#apply_refdata_description_cleanups!" do
    let(:builder) { Oddb2xml::Builder.new }

    it "fixes double-dose entries on mono products" do
      builder.packs = {
        "69475006" => {substance_swissmedic: "mirtazapinum"}
      }
      builder.refdata = {
        "7680694750066" => {
          ean13: "7680694750066",
          no8: "69475006",
          desc_de: "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 Tablette",
          desc_fr: "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 comprimé(",
          desc_it: ""
        }
      }

      builder.apply_refdata_description_cleanups!

      item = builder.refdata["7680694750066"]
      expect(item[:desc_de]).to eq "MIRTAZAPIN Sandoz eco 30 mg / 100 Tablette"
      expect(item[:desc_fr]).to eq "MIRTAZAPIN Sandoz eco 30 mg / 100 comprimé("
    end

    it "leaves combo products untouched" do
      builder.packs = {
        "67828001" => {substance_swissmedic: "pertuzumabum, trastuzumabum"}
      }
      original = "PHESGO Inj Lös 600 mg/600 mg/10 ml Durchstf"
      builder.refdata = {
        "7680678280013" => {
          ean13: "7680678280013",
          no8: "67828001",
          desc_de: original,
          desc_fr: "",
          desc_it: ""
        }
      }

      builder.apply_refdata_description_cleanups!

      expect(builder.refdata["7680678280013"][:desc_de]).to eq original
    end

    it "is idempotent" do
      builder.packs = {
        "69475006" => {substance_swissmedic: "mirtazapinum"}
      }
      builder.refdata = {
        "7680694750066" => {
          ean13: "7680694750066",
          no8: "69475006",
          desc_de: "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 Tablette",
          desc_fr: "",
          desc_it: ""
        }
      }

      builder.apply_refdata_description_cleanups!
      builder.apply_refdata_description_cleanups!

      expect(builder.refdata["7680694750066"][:desc_de])
        .to eq "MIRTAZAPIN Sandoz eco 30 mg / 100 Tablette"
    end

    it "skips entries without a Swissmedic match" do
      builder.packs = {}
      input = "MIRTAZAPIN Sandoz eco 30 mg / 30 mg / 100 Tablette"
      builder.refdata = {
        "7680694750066" => {
          ean13: "7680694750066",
          no8: "69475006",
          desc_de: input,
          desc_fr: "",
          desc_it: ""
        }
      }

      builder.apply_refdata_description_cleanups!

      expect(builder.refdata["7680694750066"][:desc_de]).to eq input
    end

    it "normalises the galenic form on the German name only (RINVOQ, issue #112 #13)" do
      builder.packs = {
        "67257003" => {substance_swissmedic: "upadacitinibum"}
      }
      builder.refdata = {
        "7680672570037" => {
          ean13: "7680672570037",
          no8: "67257003",
          desc_de: "RINVOQ Retardtabletten 30 mg 28 Stk",
          desc_fr: "RINVOQ comprimé à libération prolong. 30 mg 28 pce",
          desc_it: "RINVOQ compresse a rilascio prolungato 30 mg 28 pz"
        }
      }

      builder.apply_refdata_description_cleanups!

      item = builder.refdata["7680672570037"]
      expect(item[:desc_de]).to eq "RINVOQ Ret Tabl 30 mg 28 Stk"
      expect(item[:desc_fr]).to eq "RINVOQ comprimé à libération prolong. 30 mg 28 pce"
      expect(item[:desc_it]).to eq "RINVOQ compresse a rilascio prolungato 30 mg 28 pz"
    end

    it "reconstructs missing dose info from Swissmedic for catalogued articles (issue #112 #4/#6/#7)" do
      builder.packs = {
        "65280001" => {substance_swissmedic: "atovaquonum, proguanili hydrochloridum",
                       composition_swissmedic: "atovaquonum 250 mg, proguanili hydrochloridum 100 mg, cellulosum"},
        "62568007" => {substance_swissmedic: "cetirizini dihydrochloridum",
                       composition_swissmedic: "cetirizini dihydrochloridum 10 mg, lactosum monohydricum 65 mg"},
        "69696003" => {substance_swissmedic: "tirzepatidum",
                       composition_swissmedic: "tirzepatidum 7.5 mg, ad solutionem pro 0.6 ml corresp. natrium"}
      }
      builder.refdata = {
        "7680652800017" => {ean13: "7680652800017", no8: "65280001",
                            desc_de: "ATOVAQUON PLUS Spirig HC Filmtabl 250 mg 12 Stk", desc_fr: "", desc_it: ""},
        "7680625680073" => {ean13: "7680625680073", no8: "62568007",
                            desc_de: "CETIRIZIN Spirig HC Filmtabl 30 Stk", desc_fr: "", desc_it: ""},
        "7680696960036" => {ean13: "7680696960036", no8: "69696003",
                            desc_de: "MOUNJARO KwikPen Inj Lös 7.5 mg 1 Stk", desc_fr: "", desc_it: ""}
      }

      builder.apply_refdata_description_cleanups!

      expect(builder.refdata["7680652800017"][:desc_de]).to eq "ATOVAQUON PLUS Spirig HC Filmtabl 250 mg / 100 mg 12 Stk"
      expect(builder.refdata["7680625680073"][:desc_de]).to eq "CETIRIZIN Spirig HC Filmtabl 10 mg 30 Stk"
      expect(builder.refdata["7680696960036"][:desc_de]).to eq "MOUNJARO KwikPen Inj Lös 7.5 mg/0.6 ml 1 Stk"
    end

    it "rebuilds truncated names from Swissmedic for catalogued articles (issue #112 #1/#3)" do
      builder.packs = {
        "65672106" => {substance_swissmedic: "methotrexatum", composition_swissmedic: "", size: "1"},
        "57690004" => {substance_swissmedic: "colecalciferolum", composition_swissmedic: "", size: "1"}
      }
      builder.refdata = {
        "7680656721066" => {ean13: "7680656721066", no8: "65672106",
                            desc_de: "METOJECT Autoinjektor 10 mg/0.2 ml Inj Lös 10 mg 1",
                            desc_fr: "METOJECT Autoinjektor 10 mg/0.2 ml inj sol 10 mg 1",
                            desc_it: "METOJECT Autoinjektor 10 mg/0.2 ml sol inj 10 mg 1"},
        "7680576900046" => {ean13: "7680576900046", no8: "57690004",
                            desc_de: "VERACTIV Vitamin D3 Wild Huile Trp 20'000 U.I. 10m", desc_fr: "", desc_it: ""}
      }

      builder.apply_refdata_description_cleanups!

      met = builder.refdata["7680656721066"]
      expect(met[:desc_de]).to eq "METOJECT Autoinjektor 10 mg/0.2 ml Fertpen 1 Stk"
      expect(met[:desc_fr]).to eq "METOJECT Autoinjektor 10 mg/0.2 ml stylo pré 1 pce"
      expect(met[:desc_it]).to eq "METOJECT Autoinjektor 10 mg/0.2 ml penna preriempita 1 pz"
      expect(builder.refdata["7680576900046"][:desc_de]).to eq "VERACTIV Vitamin D3 Wild Huile Trp 20'000 U.I. 10ml"
    end
  end
end
