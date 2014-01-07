# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/downloader"

describe Oddb2xml::Extractor do
  it "pending"
end

describe Oddb2xml::TxtExtractorMethods do
  it "pending"
end

describe Oddb2xml::BagXmlExtractor do
  context 'should handle articles with and without pharmacode' do
    subject do
      dat = File.read(File.expand_path('../data/Preparation.xml', __FILE__))
      Oddb2xml::BagXmlExtractor.new(dat).to_hash
    end
    it { 
      @items = subject.to_hash
      with_pharma = @items['1699947']
      expect(with_pharma).not_to be_nil
      expect(with_pharma[:atc_code]).not_to be_nil
      expect(with_pharma[:pharmacodes]).not_to be_nil
      expect(with_pharma[:packages].size).to eq(1)
      expect(with_pharma[:packages].first[0]).to eq('1699947')
      expect(with_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq('205.3')
      expect(@items.size).to eq(2)
      no_pharma = @items['7680620690084']
      expect(no_pharma).not_to be_nil
      expect(no_pharma[:atc_code]).not_to be_nil
      expect(no_pharma[:pharmacodes]).not_to be_nil
      expect(no_pharma[:packages].size).to eq(1)
      expect(no_pharma[:packages].first[0]).to eq('7680620690084')
      expect(no_pharma[:packages].first[1][:prices][:pub_price][:price]).to eq('27.8')
    }
  end
end

describe Oddb2xml::SwissIndexExtractor do
  it "pending"
end

describe Oddb2xml::BMUpdateExtractor do
  it "pending"
end

describe Oddb2xml::LppvExtractor do
  it "pending"
end

describe Oddb2xml::SwissIndexExtractor do
  it "pending"
end

describe Oddb2xml::MigelExtractor do
  it "pending"
end

describe Oddb2xml::SwissmedicInfoExtractor do
  context 'when transfer.dat is empty' do
    subject { Oddb2xml::SwissmedicInfoExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'can parse swissmedic_packages.xlsx' do
    it {
        filename = File.join(File.dirname(__FILE__), 'data/swissmedic_packages.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :package).to_hash
        expect(@packs.size).to eq(14)
        first = @packs.first[1]
        expect(first[:atc_code]).to eq('J06AA')
        expect(first[:swissmedic_category]).to eq('B')
        expect(first[:package_size]).to eq('3')
        expect(first[:einheit_swissmedic]).to eq('Suppositorien')
        expect(first[:substance_swissmedic]).to eq('globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins)')
        expect(@packs.first[0].to_s).to eq('00274001')
      }
  end
  context 'can parse swissmedic_fridges.xlsx' do
    it {
        filename = File.join(File.dirname(__FILE__), 'data/swissmedic_fridges.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :fridge).to_arry
        expect(@packs.size).to eq(17)
        expect(@packs[0]).to eq("58618")
        expect(@packs[1]).to eq("00696")
      }
  end
  context 'can parse swissmedic_orphans.xls' do
    it {
        filename = File.join(File.dirname(__FILE__), 'data/swissmedic_orphans.xls')
        expect(File.exists?(filename)).to eq(true), "File #{filename} must exists"
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :orphan).to_arry
        expect(@packs.size).to eq(72)
        expect(@packs.first).to eq("62132")
        expect(@packs[7]).to eq("00687")
      }
  end
end

describe Oddb2xml::EphaExtractor do
  context 'can parse epha_interactions.csv' do
    it {
        filename = File.join(File.dirname(__FILE__), 'data/epha_interactions.csv')
        string = IO.read(filename)
        @actions = Oddb2xml::EphaExtractor.new(string).to_arry
        expect(@actions.size).to eq(2) 
       }
  end
end

describe Oddb2xml::MedregbmExtractor do
  it "pending"
end

describe Oddb2xml::ZurroseExtractor do
  context 'when transfer.dat is empty' do
    subject { Oddb2xml::ZurroseExtractor.new("") }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'when transfer.dat is nil' do
    subject { Oddb2xml::ZurroseExtractor.new(nil) }
    it { expect(subject.to_hash).to be_empty }
  end
  context 'when as line break mark \n is given' do
    subject do
      dat = <<-DAT
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash).to be_empty }
  end
  context 'when only 1 record have a valid EAN code' do
    subject do
      dat = <<-DAT
1120020209ERYTRHOCIN I.V. Trockensub Fl 1g                  001518002010300B080160000000000000002\r\n
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680316440115") }
  end
  context 'when expected line is given' do
    subject do
      dat = <<-DAT
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680316440115") }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("8.95") }
  end
end
