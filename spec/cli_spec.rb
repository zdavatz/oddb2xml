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
  it { @cli.should respond_to(:run) }
  it 'should run successfully' do
    @cli_output.should match(/products/)
  end
end

shared_examples_for 'any interface for address' do
  it { buildr_capture(:stdout) { @cli.should respond_to(:run) } }
  it 'should run successfully' do
    @cli_output.should match(/addresses/)
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
    Dir.chdir(Oddb2xml::WorkDir)
  end
  after(:all) do
    Dir.chdir(@savedDir) if @savedDir and File.directory?(@savedDir)
    cleanup_compressor
  end

  context 'when -x address option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-e --log'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
  end
  context 'when -o fi option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-o fi'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
 #     @cli_output = buildr_capture(:stdout) { @cli.run }
      @cli.run
    end
#    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      @cli.should have_option(:fi => true)
    end
  end

  context 'when -t md option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-t md'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have tag_suffix option' do
      @cli.should have_option(:tag_suffix=> 'MD')
    end
    it 'should not create a compressed file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
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
      @cli_output.should match(/Pharma products:/)
    end
  end

  context 'when -c tar.gz option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-c tar.gz'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
      # @cli_output = @cli.run # to debug
    end

    it_behaves_like 'any interface for product'
    it 'should not create any xml file' do
        @cli_output.should match(/Pharma/)
        Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
    it 'should have compress option' do
      @cli.should have_option(:compress_ext => 'tar.gz')
    end
    it 'should create tar.gz file' do
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.tar.gz')).first
      File.exists?(file).should eq true
    end
    it 'should not create any xml file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
  end

  context 'when -c zip option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-c zip'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have compress option' do
      @cli.should have_option(:compress_ext => 'zip')
    end
    it 'should create zip file' do
      @cli_output.should match(/Pharma/)
      file = Dir.glob(File.join(Dir.pwd, 'oddb_*.zip')).first
      File.exists?(file).should eq true
    end
    it 'should not create any xml file' do
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file| FileUtil.rm_f(file) end
      @cli_output.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.xml')).each do |file|
        File.exists?(file).should be_false
      end
    end
  end

  context 'when -f dat option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      @cli.should have_option(:format => :dat, :extended => false)
    end
    it 'should create the needed files' do
      @cli_output.should match(/\sPharma\s/)
      expected = [
        'duplicate_ean13_from_zur_rose.txt',
        'zurrose_transfer.dat',
        'oddb.dat',
      ].each{ |file|
        File.exists?(File.join(Oddb2xml::WorkDir, file)).should eq true
            }
    end
  end

  context 'when -a nonpharma option is given' do
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-a nonpharma'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      @cli.should have_option(:nonpharma => true)
    end
    it 'should not create any compressed file' do
      @cli_output.should match(/NonPharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      @cli_output.should match(/NonPharma/)
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
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-t _swiss'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have tag_suffix option' do
      @cli.should have_option(:tag_suffix=> '_SWISS')
    end
    it 'should not create any compressed file' do
      @cli_output.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files with prefix swiss_' do
      @cli_output.should match(/Pharma/)
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
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-o fi'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for product'
    it 'should have nonpharma option' do
      @cli.should have_option(:fi => true)
    end
    it 'should not create any compressed file' do
      @cli_output.should match(/Pharma/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      @cli_output.should match(/Pharma/)
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
    before(:all) do
      cleanup_directories_before_run
      options = Oddb2xml::Options.new
      options.parser.parse!('-x address'.split(' '))
      @cli = Oddb2xml::Cli.new(options.opts)
      @cli_output = buildr_capture(:stdout) { @cli.run }
    end
    it_behaves_like 'any interface for address'
    it 'should have address option' do
      @cli.should have_option(:address=> true)
    end
    it 'should not create any compressed file' do
      @cli_output.should match(/addresses/)
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.tar.gz')).first.should be_nil
      Dir.glob(File.join(Oddb2xml::WorkDir, 'oddb_*.zip')).first.should be_nil
    end
    it 'should create xml files' do
      @cli_output.should match(/addresses/)
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