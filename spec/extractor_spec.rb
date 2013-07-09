# encoding: utf-8

require 'spec_helper'

describe Oddb2xml::Extractor do
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
