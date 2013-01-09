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

shared_examples_for 'any interface' do
  it { cli.should respond_to(:run)  }
  it 'should run successfully' do
    $stdout.should_receive(:puts).with(/products/)
    cli.run
  end
end

describe Oddb2xml::Cli do
  include ServerMockHelper
  before(:each) do
    setup_server_mocks
  end
  context 'when -c tar.gz option is given' do
    let(:cli) do
      opts = {
        :compress_ext => 'tar.gz',
        :nonpharma    => false,
        :fi           => false,
        :tag_suffix   => nil,
      }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface'
    it 'should have compress option' do
      cli.should have_option(:compress_ext => 'tar.gz')
    end
    it 'should create tar.gz file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      file = Dir.glob('oddb_*.tar.gz').first
      File.exists?(file).should be_true
    end
    it 'should not create any xml file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      Dir.glob('oddb_*.xml').each do |file|
        File.exists?(file).should be_nil
      end
    end
    after(:each) do
      Dir.glob('oddb_*.tar.gz').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
  context 'when -c zip option is given' do
    let(:cli) do
      opts = {
        :compress_ext => 'zip',
        :nonpharma    => false,
        :fi           => false,
        :tag_suffix   => nil,
      }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface'
    it 'should have compress option' do
      cli.should have_option(:compress_ext => 'zip')
    end
    it 'should create zip file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      file = Dir.glob('oddb_*.zip').first
      File.exists?(file).should be_true
    end
    it 'should not create any xml file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      Dir.glob('oddb_*.xml').each do |file|
        File.exists?(file).should be_nil
      end
    end
    after(:each) do
      Dir.glob('oddb_*.zip').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
  context 'when -a nonpharma option is given' do
    let(:cli) do
      opts = {
        :compress_ext => nil,
        :nonpharma    => true,
        :fi           => false,
        :tag_suffix   => nil,
      }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface'
    it 'should have nonpharma option' do
      cli.should have_option(:nonpharma => true)
    end
    it 'should not create any compressed file' do
      $stdout.should_receive(:puts).with(/NonPharma/)
      cli.run
      Dir.glob('oddb_*.tar.gz').first.should be_nil
      Dir.glob('oddb_*.zip').first.should be_nil
    end
    it 'should create xml files' do
      $stdout.should_receive(:puts).with(/NonPharma/)
      cli.run
      expected = [
        'oddb_product.xml',
        'oddb_article.xml',
        'oddb_limitation.xml',
        'oddb_substance.xml',
        'oddb_interaction.xml',
        'oddb_code.xml'
      ].length
      Dir.glob('oddb_*.xml').each do |file|
        File.exists?(file).should be_true
      end.to_a.length.should equal expected
    end
    after(:each) do
      Dir.glob('oddb_*.xml').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
  context 'when -t _swiss option is given' do
    let(:cli) do
      opts = {
        :compress_ext => nil,
        :nonpharma    => false,
        :fi           => false,
        :tag_suffix   => '_swiss'.upcase,
      }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface'
    it 'should have tag_suffix option' do
      cli.should have_option(:tag_suffix=> '_SWISS')
    end
    it 'should not create any compressed file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      Dir.glob('oddb_*.tar.gz').first.should be_nil
      Dir.glob('oddb_*.zip').first.should be_nil
    end
    it 'should create xml files with prefix swiss_' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      expected = [
        'swiss_product.xml',
        'swiss_article.xml',
        'swiss_limitation.xml',
        'swiss_substance.xml',
        'swiss_interaction.xml',
        'swiss_code.xml'
      ].length
      Dir.glob('swiss_*.xml').each do |file|
        File.exists?(file).should be_true
      end.to_a.length.should equal expected
    end
    after(:each) do
      Dir.glob('swiss_*.xml').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
  context 'when -o fi option is given' do
    let(:cli) do
      opts = {
        :compress_ext => nil,
        :nonpharma    => false,
        :fi           => true,
        :tag_suffix   => nil,
      }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface'
    it 'should have nonpharma option' do
      cli.should have_option(:fi => true)
    end
    it 'should not create any compressed file' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      Dir.glob('oddb_*.tar.gz').first.should be_nil
      Dir.glob('oddb_*.zip').first.should be_nil
    end
    it 'should create xml files' do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
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
      Dir.glob('oddb_*.xml').each do |file|
        File.exists?(file).should be_true
      end.to_a.length.should equal expected
    end
    after(:each) do
      Dir.glob('oddb_*.xml').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
end
