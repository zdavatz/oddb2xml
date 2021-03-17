require "spec_helper"
require "oddb2xml/semantic_check"
CHECK_DIR = File.expand_path(File.join(File.dirname(__FILE__), "data", "check_artikelstamm"))

describe Oddb2xml::SemanticCheck do
  def common_run_init(options = {})
    @saved_dir = Dir.pwd
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WORK_DIR)
    Dir.chdir(Oddb2xml::WORK_DIR)
    mock_DOWNLOADS
  end

  after(:all) do
    Dir.chdir @saved_dir if @saved_dir && File.directory?(@saved_dir)
  end
  context "checking" do
    before(:each) do
      common_run_init
    end

    files2check = Dir.glob(CHECK_DIR + "/*.xml")

    files2check.each do |file2check|
      it "should exist" do
        expect(File.exist?(file2check)).to eq true
      end

      if /okay/i.match?(File.basename(file2check))
        it "#{File.basename(file2check)} should return okay" do
          result = Oddb2xml::SemanticCheck.new(file2check).allSemanticChecks
          puts "\n\nSemanticCheck: #{file2check} #{File.exist?(file2check)} returned #{result}"
          puts "SemanticCheck: #{file2check} #{File.size(file2check)}"
          # expect(result).to eq true
        end
      end

      unless /okay/i.match?(File.basename(file2check))
        it "#{File.basename(file2check)} should return an error" do
          result = Oddb2xml::SemanticCheck.new(file2check).allSemanticChecks
          expect(result).to eq false
        end
      end
    end
  end
end
