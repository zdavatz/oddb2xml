# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oddb2xml/version'

Gem::Specification.new do |spec|
  spec.name        = "oddb2xml"
  spec.version     = Oddb2xml::VERSION + '-artikelstamm-v5'
  spec.author      = "Yasuhiro Asaka, Zeno R.R. Davatz, Niklaus Giger"
  spec.email       = "yasaka@ywesee.com, zdavatz@ywesee.com, ngiger@ywesee.com"
  spec.description = "oddb2xml creates xml files using swissINDEX, BAG-XML and Swissmedic."
  spec.summary     = "oddb2xml creates xml files."
  spec.homepage    = "https://github.com/zdavatz/oddb2xml"
  spec.license       = "GPL-3.0"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # We fix the version of the spec to newer versions only in the third position
  # hoping that these version fix only security/severe bugs
  # Consulted the Gemfile.lock to get
  spec.add_dependency 'rubyzip'#, '~> 1.1.3'
  spec.add_dependency 'minitar'#, '~> 0.5.2'
  spec.add_dependency 'mechanize'#, '~> 2.5.1'
  spec.add_dependency 'nokogiri', '>= 1.8.2'
  spec.add_dependency 'savon'#, '~> 2.11.0'
  spec.add_dependency 'spreadsheet'#, '~> 1.0.0'
  spec.add_dependency 'rubyXL'#, '~> 3.3.1'
  spec.add_dependency 'sax-machine'#,  '~> 0.1.0'
  spec.add_dependency 'parslet'#, '~> 1.7.0'
  spec.add_dependency 'rubyntlm', '0.5.1'
  spec.add_dependency 'multi_json'#, '>= 0.3.2'
  spec.add_dependency 'rack', '< 2.0'
  spec.add_dependency 'httpi' #, '>= 2.4.1'
  spec.add_dependency 'trollop' #, '>= 2.4.1'
  spec.add_dependency 'xml-simple'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "flexmock"
end

