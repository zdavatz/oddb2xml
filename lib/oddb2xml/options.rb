require "optimist"
require "oddb2xml/version"

module Oddb2xml
  module Options
    def self.parse(args = ARGV)
      if args.is_a?(String)
        args = args.split(" ")
      end

      @opts = Optimist.options(args) do
        version "#{$0} ver.#{Oddb2xml::VERSION}"
        banner <<-EOS
        #{File.expand_path($0)} version #{Oddb2xml::VERSION}
        Usage:
        oddb2xml [option]
          produced files are found under data
        EOS
        opt :append, "Additional target nonpharma", default: false
        opt :artikelstamm, "Create Artikelstamm Version 3 and 5 for Elexis >= 3.1"
        opt :compress_ext, "format F. {tar.gz|zip}", type: :string, default: nil, short: "c"
        opt :extended, "pharma, non-pharma plus prices and non-pharma from zurrose.
                            Products without EAN-Code will also be listed.
                            File oddb_calc.xml will also be generated"
        opt :fhir, "Use FHIR NDJSON format from FOPH/BAG instead of XML from Spezialitätenliste", default: false
        opt :fhir_url, "Specific FHIR NDJSON URL to download (implies --fhir)", type: :string, default: nil
        opt :format, "File format F, default is xml. {xml|dat}
                            If F is given, -o option is ignored.", type: :string, default: "xml"
        opt :include, "Include target option for ean14  for 'dat' format.
                            'xml' format includes always ean14 records.", short: "i"
        opt :increment, "Increment price by x percent. Forces -f dat -p zurrose.
                            create additional field price_resellerpub as
                            price_extfactory incremented by x percent (rounded to the next 0.05 francs)
                            in oddb_article.xml. In generated zurrose_transfer.dat PRPU is set to this price
                            Forces -f dat -p zurrose.", type: :int, default: nil, short: "I"
        opt :fi, "Optional fachinfo output.", short: "o"
        opt :price, "Price source (transfer.dat) from ZurRose", default: nil
        opt :tag_suffix, "XML tag suffix S. Default is none. [A-z0-9]
                            If S is given, it is also used as prefix of filename.", type: :string, short: "t"
        opt :context, "{product|address}. product is default.", default: "product", type: :string, short: "x"
        opt :calc, "create only oddb_calc.xml with GTIN, name and galenic information"

        opt :skip_download, "skips downloading files it the file is already under downloads.
                            Downloaded files are saved under downloads"
        opt :log, "log important actions", short: :none
        opt :use_ra11zip, "Use the ra11.zip (a zipped transfer.dat from Galexis)",
          default: File.exist?("ra11.zip") ? "ra11.zip" : nil, type: :string
        opt :firstbase, "Build all NONPHARMA articles on firstbase", short: "b", default: false
      end

      @opts[:percent] = @opts[:increment]
      if @opts[:increment]
        @opts[:nonpharma] = true
        @opts[:price] = :zurrose
      end
      @opts[:ean14] = @opts[:increment]
      @opts.delete(:increment)
      @opts[:nonpharma] = @opts[:append]
      @opts.delete(:append)
      if @opts[:firstbase]
        @opts[:nonpharma] = true
        # https://github.com/zdavatz/oddb2xml/issues/76
        @opts[:calc] = true
      end
      if @opts[:extended]
        @opts[:nonpharma] = true
        @opts[:price] = :zurrose
        @opts[:calc] = true
      end
      if @opts[:artikelstamm]
        @opts[:extended] = true
        @opts[:price] = :zurrose
      end
      # FHIR URL implies FHIR mode
      if @opts[:fhir_url]
        @opts[:fhir] = true
      end
      @opts[:price] = :zurrose if @opts[:price].is_a?(TrueClass)
      @opts[:price] = @opts[:price].to_sym if @opts[:price]
      @opts[:ean14] = @opts[:include]
      @opts[:format] = @opts[:format].to_sym if @opts[:format]
      @opts.delete(:include)
      @opts.delete(:help)
      @opts.delete(:version)

      @opts[:address] = false
      @opts[:address] = true if /^addr(ess)*$/i.match?(@opts[:context])
      @opts.delete(:context)

      @opts.delete(:price) unless @opts[:price]

      @opts.each { |k, v| @opts.delete(k) if /_given$/.match?(k.to_s) }
    end
  end
end
