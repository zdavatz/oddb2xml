# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/options"
module Kernel
  def cli_capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

describe Oddb2xml::Options do
  include ServerMockHelper
  Default_opts =  {
    :fi           => false,
    :adr          => false,
    :address      => false,
    :nonpharma    => false,
    :extended     => false,
    :compress_ext => nil,
    :format       => :xml,
    :calc         => false,
    :tag_suffix   => nil,
    :debug        => false,
    :ean14        => false,
    :skip_download=> false,
    :log          => false,
    :percent      => nil,
  }
  context 'when default_opts' do
    specify { expect(Oddb2xml::Options.default_opts).to eq  Default_opts }
  end

  context 'when no options is passed' do
    options = Oddb2xml::Options.new
    specify { expect(options.opts).to eq Default_opts }
  end

  context 'when -c tar.gz option is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-c tar.gz'.split(' '))
    specify { expect(options.opts[:compress_ext]).to eq('tar.gz') }
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    specify { expect(options.opts).to eq expected }
  end

  context 'when -c tar.gz option --skip-download is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-c tar.gz --skip-download'.split(' '))
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    expected[:skip_download] = true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -c tar.gz option --skip-download is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-c tar.gz --skip-download'.split(' '))
    expected = Default_opts.clone
    expected[:compress_ext] = 'tar.gz'
    expected[:skip_download] = true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -a is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-a'.split(' '))
    expected = Default_opts.clone
    expected[:nonpharma] =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when --append is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('--append '.split(' '))
    expected = Default_opts.clone
    expected[:nonpharma] =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -e is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-e'.split(' '))
    expected = Default_opts.clone
    expected[:extended]  =  true
    expected[:nonpharma] =  true
    expected[:price]      = :zurrose
    specify { expect(options.opts).to eq expected }
  end

  context 'when -e is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-e'.split(' '))
    expected = Default_opts.clone
    expected[:extended]  =  true
    expected[:nonpharma] =  true
    expected[:price]      = :zurrose
    specify { expect(options.opts).to eq expected }
  end

  context 'when -e -I 80 is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-e -I 80'.split(' '))
    expected = Default_opts.clone
    expected[:extended]  =  true
    expected[:nonpharma] =  true
    expected[:price]      = :zurrose
    expected[:percent]    = 80
    specify { expect(options.opts).to eq expected }
  end

  context 'when -f dat is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-f dat'.split(' '))
    expected = Default_opts.clone
    expected[:format]  =  :dat
    specify { expect(options.opts).to eq expected }
  end

  context 'when -f dat -I 80 is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-f dat -I 80'.split(' '))
    expected = Default_opts.clone
    expected[:format]  =  :dat
    expected[:percent] = 80
    expected[:price]   = :zurrose
    specify { expect(options.opts).to eq expected }
  end

  context 'when -I 80 is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-I 80'.split(' '))
    expected = Default_opts.clone
    expected[:percent]   = 80
    expected[:price]   = :zurrose
    specify { expect(options.opts).to eq expected }
  end

  context 'when -o is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-o'.split(' '))
    expected = Default_opts.clone
    expected[:fi]  =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -i ean14 is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-i ean14'.split(' '))
    expected = Default_opts.clone
    expected[:ean14]  =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -x addr is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-x addr'.split(' '))
    expected = Default_opts.clone
    expected[:address]  =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -p zurrose is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-p zurrose'.split(' '))
    expected = Default_opts.clone
    expected[:price]  =  :zurrose
    specify { expect(options.opts).to eq expected }
  end

  context 'when -o fi --log is given' do
    options = Oddb2xml::Options.new
    options.parser.parse!('-o fi --log'.split(' '))
    expected = Default_opts.clone
    expected[:fi]  =  true
    expected[:log]  =  true
    specify { expect(options.opts).to eq expected }
  end

  context 'when -a nonpharma -p zurrose is given' do
    options = Oddb2xml::Options.new
    args = '-a nonpharma -p zurrose'.split(' ')
    options.parser.parse!(args) # .should raise
    expected = Default_opts.clone
    expected[:price]  =  :zurrose
    expected[:nonpharma]  =  true
    specify { expect(options.opts).to eq expected }
    specify { expect(args).to eq ["nonpharma", "zurrose"] } # will lead to an exit 2 in bin/oddb2xml
  end

  context 'when --calc is given' do
    options = Oddb2xml::Options.new
    args = '--calc'.split(' ')
    options.parser.parse!(args) # .should raise
    expected = Default_opts.clone
    expected[:calc]  =  true
    specify { expect(options.opts).to eq expected }
    specify { expect(args).to eq [] }
  end
end

