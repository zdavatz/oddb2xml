require "spec_helper"
require "oddb2xml/downloader"
require "oddb2xml/extractor"
require "oddb2xml/fhir_support"

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
end
