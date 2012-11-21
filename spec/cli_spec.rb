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
    let(:cli) { Oddb2xml::Cli.new({:compress_ext => 'tar.gz', :nonpharma => false}) }
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
  context 'when -a nonpharma option is given' do
    let(:cli) { Oddb2xml::Cli.new({:compress_ext => nil, :nonpharma => true}) }
    it_behaves_like 'any interface'
    it 'should have nonpharma option' do
      cli.should have_option(:nonpharma => true)
    end
    it 'should not create any compressed file' do
      $stdout.should_receive(:puts).with(/NonPharma/)
      cli.run
      Dir.glob('oddb_*.tar.gz').first.should be_nil
    end
    it 'should create 2 xml files' do
      $stdout.should_receive(:puts).with(/NonPharma/)
      cli.run
      Dir.glob('oddb_*.xml').each do |file|
        File.exists?(file).should be_true
      end
    end
    after(:each) do
      Dir.glob('oddb_*.xml').each do |file|
        File.unlink(file) if File.exists?(file)
      end
    end
  end
end
