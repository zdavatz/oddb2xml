# encoding: utf-8

module Oddb2xml
  class Extractor
    attr_accessor :locale, :subject

    def initialize(items_hash)
      @items_hash = items_hash
      if block_given?
        yield self
      end
    end

    def extract
      # TODO
      #   Build XML by local, subject

      # debug
      return '' unless @items_hash
      obj = ''
      obj << "lang => #{locale}\n"
      obj << "sbj  => #{subject}\n"
      obj << "\n\n"
      @items_hash.each_with_object(obj) do |hash, obj|
        hash.each_pair do |key, val|
          obj << "#{key} => #{val.to_s}\n"
        end
      end
    end

  end
end
