# encoding: utf-8
require 'spec_helper'
require "rexml/document"
require "oddb2xml/compare"

describe Oddb2xml::CompareV5 do
  
  context 'when comparing v3' do
    before(:all) do
      @first = File.join(Oddb2xml::SpecData, 'artikelstamm_P_010917.xml')
      @second = File.join(Oddb2xml::SpecData, 'artikelstamm_P_011217.xml')
      expect(File.exist?(@second)).to eq true
      expect(File.exist?(@first)).to eq true
      @result = Oddb2xml::CompareV5.new(@first, @second).compare
    end
    it 'should return true' do
      expected ={"ITEMS"=>{"NR_COMPARED"=>5, "GTIN"=>0, "PHAR"=>0, "DSCR"=>2,
                            "PEXF"=>2, "PPUB"=>2, "PHARMATYPE"=>0, "ATC"=>0,
                            "PKG_SIZE"=>0, "IKSCAT"=>0, "PRODNO"=>0}}
      expect(@result).to eq(expected)
    end
  end
  context 'when comparing v5' do
    before(:all) do
      @first = File.join(Oddb2xml::SpecData, 'v5_first.xml')
      @second = File.join(Oddb2xml::SpecData, 'v5_second.xml')
      expect(File.exist?(@second)).to eq true
      expect(File.exist?(@first)).to eq true
      @result = Oddb2xml::CompareV5.new(@first, @second).compare
    end
    it 'should return true' do
      expected = {"PRODUCTS"=>{"NR_COMPARED"=>1, "PRODNO"=>0, "SALECD"=>0, "DSCR"=>1, "DSCRF"=>0, "ATC"=>0, "SUBSTANCE"=>1},
                  "LIMITATIONS"=>{"NR_COMPARED"=>3, "LIMNAMEBAG"=>0, "DSCR"=>0, "DSCRF"=>0, "LIMITATION_PTS"=>1},
                  "ITEMS"=>{"NR_COMPARED"=>4, "PHARMATYPE"=>0, "GTIN"=>0, "SALECD"=>0, "DSCR"=>0, "DSCRF"=>0, "PEXF"=>2, "PPUB"=>2, "PKG_SIZE"=>0,
                            "MEASURE"=>0, "DOSAGE_FORM"=>3, "PRODNO"=>0, "PHAR"=>0, "IKSCAT"=>0}}
      expect(@result).to eq(expected)
    end
  end
  context 'when comparing v3 with v5' do
    before(:all) do
      @first = File.join(Oddb2xml::SpecData, 'artikelstamm_P_010917.xml')
      @first_n = File.join(Oddb2xml::SpecData, 'artikelstamm_N_010917.xml')
      @second = File.join(Oddb2xml::SpecData, 'v5_second.xml')
      expect(File.exist?(@first)).to eq true
      expect(File.exist?(@first_n)).to eq true
      expect(File.exist?(@second)).to eq true
      @result = Oddb2xml::CompareV5.new(@first, @second).compare
    end
    it 'should return true' do
      expected = {"ITEMS"=>{"NR_COMPARED"=>2, "GTIN"=>0, "PHAR"=>0, "DSCR"=>1,
                            "ATC"=>0, "PEXF"=>2, "PPUB"=>1, "PKG_SIZE"=>0, 
                            "IKSCAT"=>0, "PRODNO"=>0, "PHARMATYPE"=>0, "SL_ENTRY"=>0,
                            "LIMITATION"=>0, "LIMITATION_PTS"=>1, "LIMITATION_TEXT"=>1, "LIMNAMEBAG"=>0}}
      expect(@result).to eq(expected)
    end
  end
  context 'when comparing v5 with v3' do
    before(:all) do
      @first = File.join(Oddb2xml::SpecData, 'artikelstamm_P_010917.xml')
      @first_n = File.join(Oddb2xml::SpecData, 'artikelstamm_N_010917.xml')
      @second = File.join(Oddb2xml::SpecData, 'v5_second.xml')
      expect(File.exist?(@first)).to eq true
      expect(File.exist?(@first_n)).to eq true
      expect(File.exist?(@second)).to eq true
      @result = Oddb2xml::CompareV5.new(@second, @first).compare
    end
    it 'should return true' do
      expected_keys = ["DSCR", "DSCRF", 
                       "GTIN", "IKSCAT", "NR_COMPARED", "PEXF", "PHAR", 
                       "PHARMATYPE", "PKG_SIZE", "PPUB", "PRODNO", "SALECD", "SL_ENTRY"]

      expect(@result['ITEMS'].keys.sort).to eq expected_keys
      one_or_more = ["NR_COMPARED", 'PEXF', "SALECD", "DSCR", "DSCRF"]
      one_or_more.each do |fieldname|
        binding.pry unless @result['ITEMS'][fieldname] && @result['ITEMS'][fieldname] > 0
        expect(@result['ITEMS'][fieldname]).to be > 0
      end
      (expected_keys-one_or_more).each do |fieldname|
        expect("#{fieldname} #{@result['ITEMS'][fieldname]}").to eq "#{fieldname} 0"
      end
      
    end
  end
end
