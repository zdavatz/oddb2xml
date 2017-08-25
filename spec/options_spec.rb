# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/options"

describe Oddb2xml::Options do
  include ServerMockHelper
  Default_opts =  {
    :fi           => false,
    :address      => false,
    :artikelstamm_v3 => false,
    :artikelstamm_v5 => false,
    :nonpharma    => false,
    :extended     => false,
    :compress_ext => nil,
    :format       => :xml,
    :calc         => false,
    :tag_suffix   => nil,
    :ean14        => false,
    :skip_download=> false,
    :log          => false,
    :percent      => nil,
    :use_ra11zip  => nil,
  }
  context 'when no options is passed' do
    test_opts = Oddb2xml::Options.parse('-a')
    opts = Default_opts.clone
    opts[:nonpharma] = true
    specify { expect(test_opts).to eq opts }
  end

  context 'when -c tar.gz option is given' do
    test_opts = Oddb2xml::Options.parse('-c tar.gz')
    specify { expect(test_opts[:compress_ext]).to eq('tar.gz') }
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    specify { expect(test_opts).to eq expected }
  end

  context 'when -c tar.gz option --skip-download is given' do
    test_opts = Oddb2xml::Options.parse('-c tar.gz --skip-download')
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    expected[:skip_download] = true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -c tar.gz option --skip-download is given' do
    test_opts = Oddb2xml::Options.parse('-c tar.gz --skip-download')
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    expected[:skip_download] = true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -a is given' do
    test_opts = Oddb2xml::Options.parse('-a')
    expected = Default_opts.clone
    expected[:nonpharma] =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when --append is given' do
    test_opts = Oddb2xml::Options.parse('--append ')
    expected = Default_opts.clone
    expected[:nonpharma] =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -e is given' do
    test_opts = Oddb2xml::Options.parse('-e')
    expected = Default_opts.clone
    expected[:extended]  =  true
    expected[:nonpharma] =  true
    expected[:calc]      =  true
    expected[:price]      = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context 'when -e -I 80 is given' do
    test_opts = Oddb2xml::Options.parse('-e -I 80')
    expected = Default_opts.clone
    expected[:extended]  =  true
    expected[:nonpharma] =  true
    expected[:calc]      =  true
    expected[:price]      = :zurrose
    expected[:percent]    = 80
    specify { expect(test_opts).to eq expected }
  end

  context 'when -f dat is given' do
    test_opts = Oddb2xml::Options.parse('-f dat')
    expected = Default_opts.clone
    expected[:format]  =  :dat
    specify { expect(test_opts).to eq expected }
  end

  context 'when -f dat -I 80 is given' do
    test_opts = Oddb2xml::Options.parse('-f dat -I 80')
    expected = Default_opts.clone
    expected[:format]  =  :dat
    expected[:percent] = 80
    expected[:price]   = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context 'when -I 80 is given' do
    test_opts = Oddb2xml::Options.parse('-I 80')
    expected = Default_opts.clone
    expected[:percent]   = 80
    expected[:price]   = :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context 'when -o is given' do
    test_opts = Oddb2xml::Options.parse('-o')
    expected = Default_opts.clone
    expected[:fi]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -i ean14 is given' do
    test_opts = Oddb2xml::Options.parse('-i ean14')
    expected = Default_opts.clone
    expected[:ean14]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -x addr is given' do
    test_opts = Oddb2xml::Options.parse('-x addr')
    expected = Default_opts.clone
    expected[:address]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -p zurrose is given' do
    test_opts = Oddb2xml::Options.parse('-p zurrose')
    expected = Default_opts.clone
    expected[:price]  =  :zurrose
    specify { expect(test_opts).to eq expected }
  end

  context 'when -o fi --log is given' do
    test_opts = Oddb2xml::Options.parse('-o fi --log')
    expected = Default_opts.clone
    expected[:fi]  =  true
    expected[:log]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -a nonpharma -p zurrose is given' do
    args = '-a nonpharma -p zurrose'
    test_opts = Oddb2xml::Options.parse(args) # .should raise
    expected = Default_opts.clone
    expected[:price]  =  :zurrose
    expected[:nonpharma]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when --artikelstamm_v5 is given' do
    args = '--artikelstamm-v5'
    test_opts = Oddb2xml::Options.parse(args) # .should raise
    expected = Default_opts.clone
    expected[:price]  =  :zurrose
    expected[:extended]  =  true
    expected[:artikelstamm_v5]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -c tar.gz option is given' do
    test_opts = Oddb2xml::Options.parse('-c tar.gz')
    specify { expect(test_opts[:compress_ext]).to eq('tar.gz') }
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    specify { expect(test_opts).to eq expected }
  end

  context 'when  --use-ra11zip is given' do
    test_opts = Oddb2xml::Options.parse(' --use-ra11zip some_other_zip')
    expected = Default_opts.clone
    expected[:use_ra11zip] = 'some_other_zip'
    # expected[:price]  =  :zurrose
    # expected[:extended]  =  true
    # expected[:artikelstamm_v5]  =  true
    specify { expect(test_opts).to eq expected }
  end

  context 'when -t swiss is given' do
    test_opts = Oddb2xml::Options.parse('-t swiss')
    expected = Default_opts.clone
    expected[:tag_suffix]  =  'swiss'
    specify { expect(test_opts).to eq expected }
  end

end

