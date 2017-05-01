#!/usr/bin/env ruby

require 'pry'

ALT = 'artikelstamm_150417.xml'
NEU = "artikelstamm_#{Date.today.strftime('%d%m%Y')}_v4.xml"
def compare_count(pattern)
  lines = []
  lines << "comparing count for #{pattern}"
  lines <<  "-------------------------------"
  cmd = 'grep -c '+ pattern +  ' '+ ALT
  nr_old = `#{cmd}`.strip.to_i
  cmd = 'grep -c '+ pattern +  ' '+ NEU
  nr_new = `#{cmd}`.strip.to_i
  lines <<  "PHARMATYPE N: #{nr_old} alte #{nr_new} neue"
  diff = (nr_old- nr_new).abs
  if diff > 100
    lines << "Viel zu verschiedene Einträge (#{diff}) für #{pattern}"
    lines << ""
    puts lines
  else
    puts "Comparing #{pattern} looks good. Found #{diff} differences. #{nr_old} #{nr_new}"
  end
end

def check_via_xsd
  `xmllint --noout --schema Elexis_Artikelstamm_v4.xsd #{NEU}`
end

def compare_gtin
  system('grep "<GTIN>" ' + ALT + ' | sort > gtin_alt.sorted')
  system('grep "<GTIN>" ' + NEU + ' | sort > gtin_neu.sorted')
  lines_alt = File.readlines('gtin_alt.sorted')
  gtins_alt = []
  lines_alt.each { |line| gtins_alt <</\d+/.match(line)[0] }
  lines_neu = File.readlines('gtin_neu.sorted')
  gtins_neu = []
  lines_neu.each { |line| gtins_neu <</\d+/.match(line)[0] }
  gtins_neu.size
  puts "Found #{(gtins_neu - gtins_alt).size} different gtins"
  File.open('gtin_diffs.txt', 'w+') { |f| f.puts (gtins_neu - gtins_alt).join("\n") }
  File.open('gtin_neu_only.txt', 'w+') do |f|
    (gtins_neu - gtins_alt).each do |gtin_neu|
      f.puts gtin_neu
    end
  end
  # 4029679330030
  File.open('gtin_alt_only.txt', 'w+') do |f|
    (gtins_alt - gtins_neu).each do |gtin_alt|
      f.puts gtin_alt
    end
  end
  puts "Found #{(gtins_alt - gtins_neu).size} GTINS only in #{ALT}. GTINS listed in gtin_alt_only.txt"
  puts "Found #{(gtins_neu - gtins_alt).size} GTINS only in #{NEU}. GTINS listed in gtin_neu_only.txt"
end

check_via_xsd
compare_gtin
compare_count('"ITEM PHARMATYPE=\"N\""')
compare_count('"ITEM PHARMATYPE=\"P\""')
compare_count('"<PRODUCT>"')
compare_count('"<GTIN>"')
