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
  it { expect(@cli).to respond_to(:run) }
  it 'should run successfully' do
    expect(@cli_output).to match(/products/)
  end
end

shared_examples_for 'any interface for address' do
  it { buildr_capture(:stdout) { expect(@cli).to respond_to(:run) } }
  it 'should run successfully' do
    expect(@cli_output).to match(/addresses/)
  end
end

describe Oddb2xml::Cli do
  # Setting ShouldRun to false and changing one -> if true allows you
  # to run easily the failing test
  include ServerMockHelper
  before(:all) do
    VCR.eject_cassette
    VCR.insert_cassette('oddb2xml')
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WorkDir)
    Dir.chdir(Oddb2xml::WorkDir)
  end
  after(:all) do
    Dir.chdir(@savedDir) if @savedDir and File.directory?(@savedDir)
    cleanup_compressor
  end

  context 'when -x address option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-e --log')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
  end
  context 'when -o fi option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-o fi')
      @cli = Oddb2xml::Cli.new(options)
 #     @cli_output = buildr_capture(:stdout) { @cli.run }
      @cli.run
    end
#    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      expect(@cli).to have_option(:fi => true)
    end
  end

  context 'when -t md option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-t md')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have tag_suffix option' do
      expect(@cli).to have_option(:tag_suffix=> 'MD')
    end
    it 'should not create a compressed file' do
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first).to be_nil
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first).to be_nil
    end
    it 'should create xml files with prefix swiss_' do
      expected = [
        'md_product.xml',
        'md_article.xml',
        'md_limitation.xml',
        'md_substance.xml',
        'md_interaction.xml',
        'md_code.xml'
      ]
      expected.each{
          |name|
        tst_file = File.join(Oddb2xml::WorkDir, name)
        expect(Dir.glob(tst_file).size).to eq 1
        tst_size = File.size(tst_file)
        if tst_size < 1024
          puts "File #{name} is only #{tst_size} bytes long"
        end
        expect(tst_size).to be >= 400
      }
    end
    it 'should produce a correct report' do
      expect(@cli_output).to match(/Pharma products:/)
    end
  end

  context 'when -c tar.gz option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-c tar.gz')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
      # @cli_output = @cli.run # to debug
    end

    it_behaves_like 'any interface for product'
    it 'should not create any xml file' do
        expect(@cli_output).to match(/Pharma/)
        Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to be_falsey
      end
    end
    it 'should have compress option' do
      expect(@cli).to have_option(:compress_ext => 'tar.gz')
    end
    it 'should create tar.gz file' do
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.tar.gz')).first
      expect(File.exists?(file)).to eq true
    end
    it 'should not create any xml file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to be_falsey
      end
    end
  end

  context 'when -c zip option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-c zip')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have compress option' do
      expect(@cli).to have_option(:compress_ext => 'zip')
    end
    it 'should create zip file' do
      expect(@cli_output).to match(/Pharma/)
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.zip')).first
      expect(File.exists?(file)).to eq true
    end
    it 'should not create any xml file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file| FileUtil.rm_f(file) end
      expect(@cli_output).to match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to be_falsey
      end
    end
  end

  context 'when -f dat option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-f dat')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      expect(@cli).to have_option(:format => :dat, :extended => false)
    end
    it 'should create the needed files' do
      expect(@cli_output).to match(/\sPharma\s/)
      expect(File.exists?(File.join(Oddb2xml::Downloads, 'transfer.zip'))).to eq true
      expect(File.exists?(File.join(Oddb2xml::WorkDir, 'transfer.zip'))).to eq false
      expected = [
        'duplicate_ean13_from_zur_rose.txt',
        'oddb.dat',
      ].each{ |file|
        expect(File.exists?(File.join(Oddb2xml::WorkDir, file))).to eq true
            }
    end
  end

  context 'when -a nonpharma option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-a nonpharma')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      expect(@cli).to have_option(:nonpharma => true)
    end
    it 'should not create any compressed file' do
      expect(@cli_output).to match(/NonPharma/)
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first).to be_nil
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first).to be_nil
    end
    it 'should create xml files' do
      expect(@cli_output).to match(/NonPharma/)
      expected = [
        'oddb_product.xml',
        'oddb_article.xml',
        'oddb_limitation.xml',
        'oddb_substance.xml',
        'oddb_interaction.xml',
        'oddb_code.xml'
      ].length
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to eq true
      end.to_a.length).to equal expected
    end
  end
  context 'when -t _swiss option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-t _swiss')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have tag_suffix option' do
      expect(@cli).to have_option(:tag_suffix=> '_SWISS')
    end
    it 'should not create any compressed file' do
      expect(@cli_output).to match(/Pharma/)
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first).to be_nil
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first).to be_nil
    end
    it 'should create xml files with prefix swiss_' do
      expect(@cli_output).to match(/Pharma/)
      expected = [
        'swiss_product.xml',
        'swiss_article.xml',
        'swiss_limitation.xml',
        'swiss_substance.xml',
        'swiss_interaction.xml',
        'swiss_code.xml'
      ].length
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'swiss_*.xml')).each do |file|
        expect(File.exists?(file)).to eq true
      end.to_a.length).to equal expected
    end
  end
  context 'when -o fi option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-o fi')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      expect(@cli).to have_option(:fi => true)
    end
    it 'should not create any compressed file' do
      expect(@cli_output).to match(/Pharma/)
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first).to be_nil
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first).to be_nil
    end
    it 'should create xml files' do
      expect(@cli_output).to match(/Pharma/)
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
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to eq true
      end.to_a.length).to equal expected
    end
  end
  context 'when -x address option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.parse('-x address')
      @cli = Oddb2xml::Cli.new(options)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for address'
    it 'should have address option' do
      expect(@cli).to have_option(:address=> true)
    end
    it 'should not create any compressed file' do
      pending 'Cannot download medreg at the moment'
      expect(@cli_output).to match(/addresses/)
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first).to be_nil
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first).to be_nil
    end
    it 'should create xml files' do
      pending 'Cannot download medreg at the moment'
      expect(@cli_output).to match(/addresses/)
      expected = [
        'oddb_betrieb.xml',
        'oddb_medizinalperson.xml',
      ].length
      expect(Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        expect(File.exists?(file)).to eq true
      end.to_a.length).to equal expected
    end
  end if false # TODO: pending medreg
end
