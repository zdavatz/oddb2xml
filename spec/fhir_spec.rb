require "spec_helper"
require "oddb2xml/downloader"
require "oddb2xml/extractor"
require "oddb2xml/fhir_support"
require "oddb2xml/builder"

describe "FHIR Indikationscode support" do
  let(:cyramza_fixture) { File.join(Oddb2xml::SpecData, "fhir", "cyramza.ndjson") }

  describe Oddb2xml::FHIR::ClinicalUseDefinition do
    it "extracts the .NN suffix from id" do
      cud = described_class.new("id" => "CYRAMZA.02", "type" => "indication")
      expect(cud.nn_suffix).to eq("02")
      expect(cud.indication?).to be true
    end

    it "returns nil suffix for non-conforming ids" do
      cud = described_class.new("id" => "CYRAMZA")
      expect(cud.nn_suffix).to be_nil
    end
  end

  describe Oddb2xml::FHIR::Bundle do
    it "collects ClinicalUseDefinition entries" do
      line = File.read(cyramza_fixture).lines.first
      bundle = described_class.new(line)
      expect(bundle.clinical_use_definitions).not_to be_empty
      expect(bundle.clinical_use_definitions.map(&:id)).to include("CYRAMZA.01", "CYRAMZA.02")
    end
  end

  describe Oddb2xml::FHIR::PreparationsParser do
    it "constructs XXXXX.NN indication codes from FOPHDossierNumber + CUD suffix" do
      parser = described_class.new(cyramza_fixture)
      prep = parser.preparations.first
      codes = prep.IndicationCodes.map(&:code)
      expect(codes).to include("20403.01", "20403.02")
    end
  end

  describe Oddb2xml::FhirExtractor do
    it "exposes indication_codes on each item and package" do
      data = described_class.new(cyramza_fixture).to_hash
      expect(data).not_to be_empty

      item = data.values.first
      codes = item[:indication_codes].map { |ic| ic[:code] }
      expect(codes).to include("20403.01", "20403.02")

      pkg = item[:packages].values.first
      expect(pkg[:indication_codes]).to eq(item[:indication_codes])
    end
  end

  describe Oddb2xml::Builder, "PRD INDICATION_CODE emission" do
    it "emits one <INDICATION_CODE> child per indication on the PRD" do
      items = Oddb2xml::FhirExtractor.new(cyramza_fixture).to_hash
      builder = described_class.new
      builder.instance_variable_set(:@items, items)
      builder.instance_variable_set(:@refdata, {})
      builder.instance_variable_set(:@packs, {})
      builder.instance_variable_set(:@migel, {})
      builder.instance_variable_set(:@interactions, [])
      builder.instance_variable_set(:@flags, {})
      builder.instance_variable_set(:@orphan, [])
      builder.instance_variable_set(:@firstbase, {})
      builder.instance_variable_set(:@substances, [])
      builder.instance_variable_set(:@codes, {})
      builder.instance_variable_set(:@missing, [])
      builder.instance_variable_set(:@tag_suffix, nil)

      xml = builder.send(:build_product)
      expect(xml).to include("<INDICATION_CODE")
      expect(xml).to include('code="20403.01"')
      expect(xml).to include('code="20403.02"')
      expect(xml).to include('cud_id="CYRAMZA.01"')
      expect(xml).to include('cud_id="CYRAMZA.02"')
      # The CUD's indication text travels into the element body so
      # downstream consumers can show the human-readable indication
      # next to the code.
      expect(xml).to include("In Kombination mit Paclitaxel")
      expect(xml).to include("In Kombination mit FOLFIRI")
    end
  end
end
