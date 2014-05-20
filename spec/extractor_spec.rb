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
      dat = File.read(File.join(Oddb2xml::SpecData, 'Preparations.xml'))
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
      expect(@items.size).to eq(5)
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
  context 'can parse swissmedic_package.xlsx' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_package.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :package).to_hash
        expect(@packs.size).to eq(16)
        serocytol = nil
        @packs.each{|pack|
                    serocytol = pack[1] if pack[0].to_s == '00274001'
                   }
        expect(serocytol[:atc_code]).to eq('J06AA')
        expect(serocytol[:swissmedic_category]).to eq('B')
        expect(serocytol[:package_size]).to eq('3')
        expect(serocytol[:einheit_swissmedic]).to eq('Suppositorien')
        expect(serocytol[:substance_swissmedic]).to eq('globulina equina (immunisé avec coeur, tissu pulmonaire, reins de porcins)')
      }
  end
  context 'can parse swissmedic_fridge.xlsx' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_fridge.xlsx')
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :fridge).to_arry
        expect(@packs.size).to eq(17)
        expect(@packs[0]).to eq("58618")
        expect(@packs[1]).to eq("00696")
      }
  end
  context 'can parse swissmedic_orphans.xls' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'swissmedic_orphan.xlsx')
        expect(File.exists?(filename)).to eq(true), "File #{filename} must exists"
        @packs = Oddb2xml::SwissmedicExtractor.new(filename, :orphan).to_arry
        expect(@packs.size).to eq(78)
        expect(@packs.first).to eq("62132")
        expect(@packs[7]).to eq("00687")
      }
  end
end

describe Oddb2xml::EphaExtractor do
  context 'can parse epha_interactions.csv' do
    it {
        filename = File.join(Oddb2xml::SpecData, 'epha_interactions.csv')
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
  context 'it should work also when \n is the line ending' do
    subject do
      dat = <<-DAT
1120020244FERRO-GRADUMET Depottabl 30 Stk                   000895001090300C060710076803164401152
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { subject.to_hash.size.should eq(1) }
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
    it { expect(subject.to_hash.values.first[:price]).to eq("8.95") }
  end
  context 'when Estradiol Creme is given' do
    subject do
      dat = <<-DAT
1130921929OESTRADIOL Inj L�s 5 mg 10 Amp 1 ml               000940001630300B070820076802840708402\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    #it { expect(pp subject.to_hash) }
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680284070840") }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("9.40") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("16.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq("0921929") }
  end
  context 'when SELSUN Shampoo is given' do
    subject do
      dat = <<-DAT
1120020652SELSUN Shampoo Susp 120 ml                        001576002430300D100400076801723306812\r\n
      DAT
      Oddb2xml::ZurroseExtractor.new(dat)
    end
    it { expect(subject.to_hash.keys.length).to eq(1) }
    it { expect(subject.to_hash.keys.first).to eq("7680172330681") }
    it { expect(subject.to_hash.values.first[:vat]).to eq("2") }
    it { expect(subject.to_hash.values.first[:price]).to eq("15.76") }
    it { expect(subject.to_hash.values.first[:pub_price]).to eq("24.30") }
    it { expect(subject.to_hash.values.first[:pharmacode]).to eq("0020652") }
    
  end
  
  x =%(
  Record-Art 1 Länge 97
    :vat   => $2.to_s,
    :price => sprintf("%.2f", line[60,6].gsub(/(\d{2})$/, '.\1').to_f),
    :pub_price => sprintf("%.2f", line[66,6].gsub(/(\d{2})$/, '.\1').to_f),
    =
    )
end
