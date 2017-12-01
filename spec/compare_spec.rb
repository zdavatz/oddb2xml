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
      expect(@result).to eq(true)
    end
  end
end

