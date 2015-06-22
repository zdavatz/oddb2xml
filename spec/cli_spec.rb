# encoding: utf-8

require 'spec_helper'

RSpec::Matchers.define :have_option do |option|
  match do |interface|
    key = option.keys.first
    val = option.values.first
    options = interface.instance_variable_get(:@options)
    options[key] == val
  end
  description do
    "have #{option.keys.first} option as #{option.values.first}"
  end
end

shared_examples_for 'any interface for product' do
  it { buildr_capture(:stdout) { cli.should respond_to(:run) } }
  it 'should run successfully' do
    buildr_capture(:stdout){ cli.run }.should match(/products/)
  end
end

shared_examples_for 'any interface for address' do
  it { buildr_capture(:stdout) { cli.should respond_to(:run) } }
  it 'should run successfully' do
    buildr_capture(:stdout){ cli.run }.should match(/addresses/)
  end
end

describe Oddb2xml::Cli do
  # Setting ShouldRun to false and changing one -> if true allows you
  # to run easily the failing test
  include ServerMockHelper
  before(:each) do
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    Dir.chdir(Oddb2xml::WorkDir)
  end
  after(:each) do
    Dir.chdir(@savedDir) if @savedDir and File.directory?(@savedDir)
    cleanup_compressor
  end
  context 'when -c tar.gz option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-c tar.gz'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it 'should not create any xml file' do
        buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
        Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
  if true
    it_behaves_like 'any interface for product'
    it 'should have compress option' do
      cli.should have_option(:compress_ext => 'tar.gz')
    end
    it 'should create tar.gz file' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.tar.gz')).first
      File.exists?(file).should eq true
    end
    end
    it 'should not create any xml file' do
      cli.run
#      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
  end
  if true
  context 'when -c zip option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-c zip'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it_behaves_like 'any interface for product'
    it 'should have compress option' do
      cli.should have_option(:compress_ext => 'zip')
    end
    it 'should create zip file' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.zip')).first
      File.exists?(file).should eq true
    end
    it 'should not create any xml file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file| FileUtil.rm_f(file) end
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
  end
  context 'when -a nonpharma option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-a nonpharma'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      cli.should have_option(:nonpharma => true)
    end
    it 'should not create any compressed file' do
      buildr_capture(:stdout) { cli.run }.should match(/NonPharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      buildr_capture(:stdout) { cli.run }.should match(/NonPharma/)
      expected = [
        'oddb_product.xml',
        'oddb_article.xml',
        'oddb_limitation.xml',
        'oddb_substance.xml',
        'oddb_interaction.xml',
        'oddb_code.xml'
      ].length
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should eq true
      end.to_a.length.should equal expected
    end
  end
  context 'when -t _swiss option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-t _swiss'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it_behaves_like 'any interface for product'
    it 'should have tag_suffix option' do
      cli.should have_option(:tag_suffix=> '_SWISS')
    end
    it 'should not create any compressed file' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files with prefix swiss_' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      expected = [
        'swiss_product.xml',
        'swiss_article.xml',
        'swiss_limitation.xml',
        'swiss_substance.xml',
        'swiss_interaction.xml',
        'swiss_code.xml'
      ].length
      Dir.glob(File.join(Oddb2xml::WorkDir, 'swiss_*.xml')).each do |file|
        File.exists?(file).should eq true
      end.to_a.length.should equal expected
    end
  end
  context 'when -o fi option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-o fi'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      cli.should have_option(:fi => true)
    end
    it 'should not create any compressed file' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      buildr_capture(:stdout) { cli.run }.should match(/Pharma/)
      expected = [
        'oddb_fi.xml',
        'oddb_fi_product.xml',
        'oddb_product.xml',
        'oddb_article.xml',
        'oddb_limitation.xml',
        'oddb_substance.xml',
        'oddb_interaction.xml',
        'oddb_code.xml'
      ].length
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should eq true
      end.to_a.length.should equal expected
    end
  end
  context 'when -x address option is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-x address'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it_behaves_like 'any interface for address'
    it 'should have address option' do
      cli.should have_option(:address=> true)
    end
    it 'should not create any compressed file' do
      buildr_capture(:stdout) { cli.run }.should match(/addresses/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      buildr_capture(:stdout) { cli.run }.should match(/addresses/)
      expected = [
        'oddb_betrieb.xml',
        'oddb_medizinalperson.xml',
      ].length
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should eq true
      end.to_a.length.should equal expected
    end
  end
  end
end
