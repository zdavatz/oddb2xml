# frozen_string_literal: true

require "spec_helper"
require "oddb2xml/weleda_sl"

RSpec.describe Oddb2xml::WeledaSL do
  let(:prices_csv) {
    <<~CSV
      pharma_group_code,price_chf_incl_vat,description,limitation
      2069591,26.95,Urtinktur 41−60 g/ml,
      2070631,2.50,D/C 1−9 Ampulle,
      2070275,28.45,D/C 10−29,
    CSV
  }

  let(:weleda_csv) {
    <<~CSV
      id,name,darreichung,status,verweis,artikelnummer,pharmacode,ean,abgabekategorie,zulassungsnummer,csl
      1,"Absinthium, ethanol. Infusum D1",Tropfen 50 ml,Lieferbar,,124755,1019849,7611916162404,FM / SL,,2069591
      2,Acidum Formicae D6,Ampullen 8x1ml,Lieferbar,,1,2,7611916151071,B / SL,1,8x2070631
      3,Anaemodoron,Tropfen 50 ml,Lieferbar,,5055,7767096,7680215220016,D / -,21522,
      4,No Price Product,Tropfen,Lieferbar,,9,9,7611916999999,B / SL,9,
      5,Spaced Multiplier,Ampullen,Lieferbar,,9,9,7611916152665,B / SL,9,2 x 2070275
    CSV
  }

  # ";"-separated, leading BOM, header columns carry trailing spaces — exactly
  # the live wala_arzneimittel.csv layout.
  let(:wala_csv) {
    "﻿" + <<~CSV
      EAN-Code;Pharmacode;Bezeichnung ;Galenische Form | PGR;KAT ;CSL-Code*;CSL 70.01.
      7680687430012;1098334;Aconit comp. Schmerzöl;Öl 50 ml;D;;
      7640187361278;4228473;Aconitum comp.;Globuli velati 20 g;D;2070358;18.35
      7640187360974;4227315;Aconitum comp.;Solutio ad inj. 10 x 1 ml;B;2070588;39
      7640187360011;4926556;Aconitum/Camphora comp.;Oleum 100 ml;D;2070513;24.8
    CSV
  }

  describe ".build_wala_map" do
    subject(:map) { described_class.build_wala_map(wala_csv) }

    it "includes only rows carrying a CSL-Code, keyed by 13-digit GTIN" do
      expect(map.keys).to contain_exactly(
        "7640187361278", "7640187360974", "7640187360011"
      )
      expect(map).not_to have_key("7680687430012") # no CSL-Code => not SL
    end

    it "takes the inline package price verbatim (multiplier already applied)" do
      expect(map["7640187361278"][:price]).to eq "18.35"
      expect(map["7640187360974"][:price]).to eq "39.00" # 10 x 1 ml pack
      expect(map["7640187360011"][:price]).to eq "24.80"
    end

    it "carries the Abgabekategorie and the group code" do
      expect(map["7640187360974"]).to include(sl: true, csl: "2070588", abgabe: "B")
    end

    it "returns {} for blank input" do
      expect(described_class.build_wala_map("")).to eq({})
      expect(described_class.build_wala_map(nil)).to eq({})
    end
  end

  describe ".parse_prices" do
    it "maps group code to price" do
      prices = described_class.parse_prices(prices_csv)
      expect(prices["2069591"]).to eq "26.95"
      expect(prices.size).to eq 3
    end

    it "returns {} for blank input" do
      expect(described_class.parse_prices("")).to eq({})
      expect(described_class.parse_prices(nil)).to eq({})
    end
  end

  describe ".resolve_price" do
    let(:prices) { described_class.parse_prices(prices_csv) }

    it "resolves a plain code" do
      expect(described_class.resolve_price("2069591", prices)).to eq "26.95"
    end

    it "applies the Nx package multiplier" do
      expect(described_class.resolve_price("8x2070631", prices)).to eq "20.00"
    end

    it "tolerates spaces around the multiplier" do
      expect(described_class.resolve_price("2 x 2070275", prices)).to eq "56.90"
    end

    it "returns nil for an unknown or empty code" do
      expect(described_class.resolve_price("9999999", prices)).to be_nil
      expect(described_class.resolve_price("", prices)).to be_nil
      expect(described_class.resolve_price(nil, prices)).to be_nil
    end
  end

  describe ".build_map" do
    let(:prices) { described_class.parse_prices(prices_csv) }
    subject(:map) { described_class.build_map(weleda_csv, prices) }

    it "includes only SL rows, keyed by 13-digit GTIN" do
      expect(map.keys).to contain_exactly(
        "7611916162404", "7611916151071", "7611916999999", "7611916152665"
      )
      expect(map).not_to have_key("7680215220016") # D / - is not SL
    end

    it "joins the public price via csl, including the multiplier" do
      expect(map["7611916162404"][:price]).to eq "26.95"
      expect(map["7611916151071"][:price]).to eq "20.00"
      expect(map["7611916152665"][:price]).to eq "56.90"
    end

    it "keeps SL rows whose price cannot be resolved (price nil)" do
      expect(map["7611916999999"][:sl]).to be true
      expect(map["7611916999999"][:price]).to be_nil
    end
  end

  describe ".load with bundled fallback" do
    it "loads the bundled data files when the download yields nothing" do
      flexmock(Oddb2xml::WeledaDownloader).new_instances.should_receive(:download).and_return(nil)
      flexmock(Oddb2xml::WalaDownloader).new_instances.should_receive(:download).and_return(nil)
      flexmock(Oddb2xml::BagSlGroupPricesDownloader).new_instances.should_receive(:download).and_return(nil)
      map = described_class.load({})
      expect(map.size).to be > 400
      expect(map["7611916162404"]).to include(sl: true, price: "26.95") # Weleda
      expect(map["7640187360974"]).to include(sl: true, price: "39.00") # WALA
    end
  end
end
