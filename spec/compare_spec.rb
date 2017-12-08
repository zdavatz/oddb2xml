# encoding: utf-8
require 'spec_helper'
require "rexml/document"
require "oddb2xml/compare"

describe Oddb2xml::CompareV5 do
  context 'when download is called' do
    before(:all) do
      @first = File.join(Oddb2xml::SpecData, 'v5_first.xml')
      @second = File.join(Oddb2xml::SpecData, 'v5_second.xml')
      expect(File.exist?(@second)).to eq true
      expect(File.exist?(@first)).to eq true
      @result = Oddb2xml::CompareV5.new(@first, @second).compare
    end
    it 'should return true' do
      expectecd = {"PRODUCTS"=>{"NR_COMPARED"=>1, "PRODNO"=>0, "SALECD"=>0, "DSCR"=>1, "DSCRF"=>0, "ATC"=>0, "SUBSTANCE"=>1},
                  "LIMITATIONS"=>{"NR_COMPARED"=>3, "LIMNAMEBAG"=>0, "DSCR"=>0, "DSCRF"=>0, "LIMITATION_PTS"=>1},
                  "ITEMS"=>{"NR_COMPARED"=>4, "PHARMATYPE"=>0, "GTIN"=>0, "SALECD"=>0, "DSCR"=>0, "DSCRF"=>0, "PEXF"=>2, "PPUB"=>2, "PKG_SIZE"=>0,
                            "MEASURE"=>0, "DOSAGE_FORM"=>3, "PRODNO"=>0, "PHAR"=>0, "IKSCAT"=>0}}
      expect(@result).to eq(expectecd)
    end
  end
end

