# encoding: utf-8

require 'spec_helper'
require "rexml/document"
include REXML

module Kernel
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

describe Oddb2xml::Builder do
  include ServerMockHelper
  before(:all) do
    files = (Dir.glob('oddb_*.tar.gz')+ Dir.glob('oddb_*.zip')+ Dir.glob('oddb_*.xml'))# +Dir.glob('data/download/*'))
    files.each{ |file| FileUtils.rm(file) }
  end

  before(:each) do
    setup_server_mocks
    setup_swiss_index_server_mock(types =  ['NonPharma', 'Pharma'])
  end
  if true
  context 'should handle BAG-articles with and without pharmacode' do
    it {
      dat = File.read(File.expand_path('../data/Preparation.xml', __FILE__))
      @items = Oddb2xml::BagXmlExtractor.new(dat).to_hash
      saved =  @items.clone
      expect(@items.size).to eq(2)
      expect(saved).to eq(@items)
    }
  end
  
  context 'when no option is given' do
    let(:cli) do
      opts = {}
      Oddb2xml::Cli.new(opts)
    end
    it 'should generate a valid oddb_product.xml' do
      res = capture(:stdout){ cli.run }
      res.should match(/products/)
      article_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_article.xml'))
      File.exists?(article_filename).should be_true
      article_xml = IO.read(article_filename)
      product_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_product.xml'))
      File.exists?(product_filename).should be_true
      unless /1\.8\.7/.match(RUBY_VERSION)
        product_xml = IO.read(product_filename)
        article_xml.should match(/3TC/)
        article_xml.should match(/<PHAR>1699947</)
        article_xml.should match(/<SMNO>53662013</)
        article_xml.should match(/<DSCRD>3TC Filmtabl 150 mg</)
        article_xml.should match(/<COMPNO>7601001392175</)
        article_xml.should match(/<BC>7680536620137</)
        article_xml.should match(/<VDAT>01.10.2011</)
        article_xml.should match(/<PTYP>PEXF</)
        article_xml.should match(/<PRICE>164.55</)
        article_xml.should match(/<PTYP>PPUB</)
        article_xml.should match(/<PRICE>205.3</)

        article_xml.should match(/Levetiracetam DESITIN/i) #
        article_xml.should match(/7680536620137/) # Pharmacode
        article_xml.should match(/<PRICE>13.49</)
        article_xml.should match(/<PRICE>27.8</)

        product_xml.should match(/3TC/)
        product_xml.should match(/7680620690084/) # Levetiracetam DESITIN
        article_xml.scan(/<ART DT=/).size.should eq(3) # we should find two articles
        article_xml.should match(/<PHAR>5819012</)
        article_xml.should match(/<DSCRD>LEVETIRACETAM DESITIN Filmtabl 250 mg/)
        article_xml.should match(/<COMPNO>7601001320451</)
      end
    end
  end
  
  context 'when -a nonpharma -f dat is given' do
    let(:cli) do
      opts = {
        :nonpharma    => 'true',
        :format       => :dat,
      }
      Oddb2xml::Cli.new(opts)
    end    
    it 'should generate a valid oddb_with_migel.dat' do
      res = capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_with_migel.dat'))
      File.exists?(dat_filename).should be_true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk/), "should have Desitin"
      # oddb_dat.should match(/001349002780100B010710076806206900842/), "should match EAN of Desitin"
    end
    it "pending should match EAN of Desitin. returns 0 at the moment" 

  end
  end
  context 'when option -e is given' do
    let(:cli) do
      opts = {
        :extended    => :true,
        :nonpharma    => :true,
        :price      => :zurrose,
        }
      Oddb2xml::Cli.new(opts)
    end

    it 'should emit correct data when called with -e (extended)' do
      res = capture(:stdout){ cli.run }
      res.should match(/products/)
      article_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_article.xml'))
      File.exists?(article_filename).should be_true
      article_xml = IO.read(article_filename)
      product_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_product.xml'))
      File.exists?(product_filename).should be_true

      # check substances
      doc = REXML::Document.new File.new(File.join(File.dirname(__FILE__), '..', 'oddb_substance.xml'))
      names = XPath.match( doc, "//NAML" )
      names.size.should == 2
      names.find_all{|x| x.text.match('Lamivudinum') }.size.should == 1

      # check interactions
      doc = REXML::Document.new File.new(File.join(File.dirname(__FILE__), '..', 'oddb_interaction.xml'))
      titles = XPath.match( doc, "//TITD" )
      titles.size.should == 2
      titles.find_all{|x| x.text.match('Keine Interaktion') }.size.should == 1
      titles.find_all{|x| x.text.match('Erhöhtes Risiko für Myopathie und Rhabdomyolyse') }.size.should == 1

      unless /1\.8\.7/.match(RUBY_VERSION)
        # check articles
        article_xml.should match(/3TC/)
        article_xml.should match(/<PHAR>1699947</)
                                 article_xml.should match(/<SMNO>53662013</)
                                article_xml.should match(/<DSCRD>3TC Filmtabl 150 mg</)
        article_xml.should match(/<COMPNO>7601001392175</)
        article_xml.should match(/<BC>7680536620137</)
        article_xml.should match(/<VDAT>01.10.2011</)
        article_xml.should match(/<PTYP>PEXF</)
        article_xml.should match(/<PRICE>164.55</)
        article_xml.should match(/<PTYP>PPUB</)
        article_xml.should match(/<PRICE>205.3</)

        article_xml.should match(/Levetiracetam DESITIN/i) #
        article_xml.should match(/7680536620137/) # Pharmacode
        article_xml.should match(/<PRICE>13.49</)
        article_xml.should match(/<PRICE>27.8</)
        article_xml.scan(/<ART DT=/).size.should eq(60) # we should find some articles
        article_xml.should match(/<PHAR>5819012</)
        article_xml.should match(/<DSCRD>LEVETIRACETAM DESITIN Filmtabl 250 mg/)
        article_xml.should match(/<COMPNO>7601001320451</)

        # check products
        product_xml = IO.read(product_filename)
        product_xml.should match(/3TC/)
        product_xml.should match(/7680620690084/) # Levetiracetam DESITIN

        # check ZYVOXID in article
        article_xml.should match(/7680555580054/) # ZYVOXID
        article_xml.should match(/ZYVOXID/i)

        product_xml.should match(/7680555580054/) # ZYVOXID
        product_xml.should_not match(/ZYVOXID/i)
        doc = REXML::Document.new File.new article_filename
        dscrds = XPath.match( doc, "//DSCRD" )
        dscrds.find_all{|x| x.text.match('ZYVOXID Filmtabl 600 mg') }.size.should == 1
      end
    end
  end
end

