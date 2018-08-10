# encoding: utf-8
require 'oddb2xml/extractor'
require 'ox'

module Oddb2xml
  class Chapter70xtractor < Extractor
    def Chapter70xtractor.parse_td(elem)
      begin
        values = elem.is_a?(Array) ? elem : elem.values
        res = values.flatten.collect{|x| x.nil? ? nil : x.is_a?(Hash) ? x.values : x.gsub(/\r\n/,'').strip }
        puts "parse_td returns: #{res}" if $VERBOSE
      rescue => exc
        puts "Unable to pars #{elem} #{exc}"
        binding.pry
        return nil
      end
      res.flatten # .join("\t")
    end
    def self.parse(html_file)
      data = Hash.new{|h,k| h[k] = [] }
      Ox.default_options = {
          mode:   :generic,
          effort: :tolerant,
          smart:  true
      }
      res = Ox.load(IO.read(html_file), mode: :hash_no_attrs).values.first['body']
      # item[4].values.flatten[3].values.flatten.collect{|x| x.is_a?(Hash) ? x.values : x.gsub(/\r\n/,'')}.flatten
      #item[4].values.flatten[3].keys.first.eql?('td')
      # res.values.last.each{ |item| puts "keys #{item.keys} #{item.values.first.size}"; item.values.first.each { |subElem| puts "#{subElem}" } }; 7
      result = []
      # result = res.values.last.each{ |item| puts "keys #{item.keys} #{item.values.first.size}"; item.values.first.each { |subElem| result << Chapter70xtractor.parse_td(subElem) } }; 7
      idx = 0
      res.values.last.each do |item|
        item.values.first.each do |subElem|
          what =  Chapter70xtractor.parse_td(subElem)
          idx += 1
          puts "#{idx}: xx #{what}" if $VERBOSE
          result << what
        end
      end
      result2 = result.find_all{ |x| (x.is_a?(Array) && x.first.is_a?(String)) && x.first.to_i > 100}
    end
  end
end

  
