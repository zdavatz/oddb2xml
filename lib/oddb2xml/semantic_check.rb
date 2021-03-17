require "ox"

module Oddb2xml
  def self.log_timestamp(msg)
    full_msg = "#{Time.now.strftime("%H:%M:%S")}: #{msg}"
    puts full_msg
    $stdout.flush
    full_msg
  end

  class SemanticCheckXML
    attr_accessor :components
    attr_reader :keys, :sub_key_names, :filename, :basename, :version, :hash
    def initialize(filename, components = ["PRODUCTS", "LIMITATIONS", "ITEMS"])
      raise "File #{filename} must exist" unless File.exist?(filename)
      @filename = filename
      @basename = File.basename(filename)
      @components = components
      @hash = load_file(@filename)
    end

    def self.get_component_key_name(component_name)
      return "LIMNAMEBAG" if /LIMITATION/i.match?(component_name)
      return "PRODNO" if /PRODUCT/i.match?(component_name)
      return "GTIN" if /ITEM/i.match?(component_name)
      raise "Cannot determine keyname for component #{component_name}"
    end

    def get_items(component_name)
      # hack to make it spec/check_artikelstamm.rb work if called alone or as part
      # of the whole spec suite
      xx = @hash[:ARTIKELSTAMM] || @hash["ARTIKELSTAMM"]
      comps = xx[component_name.to_sym] || xx[component_name]
      comps.values.first
    end

    def load_file(name)
      Oddb2xml.log_timestamp "Reading #{name} #{(File.size(name) / 1024 / 1024).to_i} MB. This may take some time"
      Ox.load(IO.read(name), mode: :hash_no_attrs)
    end
  end

  class SemanticCheck
    attr_accessor :items, :products, :limitations
    def initialize(filename)
      @filename = filename
      @stammdaten = SemanticCheckXML.new(filename)
    end

    def everyProductNumberIsUnique
      puts "#{Time.now.strftime("%H:%M:%S")}: everyProductNumberIsUnique"
      return false unless products.size > 0
      products.collect { |x| x[:PRODNO] }.uniq.size == products.size
    end

    def everyGTINIsUnique
      puts "#{Time.now.strftime("%H:%M:%S")}: everyGTINIsUnique"
      return false unless items.size > 0
      items.collect { |x| x[:GTIN] }.uniq.size == items.size
    end

    def everyGTINIsNumericOnly
      puts "#{Time.now.strftime("%H:%M:%S")}: everyGTINIsNumericOnly"
      items.each do |item|
        unless /^[0-9]+$/i.match?(item[:GTIN])
          puts "GTIN is not Numeric Only"
          return false
        end
      end
    end

    def everyPharmaArticleHasAProductItem
      result = true
      puts "#{Time.now.strftime("%H:%M:%S")}: everyPharmaArticleHasAProductItem"
      all_product_numbers = products.collect { |product| product[:PRODNO] }
      items.each do |item|
        next unless item[:PRODNO]
        unless item[:Chapter70_HACK]
          unless all_product_numbers.index(item[:PRODNO])
            puts "Item #{item[:GTIN]}  has no Product #{item[:PRODNO]}  #{item[:DSCR]}"
            result = false
          end
        end
      end
      result
    end

    def everyProductHasAtLeastOneArticle
      result = true
      puts "#{Time.now.strftime("%H:%M:%S")}: veryProductHasAtLeastOneArticle"
      all_product_numbers = items.collect { |item| item[:PRODNO] }
      products.each do |product|
        unless all_product_numbers.index(product[:PRODNO])
          puts "product #{product[:PRODNO]}: has no Item #{product[:DSCR]}"
          result = false
        end
      end
      result
    end

    def everyReferencedLimitationIsIncluded
      result = true
      puts "#{Time.now.strftime("%H:%M:%S")}: everyReferencedLimitationIsIncluded"
      all_limitations = limitations.collect { |lim| lim[:LIMNAMEBAG] }
      products.each do |product|
        next unless product[:LIMNAMEBAG]
        unless all_limitations.index(product[:LIMNAMEBAG])
          puts "product #{product[:PRODNO]}  has no limitation #{product[:LIMNAMEBAG]} #{product[:DSCR]}"
          result = false
        end
      end
      result
    end

    def checkPackageSize
      puts "#{Time.now.strftime("%H:%M:%S")}: checkPackageSize"
      items.each do |item|
        if item["PKG_SIZE"] && item["PKG_SIZE"].length >= 6
          puts "WARNING possibly invalid package size #{item["PKG_SIZE"]}"
          pp item
        end
      end
    end

    def allSemanticChecks
      @limitations = @stammdaten.get_items("LIMITATIONS")
      @items = @stammdaten.get_items("ITEMS")
      @products = @stammdaten.get_items("PRODUCTS")
      puts "#{Time.now.strftime("%H:%M:%S")}: Running all semantic checks for #{@stammdaten.filename} for #{products.size} products and #{items.size} items"
      if everyProductNumberIsUnique &&
          everyGTINIsUnique &&
          everyGTINIsNumericOnly &&
          everyPharmaArticleHasAProductItem &&
          everyProductHasAtLeastOneArticle &&
          everyReferencedLimitationIsIncluded &&
          checkPackageSize
        puts "#{Time.now.strftime("%H:%M:%S")}: Everything is okay"
        true
      else
        puts "#{Time.now.strftime("%H:%M:%S")}: Checking #{@stammdaten.filename} failed"
        false
      end
    rescue => error
      puts "Execution failed with #{error}"
      raise error
    end
  end
end

if $0.eql?(__FILE__)
  daten = Oddb2xml::SemanticCheck.new(ARGV.first)
  daten.allSemanticChecks
end
