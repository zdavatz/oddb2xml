# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any compressor' do
  it 'should create compress file' do
    File.stub(:unlink).and_return(false)
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_article.xml')
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_product.xml')
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_substance.xml')
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_limitation.xml')
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_fi.xml')
    @compressor.contents << File.join(Oddb2xml::SpecCompressor, 'oddb_fi_product.xml')
    @compressor.finalize!.should eq(true)
    compress_file = @compressor.instance_variable_get(:@compress_file)
    File.exists?(compress_file).should == true
    File.unstub(:unlink)
    @compressor = nil
  end
end

describe Oddb2xml::Compressor do
  after(:each) do
    cleanup_compressor
    if @compress_file
      compress_file = @compressor.instance_variable_get(:@compress_file)
      FileUtils.rm_f(compress_file, :verbose => true)
    end
  end
  after(:all) do
    cleanup_compressor
  end
  context 'at initialize' do
    context ' argment is given' do
      before(:each) do
        cleanup_directories_before_run
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
        cleanup_directories_before_run
        @compressor = Oddb2xml::Compressor.new('swiss', {:compress_ext => 'tar.gz'})
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /swiss_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
      end
    end
    context "when tar.gz ext is given" do
      before(:each) do
        cleanup_directories_before_run
        @compressor = Oddb2xml::Compressor.new('oddb', {:compress_ext => 'tar.gz'})
      end
      it 'should have formated filename with datetime' do
        @compressor.instance_variable_get(:@compress_file).
          should =~ /oddb_xml_\d{2}.\d{2}.\d{4}_\d{2}.\d{2}.tar\.gz/
      end
    end
    context "when zip ext is given" do
      before(:each) do
        cleanup_directories_before_run
        @compressor = Oddb2xml::Compressor.new('oddb', {:compress_ext => 'zip'})
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
        cleanup_directories_before_run
        @savedDir = Dir.pwd
        Dir.chdir Oddb2xml::SpecCompressor
        @compressor = Oddb2xml::Compressor.new
      end
      after(:each) do
        Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
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
          cleanup_directories_before_run
          @compressor = Oddb2xml::Compressor.new
        end
        it_behaves_like 'any compressor'
      end
      context 'with zip' do
        before(:each) do
          cleanup_directories_before_run
          @savedDir = Dir.pwd
          Dir.chdir Oddb2xml::SpecCompressor
          @compressor = Oddb2xml::Compressor.new('oddb', {:compress_ext => 'zip'})
        end
        after(:each) do
          Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
        end
        it_behaves_like 'any compressor' if true
      end
    end
  end
end
