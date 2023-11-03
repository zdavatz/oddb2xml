require "spec_helper"
require "#{Dir.pwd}/lib/oddb2xml/options"

Oddb2xml::DEFAULT_OPTS = {
  fi: false,
  address: false,
  artikelstamm: false,
  nonpharma: false,
  extended: false,
  compress_ext: nil,
  format: :xml,
  calc: false,
  tag_suffix: nil,
  ean14: false,
  skip_download: false,
  log: false,
  percent: nil,
  use_ra11zip: nil,
  firstbase: false,
}

describe Oddb2xml::Options do
  include ServerMockHelper
  context "when no options is passed" do
    test_opts = Oddb2xml::Options.parse("-a")
    opts = Oddb2xml::DEFAULT_OPTS.clone
    opts[:nonpharma] = true
    specify { expect(test_opts).to eq opts }
  end

  context "when -c tar.gz option is given" do
    test_opts = Oddb2xml::Options.parse("-c tar.gz")
    specify { expect(test_opts[:compress_ext]).to eq("tar.gz") }
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:compress_ext] = "tar.gz"
    specify { expect(test_opts).to eq expected }
  end

  context "when -c tar.gz option --skip-download is given" do
    test_opts = Oddb2xml::Options.parse("-c tar.gz --skip-download")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:compress_ext] = "tar.gz"
    expected[:skip_download] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -c tar.gz option --skip-download is given" do
    test_opts = Oddb2xml::Options.parse("-c tar.gz --skip-download")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:compress_ext] = "tar.gz"
    expected[:skip_download] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -a is given" do
    test_opts = Oddb2xml::Options.parse("-a")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:nonpharma] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when --append is given" do
    test_opts = Oddb2xml::Options.parse("--append ")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:nonpharma] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -e is given" do
    test_opts = Oddb2xml::Options.parse("-e")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:extended] = true
    expected[:nonpharma] = true
    expected[:calc] = true
    expected[:price] = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context "when -e -I 80 is given" do
    test_opts = Oddb2xml::Options.parse("-e -I 80")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:extended] = true
    expected[:nonpharma] = true
    expected[:calc] = true
    expected[:price] = :zurrose
    expected[:percent] = 80
    specify { expect(test_opts).to eq expected }
  end

  context "when -f dat is given" do
    test_opts = Oddb2xml::Options.parse("-f dat")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:format] = :dat
    specify { expect(test_opts).to eq expected }
  end

  context "when -f dat -I 80 is given" do
    test_opts = Oddb2xml::Options.parse("-f dat -I 80")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:format] = :dat
    expected[:percent] = 80
    expected[:price] = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context "when -I 80 is given" do
    test_opts = Oddb2xml::Options.parse("-I 80")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:percent] = 80
    expected[:price] = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context "when -o is given" do
    test_opts = Oddb2xml::Options.parse("-o")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:fi] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -i ean14 is given" do
    test_opts = Oddb2xml::Options.parse("-i ean14")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:ean14] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -x addr is given" do
    test_opts = Oddb2xml::Options.parse("-x addr")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:address] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -p zurrose is given" do
    test_opts = Oddb2xml::Options.parse("-p zurrose")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:price] = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context "when -o fi --log is given" do
    test_opts = Oddb2xml::Options.parse("-o fi --log")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:fi] = true
    expected[:log] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -a nonpharma -p zurrose is given" do
    args = "-a nonpharma -p zurrose"
    test_opts = Oddb2xml::Options.parse(args) # .should raise
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:price] = :zurrose
    expected[:nonpharma] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when --artikelstamm is given" do
    args = "--artikelstamm"
    test_opts = Oddb2xml::Options.parse(args) # .should raise
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:price] = :zurrose
    expected[:extended] = true
    expected[:artikelstamm] = true
    specify { expect(test_opts).to eq expected }
  end

  context "when -c tar.gz option is given" do
    test_opts = Oddb2xml::Options.parse("-c tar.gz")
    specify { expect(test_opts[:compress_ext]).to eq("tar.gz") }
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:compress_ext] = "tar.gz"
    specify { expect(test_opts).to eq expected }
  end

  context "when  --use-ra11zip is given" do
    test_opts = Oddb2xml::Options.parse(" --use-ra11zip some_other_zip")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:use_ra11zip] = "some_other_zip"
    # expected[:price]  =  :zurrose
    # expected[:extended]  =  true
    # expected[:artikelstamm]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context "when -t swiss is given" do
    test_opts = Oddb2xml::Options.parse("-t swiss")
    expected = Oddb2xml::DEFAULT_OPTS.clone
    expected[:tag_suffix] = "swiss"
    specify { expect(test_opts).to eq expected }
  end
end
