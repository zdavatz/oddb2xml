# encoding: utf-8

require 'spec_helper'
require 'oddb2xml/semantic_check'

describe Oddb2xml::SemanticCheck do
  CheckDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'check_artikelstamm'))

  def common_run_init(options = {})
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WorkDir)
    Dir.chdir(Oddb2xml::WorkDir)
    mock_downloads
  end

  after(:all) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  context 'checking' do
    before(:each) do
      common_run_init
    end
    
    files2check = Dir.glob(CheckDir + '/*.xml')

    files2check.each do |file2check|
      it 'should exist' do
        expect(File.exists?(file2check)).to eq true
      end

      it "#{File.basename(file2check)} should return okay" do
        result = Oddb2xml::SemanticCheck.new(file2check).allSemanticChecks
        expect(result).to eq true
      end if /okay/i.match(File.basename(file2check))

      it "#{File.basename(file2check)} should return an error" do
        result = Oddb2xml::SemanticCheck.new(file2check).allSemanticChecks
        expect(result).to eq false
      end unless /okay/i.match(File.basename(file2check))

    end
  end
end
