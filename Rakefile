#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'hoe'

# Hoe.plugin :compiler
# Hoe.plugin :gem_prelude_sucks
# Hoe.plugin :inline
# Hoe.plugin :minitest
# Hoe.plugin :racc
# Hoe.plugin :rubyforge

Hoe.spec 'oddb2xml' do
  self.author      = "Yasuhiro Asaka, Zeno R.R. Davatz" # gem.authors
  self.email       = "yasaka@ywesee.com, zdavatz@ywesee.com"
  self.description = "oddb2xml creates xml files using swissINDEX, BAG-XML and Swissmedic."
  self.summary     = "oddb2xml creates xml files."
  self.urls        = ["https://github.com/zdavatz/oddb2xml"] # gem.homepage

  #please keep the version here in sync with the ones in the Gemfile
  # gem.add_runtime_dependency
  self.extra_deps << ['rubyzip']
  self.extra_deps << ['archive-tar-minitar']
  self.extra_deps << ['mechanize', '~> 2.5.1']
  self.extra_deps << ['nokogiri']
  self.extra_deps << ['savon', '>= 2.0']
  self.extra_deps << ['spreadsheet']
  self.extra_deps << ['rubyXL', '~> 2.5']

  # gem.add_development_dependency
  self.extra_dev_deps << ['rspec']
  self.extra_dev_deps << ['webmock']

  self.extra_dev_deps << ['hoe', '>= 3.4']
  self.extra_dev_deps << ['rdoc']
end
