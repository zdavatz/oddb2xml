# encoding: utf-8
require 'oddb2xml/extractor'
require 'ox'
require 'open-uri'

module Oddb2xml
  class Chapter70xtractor < Extractor
    def Chapter70xtractor.parse_td(elem)
      begin
        values = elem.is_a?(Array) ? elem : elem.values
        res = values.flatten.collect{|x| x.nil? ? nil : x.is_a?(Hash) ? x.values : x.gsub(/\r\n/,'').strip }
        puts "parse_td returns: #{res}" if $VERBOSE
      rescue => exc
        puts "Unable to pars #{elem} #{exc}"
        # binding.pry
        return nil
      end
      res.flatten # .join("\t")
    end
    LIMITATIONS = {
      'L'  => 'Kostenübernahme nur nach vorgängiger allergologischer Abklärung.',
      'L1' => 'Eine Flasche zu 20 ml Urtinktur einer bestimmten Pflanze pro Monat.',
      'L1, L2' => 'Eine Flasche zu 20 ml Urtinktur einer bestimmten Pflanze pro Monat. Für Aesculus, Carduus Marianus, Ginkgo, Hedera helix, Hypericum perforatum, Lavandula, Rosmarinus officinalis, Taraxacum officinale.',
      'L3' => 'Alle drei Monate wird eine Verordnung/Originalpackung pro Mittel vergütet.',
    }
    def self.items
      @@items
    end
    def self.parse(html_file = 'http://www.spezialitaetenliste.ch/varia_De.htm')
      data = Hash.new{|h,k| h[k] = [] }
      Ox.default_options = {
          mode:   :generic,
          effort: :tolerant,
          smart:  true
      }
      res = Ox.load(Oddb2xml.uri_open(html_file).read, mode: :hash_no_attrs).values.first['body']
      result = []
      idx = 0
      @@items = {}
      res.values.last.each do |item|
        item.values.first.each do |subElem|
          what =  Chapter70xtractor.parse_td(subElem)
          idx += 1
          puts "#{idx}: xx #{what}" if $VERBOSE
          result << what
        end
      end
      result2 = result.find_all{ |x| (x.is_a?(Array) && x.first.is_a?(String)) && x.first.to_i > 100}
      result2.each do |entry|
        data = {}
        pharma_code = entry.first
        ean13 =  (Oddb2xml::FAKE_GTIN_START + pharma_code.to_s)
        if entry[2].encoding.to_s.eql?('ASCII-8BIT')
          german = CGI.unescape(entry[2].force_encoding('ISO-8859-1'))
        else
          german = entry[2]
        end
        @@items[ean13] = {
          :data_origin   => 'Chapter70',
          :line   => entry.join(","),
          :ean13 => ean13,
          :description => german,
          :quantity => entry[3],
          :pharmacode => pharma_code,
          :pub_price => entry[4],
          :limitation => entry[5],
          :type => :pharma,
        }
      end
      result2
    end
  end
end
