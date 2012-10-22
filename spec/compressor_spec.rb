# encoding: utf-8

require 'spec_helper'

describe Oddb2xml::Compressor do
  context "when tar.gz ext is given at initialize" do
    before(:each) do
      @compressor = Oddb2xml::Compressor.new('tar.gz')
    end
    it 'should have formated filename with datetime' do
      @compressor.instance_variable_get(:@compressed_file).
        should =~ /oddb_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
    end
    it 'should have empty contents as array' do
      @compressor.contents.should be_a Array
      @compressor.contents.should be_empty
    end
  end
  context 'when finalize! is called' do
    before(:each) do
      @compressor = Oddb2xml::Compressor.new()
    end
    context 'unexpectedly' do
      it 'should fail with no contents' do
        @compressor.finalize!.should == false
      end
      it 'should fail with invalid file' do
        @compressor.contents << '../invalid_file'
        @compressor.finalize!.should == false
      end
    end
    context 'successfully' do
      it 'pending'
    end
  end
end

