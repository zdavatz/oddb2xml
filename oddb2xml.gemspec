# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oddb2xml/version'

Gem::Specification.new do |spec|
  spec.name        = "oddb2xml"
  spec.version     = Oddb2xml::VERSION
  spec.author      = "Yasuhiro Asaka, Zeno R.R. Davatz"
  spec.email       = "yasaka@ywesee.com, zdavatz@ywesee.com"
  spec.description = "oddb2xml creates xml files using swissINDEX, BAG-XML and Swissmedic."
  spec.summary     = "oddb2xml creates xml files."
  spec.homepage    = "https://github.com/zdavatz/oddb2xml"
  spec.license       = "GPL-v2"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rubyzip', '~> 1.0'
  spec.add_dependency 'archive-tar-minitar'
  spec.add_dependency 'mechanize', '~> 2.5.1'
  spec.add_dependency 'nokogiri', '~> 1.5.10'
  spec.add_dependency 'savon', '~> 2.0'
  spec.add_dependency 'spreadsheet'
  spec.add_dependency 'rubyXL', '~> 2.5'
  
  
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rdoc"
end

