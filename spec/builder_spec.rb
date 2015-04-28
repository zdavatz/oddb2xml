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

def setup_package_xlsx_for_calc
  src = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'swissmedic_package-galenic.xlsx'))
  dest =  File.join(Oddb2xml::WorkDir, 'swissmedic_package.xlsx')
  FileUtils.makedirs(Oddb2xml::WorkDir)
  FileUtils.cp(src, dest, { :verbose => false, :preserve => true})
  FileUtils.cp(File.expand_path(File.join(File.dirname(__FILE__), 'data', 'XMLPublications.zip')),
              File.join(Oddb2xml::WorkDir, 'downloads'),
              { :verbose => false, :preserve => true})
end

def check_validation_via_xsd
  @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
  File.exists?(@oddb2xml_xsd).should eq true
  files = Dir.glob('*.xml')
  xsd = Nokogiri::XML::Schema(File.read(@oddb2xml_xsd))                                        
  files.each{
    |file|
    $stderr.puts "Validating file #{file} with #{File.size(file)} bytes" if $VERBOSE
    doc = Nokogiri::XML(File.read(file))
    xsd.validate(doc).each do |error|  error.message.should be_nil  end
  }
end
describe Oddb2xml::Builder do
  NrExtendedArticles = 78
  NrPharmaAndNonPharmaArticles = 60
  NrPharmaArticles = 5
  include ServerMockHelper
  before(:each) do
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    setup_server_mocks
    Dir.chdir Oddb2xml::WorkDir
  end
  after(:each) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end

  context 'XSD-generation: ' do
    let(:cli) do
        opts = {}
        @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
        @article_xml  = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
        @product_xml  = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
        options = Oddb2xml::Options.new
        options.parser.parse!([])
        Oddb2xml::Cli.new(options.opts)
    end

    it 'should return true when validating xml against oddb2xml.xsd' do
      res = buildr_capture(:stdout){ cli.run }
      File.exists?(@article_xml).should eq true
      File.exists?(@product_xml).should eq true
      check_validation_via_xsd
    end
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
      options = Oddb2xml::Options.new
      options.parser.parse!([])
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should pass validating via oddb2xml.xsd' do
      check_validation_via_xsd
    end
    
    it 'should generate a valid oddb_product.xml' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
      File.exists?(product_filename).should eq true
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
        product_xml.match(/<DSCRD>3TC Filmtabl 150 mg/).should_not == nil
        product_xml.match(/<GTIN>7680620690084/).should_not == nil
        product_xml.match(/<DSCRD>Levetiracetam DESITIN Filmtabl 250 mg/).should_not == nil
        product_xml.match(/<DSCRF>Levetiracetam DESITIN cpr pell 250 mg/).should_not == nil
        product_xml.match(/<SubstanceSwissmedic>levetiracetamum</)
        product_xml.match(/<CompositionSwissmedic>levetiracetamum 250 mg, excipiens pro compressi obducti pro charta.</).should_not == nil

        article_xml.scan(/<ART DT=/).size.should eq(NrPharmaArticles)
        article_xml.should match(/<PHAR>5819012</)
        article_xml.should match(/<DSCRD>LEVETIRACETAM DESITIN Filmtabl 250 mg/)
        article_xml.should match(/<COMPNO>7601001320451</)
      end
    end
  end

  context 'when -f dat is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/^..2/), "should have a record with '2' in CMUT field"
      oddb_dat.should match(/^..3/), "should have a record with '3' in CMUT field"
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk/), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article(line, false, false) }
      # oddb_dat.should match(/^..1/), "should have a record with '1' in CMUT field" # we have no
    end
  end

  context 'when --append -f dat is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('--append -f dat'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should generate a valid oddb_with_migel.dat' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk/), "should have Desitin"
      # oddb_dat.should match(/001349002780100B010710076806206900842/), "should match EAN of Desitin"
    end

    it "should match EAN of Desitin. returns 0 at the moment" do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/76806206900842/), "should match EAN of Desitin"
    end
  end

  context 'when --append -I 80 -e is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('--append -I 80 -e'.split(' '))
      setup_package_xlsx_for_calc
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should contain the correct prices' do
      cleanup_directories_before_run
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
      File.exists?(product_filename).should eq true
      doc = REXML::Document.new File.new(@article_xml)
      unless /1\.8\.7/.match(RUBY_VERSION)
        price_zur_rose_pub = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSEPUB']/PRICE").first.text
        price_zur_rose_pub.should eq '15.45'
        price_reseller_pub = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='RESELLERPUB']/PRICE").first.text
        price_reseller_pub.should eq '12.9'
        price_zur_rose = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSE']/PRICE").first.text
        price_zur_rose.should eq '7.18'
      end
    end
  end

  context 'when option -e is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-e'.split(' '))
      cleanup_directories_before_run
      setup_package_xlsx_for_calc
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should contain the correct prices' do
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
      File.exists?(product_filename).should eq true
      doc = REXML::Document.new File.new(@article_xml)
      unless /1\.8\.7/.match(RUBY_VERSION)
        price_zur_rose = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSE']/PRICE").first.text
        price_zur_rose.should eq '7.18'
        price_zur_rose_pub = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='ZURROSEPUB']/PRICE").first.text
        price_zur_rose_pub.should eq '15.45'
        price_reseller_pub = XPath.match( doc, "//ART[DSCRD='SOFRADEX Gtt Auric']/ARTPRI[PTYP='RESELLERPUB']/PRICE")
        price_reseller_pub.size.should eq 0
      end
    end

    def checkItemForRefdata(doc, pharmacode, isRefdata)
      article = XPath.match( doc, "//ART[PHAR=#{pharmacode.to_s}]").first
      name =  article.elements['DSCRD'].text
      refdata =  article.elements['REF_DATA'].text
      smno    =  article.elements['SMNO'] ? article.elements['SMNO'].text : 'nil'
      puts "checking doc for pharmacode #{pharmacode} isRefdata #{isRefdata} == #{refdata}. SMNO: #{smno} #{name}" if $VERBOSE
      article.elements['REF_DATA'].text.should == isRefdata.to_s

    end

    it 'should generate the flag non-refdata' do
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-non-refdata.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      XPath.match( doc, "//REF_DATA" ).size.should > 0
      checkItemForRefdata(doc, "1699947", 1) # 3TC Filmtabl 150 mg SMNO 53662013 IKSNR 53‘662, 53‘663
      checkItemForRefdata(doc, "0028470", 0) # Complamin
      checkItemForRefdata(doc, "3036984", 1) # NovoPen 4 Injektionsgerät blue In NonPharma (a MiGel product)
      checkItemForRefdata(doc, "5366964", 1) # 1-DAY ACUVUE moist jour
    end

    it 'should generate SALECD A for migel (NINCD 13)' do
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      doc = REXML::Document.new File.new(@article_xml)
      article = XPath.match( doc, "//ART[ARTINS/NINCD=13]").first
      article = XPath.match( doc, "//ART[PHAR=5366964]").first
      article.elements['SALECD'].text.should == 'A'
      article.elements['ARTINS/NINCD'].text.should == '13'
    end

    it 'should pass validating via oddb2xml.xsd' do
      check_validation_via_xsd
    end
    
    it 'should not contain veterinary iksnr 47066 CANIPHEDRIN'  do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/NonPharma/i)
      res.should match(/NonPharma products: #{NrPharmaAndNonPharmaArticles}/)
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      dscrds = XPath.match( doc, "//ART" )
      XPath.match( doc, "//BC" ).find_all{|x| x.text.match('47066') }.size.should == 0
      XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/CANIPHEDRIN/) }.size.should == 0
    end

    it 'should handle not duplicate pharmacode 5366964'  do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/NonPharma/i)
      res.should match(/NonPharma products: #{NrPharmaAndNonPharmaArticles}/)
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      dscrds = XPath.match( doc, "//ART" )
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('5366964') }.size.should == 1
      dscrds.size.should == NrExtendedArticles
      XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should >= 1
      XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('620691') }.size.should == 1
    end

    it 'should load correct number of nonpharma' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/NonPharma/i)
      res.should match(/NonPharma products: #{NrPharmaAndNonPharmaArticles}/)
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
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
      File.exists?(limitation_filename).should eq true
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
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
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
        
        doc = REXML::Document.new File.new @article_xml
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
      File.exists?(product_filename).should eq true

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
      XPath.match( doc, "//PRD" ).find_all{|x| true}.size.should == 17
      XPath.match( doc, "//GTIN" ).find_all{|x| true}.size.should == 17
      XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should == 1
    end

    def checkItemForSALECD(doc, pharmacode, expected)
      article = XPath.match( doc, "//ART[PHAR=#{pharmacode.to_s}]").first
      name    =  article.elements['DSCRD'].text
      salecd  =  article.elements['SALECD'].text
      if $VERBOSE or article.elements['SALECD'].text != expected.to_s
        puts "checking doc for pharmacode #{pharmacode} expected #{expected} == #{salecd}. #{name}"
        puts article.text
      end
      article.elements['SALECD'].text.should == expected.to_s
    end
    it 'should generate the flag SALECD' do
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-SALECD.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      XPath.match( doc, "//REF_DATA" ).size.should > 0
      checkItemForSALECD(doc, "0020244", 'A') # FERRO-GRADUMET Depottabl 30 Stk
      checkItemForSALECD(doc, "0598003", 'I') # SOFRADEX
    end
  end

  context 'testing -e option' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-e --skip-download'.split(' '))
      setup_package_xlsx_for_calc
      Oddb2xml::Cli.new(options.opts)
    end

    let(:cli_I80) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-e -I 80 --skip-download'.split(' '))
      setup_package_xlsx_for_calc
      Oddb2xml::Cli.new(options.opts)
    end
    search_path_reseller = "//ART[PHAR=0023722]/ARTPRI[PTYP='RESELLERPUB']/PRICE"
    search_path_rose     = "//ART[PHAR=0023722]/ARTPRI[PTYP='ZURROSE']/PRICE"
    search_path_pub      = "//ART[PHAR=0023722]/ARTPRI[PTYP='ZURROSEPUB']/PRICE"
    # sl-entries have a PPUB price
    search_path_desitin  = "//ART[SMNO='62069008']/ARTPRI[PTYP='PPUB']/PRICE"

    it 'should should return the ZurRose prive if -e' do
      res = buildr_capture(:stdout){ cli.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-e.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      XPath.match( doc, "//REF_DATA" ).size.should > 0
      article = XPath.match( doc, "//ART[PHAR=0023722]").first
      name =  article.elements['DSCRD'].text
      refdata =  article.elements['REF_DATA'].text
      smno    =  article.elements['SMNO'] ? article.elements['SMNO'].text : 'nil'
      XPath.match( doc, search_path_rose).size.should eq 1
      XPath.match( doc, search_path_rose).first.text.should eq '9.85'
      XPath.match( doc, search_path_reseller).size.should eq 0
      price = 15.20 # This is the zurrose pub price.
      XPath.match( doc, search_path_pub).first.text.to_f.should eq price
      XPath.match( doc, search_path_desitin).first.text.should eq '27.8'
    end

    it 'should add 80 percent to zur_rose pubbprice if -I 80' do
      res = buildr_capture(:stdout){ cli_I80.run }
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-e80.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      article = XPath.match( doc, "//ART[PHAR=0023722]").first
      name =  article.elements['DSCRD'].text
      refdata =  article.elements['REF_DATA'].text
      smno    =  article.elements['SMNO'] ? article.elements['SMNO'].text : 'nil'
      XPath.match( doc, search_path_rose).size.should eq 1
      XPath.match( doc, search_path_rose).first.text.should eq '9.85'
      XPath.match( doc, search_path_pub).first.text
      XPath.match( doc, search_path_pub).first.text.should eq '15.20'
      XPath.match( doc, search_path_reseller).size.should eq 1
      XPath.match( doc, search_path_reseller).first.text.should eq '17.75'

      XPath.match( doc, search_path_desitin).first.text.should eq '27.8'

      # sl-entries have a PPUB price, but no ZURROSEPUB, and vice versa
      XPath.match( doc, "//ART[PHAR=0023722]/ARTPRI[PTYP='PPUB']").size.should eq 0
      XPath.match( doc, "//ART[SMNO='62069008']/ARTPRI[PTYP='ZURROSEPUB']").size.should eq 0
      XPath.match( doc, "//ART[SMNO='62069008']/ARTPRI[PTYP='RESELLERPUB']").size.should eq 0
    end
  end

  # Check IGM-Format
  def check_article(line, check_prices = false, add_80_percents=0)
    typ            = line[0..1]
    name           = line[10..59]
    ckzl           = line[72]
    ciks           = line[75]
    price_exf      = line[60..65].to_i
    price_reseller = line[66..71].to_i
    price_public   = line[66..71].to_i
    typ.should    eq '11'
    puts "check_article: #{price_doctor} #{price_public} CKZL is #{ckzl} CIKS is #{ciks} name  #{name} " if $VERBOSE
    return unless check_prices
    if /11116999473TC/.match(line)
      line[60..65].should eq '016455'
      price_exf.should eq 16455
      ckzl.should eq '1'
      price_public.should eq 20530     # this is a SL-product. Therefore we may not have a price increase
      line[66..71].should eq '020530'  # the dat format requires leading zeroes and not point
    end
    if /1130598003SOFRADEX/.match(line)
      # 1130598003SOFRADEX Gtt Auric 8 ml                           000718001545300B120130076803169501572
      ckzl.should eq '3'
      if add_80_percents
        price_reseller.should eq    1292  # = 1545*1.8 this is a non  SL-product. Therefore we must increase its price as requsted
        line[66..71].should eq '001292' # dat format requires leading zeroes and not poin
      else
        price_reseller.should eq     718  # this is a non  SL-product, but no price increase was requested
        line[66..71].should eq '000718' # the dat format requires leading zeroes and not point
      end if false
      line[60..65].should eq '000718' # the dat format requires leading zeroes and not point
      price_exf.should eq    718      # this is a non  SL-product, but no price increase was requested
    end
  end

  context 'when -f dat -p is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat -p'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      res = buildr_capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/^..2/), "should have a record with '2' in CMUT field"
      oddb_dat.should match(/^..3/), "should have a record with '3' in CMUT field"
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk/), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article(line, true, false) }
      # oddb_dat.should match(/^..1/), "should have a record with '1' in CMUT field" # we have no
    end
  end

  context 'when -f dat -I 80 is given' do
    let(:cli) do
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat -I 80'.split(' '))
      Oddb2xml::Cli.new(options.opts)
    end
    it 'should contain the corect prices' do
      res = buildr_capture(:stdout){ cli.run }
      # res = cli.run
      res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat_lines = IO.readlines(dat_filename)
      IO.readlines(dat_filename).each{ |line| check_article(line, true, true) }
    end
  end
end
