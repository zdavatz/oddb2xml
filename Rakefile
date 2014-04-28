#!/usr/bin/env ruby
# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oddb2xml/version'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# dependencies are now declared in oddb2xml.gemspec

desc 'Offer a gem task like hoe'
task :gem => :build do
  Rake::Task[:build].invoke
end

task :spec => :clean

desc 'Run oddb2xml with all commonly used combinations'
task :test => [:clean, :spec, :gem] do
  system("./test_options.rb 2>&1 | tee test_options.log")
end

require 'rake/clean'
CLEAN.include FileList['*.xls*']
CLEAN.include FileList['*.xml*']
CLEAN.include FileList['*.dat*']
CLEAN.include FileList['*.tar.gz']
CLEAN.include FileList['*.txt.*']
CLEAN.include FileList['*.csv.*']
CLEAN.include FileList['ruby*.tmp']
CLEAN.include FileList['data/download']
CLEAN.include FileList['duplicate_ean13_from_zur_rose.txt']
