#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerate data/bag_sl_group_prices.csv (and the copy in
# github.com/zdavatz/oddb2xml_files) from the BAG SL definition PDF
# "Homoeopathica, Anthroposophica, Allergene".
#
# This maps each Pharma-Gruppen-Code (the `csl` column of
# weleda_arzneimittel.csv) to its public price (CHF incl. MWST). oddb2xml joins
# GTIN -> csl -> price to recover the SL flag and public price of Kapitel-70
# complementary medicines that are missing from the FHIR feed (issue #121).
#
# Requirements: poppler's `pdftotext` (dev-time only -- NOT a gem/runtime
# dependency, so the gem keeps its Ruby >= 2.5 floor; pdf-reader was rejected
# because its `afm` dependency now requires Ruby >= 3.2).
#
# Usage:
#   ruby tools/generate_bag_sl_group_prices.rb [path/to/HAA.pdf] [out.csv]
# With no PDF path it downloads the current PDF from epl.bag.admin.ch.

require "csv"
require "open-uri"
require "tempfile"

PDF_URL = "https://epl.bag.admin.ch/static/sl/definitions/" \
  "Homoeopathica,%20Anthroposophica,%20Allergene.pdf"

pdf_path = ARGV[0]
out_path = ARGV[1] || File.expand_path("../data/bag_sl_group_prices.csv", __dir__)

unless pdf_path
  tmp = Tempfile.new(["haa", ".pdf"])
  tmp.binmode
  tmp.write(URI.parse(PDF_URL).open.read) # standard:disable Security/Open
  tmp.close
  pdf_path = tmp.path
end

txt = `pdftotext -layout #{pdf_path.inspect} -`
raise "pdftotext failed (is poppler installed?)" unless $?.success?

seen = {}
rows = []
txt.each_line do |line|
  rest = line.rstrip
  next unless rest =~ /^\s*(\d{7})\s+(.*)$/
  code = $1
  body = $2
  nums = body.scan(/\d+\.\d{2}/)
  next if nums.empty?
  price = nums.last                              # price is the last NN.NN on the row
  next if seen[code]
  seen[code] = true
  tail = body.split(price, 2)[1].to_s
  limitation = tail.gsub(/[^L0-9, ]/, "").strip  # optional Lx limitation markers
  desc = body.sub(/\s+#{Regexp.escape(price)}.*$/, "").gsub(/\s{2,}/, " ").strip
  rows << [code, price, desc, limitation]
end

CSV.open(out_path, "w") do |csv|
  csv << %w[pharma_group_code price_chf_incl_vat description limitation]
  rows.each { |r| csv << r }
end

puts "Wrote #{rows.size} price rows to #{out_path}"
