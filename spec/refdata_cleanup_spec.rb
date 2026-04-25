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
  end
end
