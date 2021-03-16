#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__))
require "spec_helper"
module Oddb2xml
  # Small helper script to see, whether all files are correctly filled
  def self.fill
    start_keys = [
      1125822801,
      1125830700,
      1122465312,
      1120020209,
      1120020244,
      1130020646,
      1120020652,
      1130021806,
      1130021976,
      1130023722,
      1130027447,
      1130028470,
      1135366964,
      1122871437,
      1122871443,
      1122871466,
      1122871472,
      1132867163,
      1138110429,
      1130598003,
      1125565072,
      1126000923,
      1128111222,
      1128111718,
      1128807890,
      1117199565,
      1128111611
    ]

    gtins = GTINS_DRUGS + [FERRO_GRADUMET_GTIN,
      HIRUDOID_GTIN, LANSOYL_GTIN, LEVETIRACETAM_GTIN,
      SOFRADEX_GTIN, THREE_TC_GTIN, ZYVOXID_GTIN]
    gtins.each { |gtin| Oddb2xml.check_gtin(gtin) }

    ENV["LANG"] = "de_CH.ISO-8859"
    outfile = "spec/data/transfer.dat"
    FileUtils.rm_f(outfile, verbose: true)
    start_keys.each do |key|
      cmd = "egrep '^#{key}' DOWNLOADS/transfer.dat >> #{outfile}"
      system(cmd)
    end
    iksnrs = []
    gtins.each do |key|
      cmd = "grep #{key} DOWNLOADS/transfer.dat >> #{outfile}"
      system(cmd)
      iksnrs << key.to_s[4..8] if /^7680/i.match?(key.to_s)
    end
    puts "Created #{outfile} #{File.size(outfile)} bytes"
    puts "Used IKSNRS are #{iksnrs.sort.uniq.join(" ")}"
  end

  def self.check_gtin(gtin)
    files = `grep -l #{gtin} DOWNLOADS/*.xml`.split("\n")
    files.each do |file|
      short = File.join(SpecData, File.basename(file))
      nr_matches = 0
      nr_matches = `grep -c #{gtin} #{short}`.to_i if File.exist?(short)
      puts "Could not find #{gtin} in #{short}" unless nr_matches > 0
    end
  end
end

Oddb2xml.fill
