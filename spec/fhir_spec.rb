require "spec_helper"
require "json"
require "tempfile"
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
    it "reads the explicit indicationCode (XXXXX.NN) from each limitation" do
      parser = described_class.new(cyramza_fixture)
      prep = parser.preparations.first
      codes = prep.IndicationCodes.map(&:code)
      expect(codes).to include("20403.01", "20403.02")
      # cud_id still carries the CUD reference so the text can be resolved.
      expect(prep.IndicationCodes.map(&:cud_id)).to include("CYRAMZA.01", "CYRAMZA.02")
    end

    it "uses the explicit indicationCode field, not a dossier+CUD-suffix derivation" do
      # The BAG changelog (>= v2.0.5) states the limitation code (CUD id) and
      # the indication code are independent. Rewrite the explicit indicationCode
      # values so they no longer correspond to FOPHDossierNumber + CUD suffix,
      # and confirm the parser surfaces the explicit values verbatim.
      bundle = JSON.parse(File.read(cyramza_fixture))
      bundle["entry"].each do |entry|
        res = entry["resource"]
        next unless res["resourceType"] == "RegulatedAuthorization"
        Array(res["indication"]).each do |ind|
          Array(ind["extension"]).each do |ext|
            next unless ext["url"].to_s.include?("regulatedAuthorization-limitation")
            Array(ext["extension"]).each do |sub|
              sub["valueString"] = "99999.77" if sub["url"] == "indicationCode"
            end
          end
        end
      end

      file = Tempfile.new(["cyramza-indc", ".ndjson"])
      begin
        file.write(JSON.generate(bundle))
        file.flush
        parser = described_class.new(file.path)
        codes = parser.preparations.first.IndicationCodes.map(&:code)
        expect(codes).to all(eq("99999.77"))
        expect(codes).not_to include("20403.01", "20403.02")
      ensure
        file.close
        file.unlink
      end
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

  describe Oddb2xml::FhirExtractor, "limitation text resolution" do
    # Build language-variant copies of the Cyramza fixture in-memory:
    # the live FHIR feed never stores limitation text inline, only a
    # reference to a ClinicalUseDefinition whose `concept.text` differs
    # per language. We translate the CUD text + MPD product name and
    # write the modified bundle to a Tempfile so the multi-language
    # path can be exercised end-to-end.
    def language_variant(source_path, lang_code, cud_texts, product_name)
      bundle = JSON.parse(File.read(source_path))
      bundle["entry"].each do |entry|
        res = entry["resource"]
        case res["resourceType"]
        when "MedicinalProductDefinition"
          res["name"].each do |name|
            usage = name.dig("usage", 0, "language", "coding", 0)
            usage["code"] = lang_code if usage
            name["productName"] = product_name
          end
        when "ClinicalUseDefinition"
          text = cud_texts[res["id"]]
          if text
            res["indication"]["diseaseSymptomProcedure"]["concept"]["text"] = text
          end
        end
      end
      file = Tempfile.new(["cyramza-#{lang_code}", ".ndjson"])
      file.write(JSON.generate(bundle))
      file.flush
      file
    end

    let(:fr_file) do
      language_variant(
        cyramza_fixture, "fr-CH",
        {
          "CYRAMZA.01" => "FR limitation pour CYRAMZA.01",
          "CYRAMZA.02" => "FR limitation pour CYRAMZA.02"
        },
        "Cyramza FR"
      )
    end

    let(:it_file) do
      language_variant(
        cyramza_fixture, "it-CH",
        {
          "CYRAMZA.01" => "IT limitazione per CYRAMZA.01",
          "CYRAMZA.02" => "IT limitazione per CYRAMZA.02"
        },
        "Cyramza IT"
      )
    end

    after do
      [fr_file, it_file].each do |f|
        f.close
        f.unlink
      end
    end

    it "fills DescriptionDe from the referenced ClinicalUseDefinition" do
      data = described_class.new(cyramza_fixture).to_hash
      pkg = data.values.first[:packages].values.first
      texts = pkg[:limitations].map { |l| l[:desc_de] }
      expect(texts).to include(start_with("In Kombination mit Paclitaxel"))
      expect(texts).to include(start_with("In Kombination mit FOLFIRI"))
      # CUD reference is carried through so merge_language can resolve FR/IT.
      expect(pkg[:limitations].map { |l| l[:cud_ref] }).to include("CYRAMZA.01", "CYRAMZA.02")
    end

    it "fills DescriptionFr / DescriptionIt from the language-specific bundles" do
      files = {"de" => cyramza_fixture, "fr" => fr_file.path, "it" => it_file.path}
      data = described_class.new(files).to_hash
      pkg = data.values.first[:packages].values.first

      by_ref = pkg[:limitations].each_with_object({}) { |l, h| h[l[:cud_ref]] = l }

      expect(by_ref["CYRAMZA.01"][:desc_fr]).to eq("FR limitation pour CYRAMZA.01")
      expect(by_ref["CYRAMZA.02"][:desc_fr]).to eq("FR limitation pour CYRAMZA.02")
      expect(by_ref["CYRAMZA.01"][:desc_it]).to eq("IT limitazione per CYRAMZA.01")
      expect(by_ref["CYRAMZA.02"][:desc_it]).to eq("IT limitazione per CYRAMZA.02")
      # DE text is still there.
      expect(by_ref["CYRAMZA.01"][:desc_de]).to start_with("In Kombination mit Paclitaxel")
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
