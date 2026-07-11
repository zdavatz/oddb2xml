# frozen_string_literal: true

require "spec_helper"
require "oddb2xml/rogger_names"

RSpec.describe Oddb2xml::RoggerNames do
  let(:rogger_csv) {
    <<~CSV
      GTIN,Mediname
      7680672570037,RINVOQ Ret Tabl 30 mg 28 Stk
      7680665940021,GABAPENTIN Spirig HC Kaps 100 mg 100 Stk
      7680625680042,CETIRIZIN Spirig HC Filmtabl 10 mg 10 Stk
      not-a-gtin,BROKEN ROW
      7680656721066,
    CSV
  }

  describe ".parse" do
    subject(:map) { described_class.parse(rogger_csv) }

    it "maps 13-digit GTINs to the preferred German name" do
      expect(map["7680672570037"]).to eq "RINVOQ Ret Tabl 30 mg 28 Stk"
      expect(map["7680665940021"]).to eq "GABAPENTIN Spirig HC Kaps 100 mg 100 Stk"
    end

    it "skips rows with a malformed GTIN or an empty name" do
      expect(map.size).to eq 3
      expect(map).not_to have_key("7680656721066")
    end

    it "returns {} for blank input" do
      expect(described_class.parse("")).to eq({})
      expect(described_class.parse(nil)).to eq({})
    end
  end

  describe ".rogger_csv?" do
    it "accepts the sheet export header and rejects HTML/empty bodies" do
      expect(described_class.rogger_csv?(rogger_csv)).to be true
      expect(described_class.rogger_csv?("\xEF\xBB\xBFGTIN,Mediname\n")).to be true
      expect(described_class.rogger_csv?(nil)).to be false
      expect(described_class.rogger_csv?("")).to be false
      expect(described_class.rogger_csv?("<!DOCTYPE html><html>Sign in - Google Accounts</html>")).to be false
    end
  end

  describe ".load" do
    it "falls back to the bundled data/rogger_liste.csv when the download fails" do
      flexmock(Oddb2xml::RoggerDownloader).new_instances.should_receive(:download).and_raise(SocketError)
      map = described_class.load({})
      expect(map).not_to be_empty
      expect(map.keys).to all(match(/\A\d{13}\z/))
      expect(map["7680672570037"]).to eq "RINVOQ Ret Tabl 30 mg 28 Stk"
    end

    it "falls back to the bundled CSV when the response is not the sheet export" do
      flexmock(Oddb2xml::RoggerDownloader).new_instances.should_receive(:download)
        .and_return("<!DOCTYPE html><html>Sign in - Google Accounts</html>")
      map = described_class.load({})
      expect(map["7680672570037"]).to eq "RINVOQ Ret Tabl 30 mg 28 Stk"
    end

    it "never raises, returning {} when no source is available" do
      flexmock(Oddb2xml::RoggerDownloader).new_instances.should_receive(:download).and_raise(SocketError)
      flexmock(described_class).should_receive(:source).and_return(nil)
      expect(described_class.load({})).to eq({})
    end
  end

  describe "Builder#apply_rogger_name_overrides!" do
    it "replaces only the German description of listed GTINs" do
      builder = Oddb2xml::Builder.new({})
      builder.rogger_names = {"7680672570037" => "RINVOQ Ret Tabl 30 mg 28 Stk"}
      builder.refdata = {
        "7680672570037" => {ean13: "7680672570037", no8: "67257003",
                            desc_de: "RINVOQ Retardtabletten 30 mg 28 Stk",
                            desc_fr: "RINVOQ cpr ret 30 mg 28 pce"},
        "7680671390032" => {ean13: "7680671390032", no8: "67139003",
                            desc_de: "FAMPYRA Ret Tabl 10 mg 4x14 Stk",
                            desc_fr: "FAMPYRA cpr ret 10 mg 4x14 pce"}
      }
      builder.send(:apply_rogger_name_overrides!)
      expect(builder.refdata["7680672570037"][:desc_de]).to eq "RINVOQ Ret Tabl 30 mg 28 Stk"
      expect(builder.refdata["7680672570037"][:desc_fr]).to eq "RINVOQ cpr ret 30 mg 28 pce"
      expect(builder.refdata["7680671390032"][:desc_de]).to eq "FAMPYRA Ret Tabl 10 mg 4x14 Stk"
    end
  end
end
