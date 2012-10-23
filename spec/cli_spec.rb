# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any interface' do
  it { cli.should respond_to(:run)  }
  it 'should run successfully' do
    $stdout.should_receive(:puts).with(/product/)
    cli.run
  end
end

describe Oddb2xml::Cli do
  include ServerMockHelper
  before(:each) do
    setup_server_mocks
  end
  context "when -c tar.gz option is given" do
    let(:cli) { Oddb2xml::Cli.new({:compress => 'tar.gz', :nonpharma => false}) }
    it { cli.instance_variable_get(:@options).should == {:compress => 'tar.gz', :nonpharma => false} }
    it_behaves_like 'any interface'
    it "should create tar.gz file" do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      file = Dir.glob('oddb_*.tar.gz').first
      File.exists?(file).should be_true
    end
    it "should not create any xml file" do
      $stdout.should_receive(:puts).with(/Nonpharma/)
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
  context "when -a nonpharma option is given" do
    let(:cli) { Oddb2xml::Cli.new({:compress => nil, :nonpharma => true}) }
    it { cli.instance_variable_get(:@options).should == {:compress => nil, :nonpharma => true} }
    it_behaves_like 'any interface'
    it "should not create any compressed file" do
      $stdout.should_receive(:puts).with(/Pharma/)
      cli.run
      Dir.glob('oddb_*.tar.gz').first.should be_nil
    end
    it "should create 2 xml files" do
      $stdout.should_receive(:puts).with(/Nonpharma/)
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
