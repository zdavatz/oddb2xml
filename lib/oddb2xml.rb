# frozen_string_literal: true

require "oddb2xml/version"
require "oddb2xml/util"
require "oddb2xml/options"
require "oddb2xml/downloader"
require "oddb2xml/xml_definitions"
require "oddb2xml/extractor"
require "oddb2xml/builder"
require "oddb2xml/fhir_support"
require "oddb2xml/cli"

module Oddb2xml
  class Error < StandardError; end
end
