# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any compressor' do
  it 'should create compress file' do
    File.stub(:unlink).and_return(false)
    @compressor.contents << File.expand_path('../data/oddb_article.xml', __FILE__)
    @compressor.contents << File.expand_path('../data/oddb_product.xml', __FILE__)
    @compressor.finalize!.should == true
    compress_file = @compressor.instance_variable_get(:@compress_file)
    File.exists?(compress_file).should == true
    File.unstub!(:unlink)
  end
end

describe Oddb2xml::Compressor do
  context 'at initialize' do
    context 'any argment is given' do
      before(:each) do
        @compressor = Oddb2xml::Compressor.new
      end
      it 'should have empty contents as array' do
        @compressor.contents.should be_a Array
        @compressor.contents.should be_empty
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /oddb_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
      end
    end
    context "when swiss prefix is given" do
      before(:each) do
        @compressor = Oddb2xml::Compressor.new('swiss', 'tar.gz')
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /swiss_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
      end
    end
    context "when tar.gz ext is given" do
      before(:each) do
        @compressor = Oddb2xml::Compressor.new('oddb', 'tar.gz')
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /oddb_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
      end
    end
    context "when zip ext is given" do
      before(:each) do
        @compressor = Oddb2xml::Compressor.new('oddb', 'zip')
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /oddb_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.zip/
      end
    end
  end
  context 'when finalize! is called' do
    context 'unexpectedly' do
      before(:each) do
        @compressor = Oddb2xml::Compressor.new
      end
      it 'should fail with no contents' do
        @compressor.finalize!.should == false
      end
      it 'should fail with invalid file' do
        @compressor.contents << '../invalid_file'
        @compressor.finalize!.should == false
      end
    end
    context 'successfully' do
      context 'with tar.gz' do
        before(:each) do
          @compressor = Oddb2xml::Compressor.new
        end
        it_behaves_like 'any compressor'
      end
      context 'with zip' do
        before(:each) do
          @compressor = Oddb2xml::Compressor.new('oddb', 'zip')
        end
        it_behaves_like 'any compressor'
      end
      after(:each) do
        Dir.glob('oddb_xml_*').each do |file|
          File.unlink(file) if File.exists?(file)
        end
      end
    end
  end
end
