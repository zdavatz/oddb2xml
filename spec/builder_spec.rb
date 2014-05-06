# encoding: utf-8

require 'spec_helper'
require "rexml/document"
include REXML

module Kernel
  def buildr_capture(stream)
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
  NrExtendedArticles = 71
  NrPharmaAndNonPharmaArticles = 61
  NrPharmaArticles = 4
  include ServerMockHelper
  before(:each) do
    @saveddir = Dir.pwd
    cleanup_directories_before_run
    setup_server_mocks
    setup_swiss_index_server_mock(types =  ['NonPharma', 'Pharma'])
    Dir.chdir Oddb2xml::WorkDir
  end
  after(:each) do
    Dir.chdir @saveddir
  end

  context 'should handle BAG-articles with and without pharmacode' do
    it {
      dat = File.read(File.expand_path('../data/Preparations.xml', __FILE__))
      @items = Oddb2xml::BagXmlExtractor.new(dat).to_hash
      saved =  @items.clone
      expect(@items.size).to eq(5)
      expect(saved).to eq(@items)
    }
  end

  context 'when no option is given' do
    let(:cli) do
      opts = {}
      Oddb2xml::Cli.new(opts)
    end

    it 'should generate a valid oddb_product.xml' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      article_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(article_filename).should be_true
      article_xml = IO.read(article_filename)
      product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
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
        article_xml.scan(/<ART DT=/).size.should eq(NrPharmaArticles)
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
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      File.exists?(dat_filename).should be_true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk/), "should have Desitin"
      # oddb_dat.should match(/001349002780100B010710076806206900842/), "should match EAN of Desitin"
    end
    it "pending should match EAN of Desitin. returns 0 at the moment" 
  end
  context 'when option -e is given' do
    let(:cli) do
      opts = {
        :extended    => :true,
        :nonpharma    => :true,
        :price      => :zurrose,
        :log      => true,
        :skip_download => true,
      }
      Oddb2xml::Cli.new(opts)
    end

    it 'should handle not duplicate pharmacode 5366964'  do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/NonPharma/i)
      res.should match(/NonPharma products: #{NrPharmaAndNonPharmaArticles}/)
      article_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(article_filename).should be_true
      article_xml = IO.read(article_filename)
      doc = REXML::Document.new File.new(article_filename)
      dscrds = XPath.match( doc, "//ART" )
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('5366964') }.size.should == 1
      dscrds.size.should == NrExtendedArticles
      XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should == 1
      XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('620691') }.size.should == 1
    end

    it 'should load correct number of nonpharma' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/NonPharma/i)
      res.should match(/NonPharma products: #{NrPharmaAndNonPharmaArticles}/)
      article_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(article_filename).should be_true 
      article_xml = IO.read(article_filename)
      doc = REXML::Document.new File.new(article_filename)
      dscrds = XPath.match( doc, "//ART" )
      dscrds.size.should == NrExtendedArticles
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('1699947') }.size.should == 1 # swissmedic_packages Cardio-Pulmo-Rénal Sérocytol, suppositoire
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('2465312') }.size.should == 1 # from swissindex_pharma.xml"
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('0000000') }.size.should == 1 # from swissindex_pharma.xml
    end

    it 'should emit a correct oddb_limitation.xml' do
      res = buildr_capture(:stdout){ cli.run }
      # check limitations
      limitation_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_limitation.xml'))
      File.exists?(limitation_filename).should be_true
      limitation_xml = IO.read(limitation_filename)
      limitation_xml.should match(/Die aufgeführten Präparat/)
      doc = REXML::Document.new File.new(limitation_filename)
      limitations = XPath.match( doc, "//LIM" )
      limitations.size.should == 4
      XPath.match( doc, "//SwissmedicNo5" ).find_all{|x| x.text.match('28486') }.size.should == 1
      XPath.match( doc, "//Pharmacode" ).find_all{|x| x.text.match('3817150') }.size.should == 2
      XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('ALFARÉ') }.size.should == 1
      XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('070110') }.size.should == 1
    end

    it 'should emit a correct oddb_article.xml' do
      res = buildr_capture(:stdout){ cli.run }
      article_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(article_filename).should be_true
      article_xml = IO.read(article_filename)
      doc = REXML::Document.new File.new(article_filename)
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
        article_xml.scan(/<ART DT=/).size.should eq(NrExtendedArticles) # we should find some articles
        article_xml.should match(/<PHAR>5819012</)
        article_xml.should match(/<DSCRD>LEVETIRACETAM DESITIN Filmtabl 250 mg/)
        article_xml.should match(/<COMPNO>7601001320451</)
        # check ZYVOXID in article
        article_xml.should match(/7680555580054/) # ZYVOXID
        article_xml.should match(/ZYVOXID/i)
        
        doc = REXML::Document.new File.new article_filename
        dscrds = XPath.match( doc, "//DSCRD" )
        dscrds.find_all{|x| x.text.match('ZYVOXID Filmtabl 600 mg') }.size.should == 1
        
      end
      #pending 'Checking for LIMPTS' # XPath.match( doc, "//LIMPTS" ).size.should == 1
    end

    it 'should emit a correct oddb_substance.xml' do
      res = buildr_capture(:stdout){ cli.run }
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_substance.xml'))
      names = XPath.match( doc, "//NAML" )
      names.size.should == 10
      names.find_all{|x| x.text.match('Lamivudinum') }.size.should == 1
    end

    it 'should emit a correct oddb_interaction.xml' do
      res = buildr_capture(:stdout){ cli.run }
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_interaction.xml'))
      titles = XPath.match( doc, "//TITD" )
      titles.size.should == 2
      titles.find_all{|x| x.text.match('Keine Interaktion') }.size.should == 1
      titles.find_all{|x| x.text.match('Erhöhtes Risiko für Myopathie und Rhabdomyolyse') }.size.should == 1
    end

    it 'should emit a correct oddb_product.xml' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
      File.exists?(product_filename).should be_true

      unless /1\.8\.7/.match(RUBY_VERSION)
        # check articles

        # check products
        product_xml = IO.read(product_filename)
        product_xml.should match(/3TC/)
        product_xml.should match(/7680620690084/) # Levetiracetam DESITIN

        product_xml.should match(/7680555580054/) # ZYVOXID
        product_xml.should_not match(/ZYVOXID/i)
      end
      doc = REXML::Document.new File.new(product_filename)
      XPath.match( doc, "//PRD" ).find_all{|x| true}.size.should == 3
      XPath.match( doc, "//GTIN" ).find_all{|x| true}.size.should == 3
      XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should == 1
    end
  end
end
