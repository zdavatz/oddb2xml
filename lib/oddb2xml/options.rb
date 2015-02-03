# encoding: utf-8
require 'optparse'

module Oddb2xml
  
  class Options
    attr_reader :parser, :opts
    def Options.default_opts
      {
        :fi           => false,
        :adr          => false,
        :address      => false,
        :nonpharma    => false,
        :extended     => false,
        :compress_ext => nil,
        :format       => :xml,
        :galenic      => false,
        :tag_suffix   => nil,
        :debug        => false,
        :ean14        => false,
        :skip_download=> false,
        :log          => false,
        :percent      => nil,
      }
    end
    def Options.help
  <<EOS
#$0 ver.#{Oddb2xml::VERSION}
Usage:
  oddb2xml [option]
    produced files are found under data
    -a,   --append       Additional target nonpharma
    -c F, --compress=F   Compress format F. {tar.gz|zip}
    -e    --extended     pharma, non-pharma plus prices and non-pharma from zurrose. Products without EAN-Code will also be listed.
    -f F, --format=F     File format F, default is xml. {xml|dat}
                         If F is given, -o option is ignored.
    -I x, --increment=x  Increment price by x percent. Forces -f dat -p zurrose.
    -I x, --increment=x  create additional field price_resellerpub as
                         price_extfactory incremented by x percent (rounded to the next 0.05 francs)
                         in oddb_article.xml. In generated zurrose_transfer.dat PRPU is set to this price
                         Forces -f dat -p zurrose.
    -i,   --include      Include target option for ean14  for 'dat' format.
                         'xml' format includes always ean14 records.
    -o,   --option       Optional fachinfo output.
    -p,   --price        Price source (transfer.dat) from ZurRose
    -t S, --tag-suffix=S XML tag suffix S. Default is none. [A-z0-9]
                         If S is given, it is also used as prefix of filename.
    -x N, --context=N    context N {product|address}. product is default.
    --galenic            create only oddb_calc.xml with GTIN, name and galenic information

                         For debugging purposes
    --skip-download      skips downloading files it the file is already under downloads.
                         Downloaded files are saved under downloads
    --log                log important actions
    -h,   --help         Show this help message.
EOS
    end
    def initialize
      @parser = OptionParser.new
      @opts   = Options.default_opts
      @parser.on('-a',   '--append')                       {|v| @opts[:nonpharma] = true }
      @parser.on('-c v', '--compress v',   /^tar\.gz|zip$/){|v| @opts[:compress_ext] = v }
      @parser.on('-e', '--extended')                       {|v| @opts[:extended] = true
                                                              @opts[:nonpharma] = true
                                                              @opts[:price] = :zurrose
                                                            }
      @parser.on('-f v', '--format v',     /^xml|dat$/)    {|v| @opts[:format] = v.intern }
      @parser.on('--galenic')                              {|v| @opts[:galenic] = true }
      @parser.on('-o',   '--option')                       {|v| @opts[:fi] = true }
      @parser.on('-I v', '--increment v',  /^[0-9]+$/)     {|v| @opts[:percent] = v ? v.to_i : 0
                                                                @opts[:price] = :zurrose
                                                           }
      @parser.on('-i',   '--include')                      {|v| @opts[:ean14] = true }
      @parser.on('-t v', '--tag-suffix v', /^[A-z0-9]*$/i) {|v| @opts[:tag_suffix] = v.upcase }
      @parser.on('-x v', '--context v',    /^addr(ess)*$/i){|v| @opts[:address] = true }
      @parser.on('-p', '--price')                          {|v| @opts[:price] = :zurrose }
      @parser.on('--skip-download')                        {|v| @opts[:skip_download] = true }
      @parser.on('--log')                                  {|v| @opts[:log] = true }
      @parser.on_tail('-h', '--help') { puts Options.help; exit }
    end
  end
end
