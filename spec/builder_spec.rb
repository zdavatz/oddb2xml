# encoding: utf-8

require 'spec_helper'
require "rexml/document"
include REXML
RUN_ALL = false
def checkItemForRefdata(doc, pharmacode, isRefdata)
  article = XPath.match( doc, "//ART[PHAR=#{pharmacode.to_s}]").first
  name =     article.elements['DSCRD'].text
  refdata =  article.elements['REF_DATA'].text
  smno    =  article.elements['SMNO'] ? article.elements['SMNO'].text : 'nil'
  puts "checking doc for gtin #{gtin} isRefdata #{isRefdata} == #{refdata}. SMNO: #{smno} #{name}" if $VERBOSE
  article.elements['REF_DATA'].text.should == isRefdata.to_s
  article
end

def check_article_IGM_format(line, price_kendural=825, add_80_percents=false)
  typ            = line[0..1]
  name           = line[10..59]
  ckzl           = line[72]
  ciks           = line[75]
  price_exf      = line[60..65].to_i
  price_reseller = line[66..71].to_i
  price_public   = line[66..71].to_i
  typ.should    eq '11'
  puts "check_article_IGM_format: #{price_exf} #{price_public} CKZL is #{ckzl} CIKS is #{ciks} name  #{name} " if $VERBOSE
  found_SL = false
  found_non_SL = false

  if /7680353660163\d$/.match(line) # KENDURAL Depottabl 30 Stk
    puts "found_SL for #{line}" if $VERBOSE
    found_SL = true
    line[60..65].should eq '000491'
    price_exf.should eq 491
    ckzl.should eq '1'
    price_public.should eq price_kendural     # this is a SL-product. Therefore we may not have a price increase
    line[66..71].should eq '000'+price_kendural.to_s  # the dat format requires leading zeroes and not point
  end

  if /7680403330459\d$/.match(line) # CARBADERM
    found_non_SL = true
    puts "found_non_SL for #{line}" if $VERBOSE
    ckzl.should eq '3'
    if add_80_percents
      price_reseller.should eq    2919  # = 1545*1.8 this is a non  SL-product. Therefore we must increase its price as requsted
      line[66..71].should eq '002919' # dat format requires leading zeroes and not poin
    else
      price_reseller.should eq     2770  # this is a non  SL-product, but no price increase was requested
      line[66..71].should eq '002770' # the dat format requires leading zeroes and not point
    end
    line[60..65].should eq '001622' # the dat format requires leading zeroes and not point
    price_exf.should eq    1622      # this is a non  SL-product, but no price increase was requested
  end
  return [found_SL, found_non_SL]
end

def check_validation_via_xsd
  @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
  @oddb_calc_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_calc.xsd'))
  File.exists?(@oddb2xml_xsd).should eq true
  File.exists?(@oddb_calc_xsd).should eq true
  files = Dir.glob('*.xml')
  xsd_oddb2xml = Nokogiri::XML::Schema(File.read(@oddb2xml_xsd))
  xsd_oddb_calc = Nokogiri::XML::Schema(File.read(@oddb_calc_xsd))
  files.each{
    |file|
    next if /#{Time.now.year}/.match(file)
    doc = Nokogiri::XML(File.read(file))
    xsd2use = /oddb_calc/.match(file) ? xsd_oddb_calc : xsd_oddb2xml
    xsd2use.validate(doc).each do
      |error|
        if error.message
          puts "Failed validating #{file} with #{File.size(file)} bytes using XSD from #{@oddb2xml_xsd}"
        end
        error.message.should be_nil
    end
  }
end

def checkPrices(increased = false)
  doc = REXML::Document.new File.new(checkAndGetArticleXmlName)

  sofradex = checkAndGetArticleWithGTIN(doc, Oddb2xml::SOFRADEX_GTIN)
  sofradex.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text.should eq Oddb2xml::SOFRADEX_PRICE_ZURROSE.to_s
  sofradex.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text.should eq Oddb2xml::SOFRADEX_PRICE_ZURROSEPUB.to_s

  lansoyl = checkAndGetArticleWithGTIN(doc, Oddb2xml::LANSOYL_GTIN)
  lansoyl.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text.should eq Oddb2xml::LANSOYL_PRICE_ZURROSE.to_s
  lansoyl.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text.should eq Oddb2xml::LANSOYL_PRICE_ZURROSEPUB.to_s

  desitin = checkAndGetArticleWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  desitin.elements["ARTPRI[PTYP='PPUB']/PRICE"].text.should eq Oddb2xml::LEVETIRACETAM_PRICE_PPUB.to_s
  desitin.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text.should eq Oddb2xml::LEVETIRACETAM_PRICE_ZURROSE.to_s
  desitin.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text.to_f.should eq Oddb2xml::LEVETIRACETAM_PRICE_PPUB.to_f
  if increased
    lansoyl.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text.should eq Oddb2xml::LANSOYL_PRICE_RESELLER_PUB.to_s
    sofradex.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text.should eq Oddb2xml::SOFRADEX_PRICE_RESELLER_PUB.to_s
    desitin.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text.should eq Oddb2xml::LEVETIRACETAM_PRICE_RESELLER_PUB.to_s
  else
    lansoyl.elements["ARTPRI[PTYP='RESELLERPUB']"].should eq nil
    sofradex.elements["ARTPRI[PTYP='RESELLERPUB']"].should eq nil
    desitin.elements["ARTPRI[PTYP='RESELLERPUB']"].should eq nil
  end
end

def checkAndGetArticleXmlName(tst=nil)
  article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
  File.exists?(article_xml).should eq true
  FileUtils.cp(article_xml, File.join(Oddb2xml::WorkDir, "tst-#{tst}.xml")) if tst
  article_xml
end

def checkAndGetProductWithGTIN(doc, gtin)
  products = XPath.match( doc, "//PRD[GTIN=#{gtin.to_s}]")
  gtins    = XPath.match( doc, "//PRD[GTIN=#{gtin.to_s}]/GTIN")
  binding.pry unless gtins.size == 1
  gtins.size.should eq 1
  gtins.first.text.should eq gtin.to_s
  # return product
  return products.size == 1 ? products.first : nil
end

def checkAndGetArticleWithGTIN(doc, gtin)
  articles = XPath.match( doc, "//ART[ARTBAR/BC=#{gtin}]")
  gtins    = XPath.match( doc, "//ART[ARTBAR/BC=#{gtin}]/ARTBAR/BC")
  gtins.size.should eq 1
  gtins.first.text.should eq gtin.to_s
  gtins.first
  # return article
  return articles.size == 1 ? articles.first : nil
end

def checkArticleXml(checkERYTHROCIN = true)
  article_filename = checkAndGetArticleXmlName

  # check articles
  doc = REXML::Document.new IO.read(article_filename)
  checkAndGetArticleWithGTIN(doc, Oddb2xml::THREE_TC_GTIN)
  desitin = checkAndGetArticleWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  desitin.should_not eq nil
  # TODO: why is this now nil? desitin.elements['ATC'].text.should == 'N03AX14'
  desitin.elements['DSCRD'].text.should ==  "LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk"
  desitin.elements['DSCRF'].text.should == 'LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce'
  desitin.elements['REF_DATA'].text.should == '1'
  desitin.elements['PHAR'].text.should == '5819012'
  desitin.elements['SMCAT'].text.should == 'B'
  desitin.elements['SMNO'].text.should == '62069008'
  desitin.elements['VAT'].text.should == '2'
  desitin.elements['PRODNO'].text.should == '620691'
  desitin.elements['SALECD'].text.should == 'A'
  desitin.elements['CDBG'].text.should == 'N'
  desitin.elements['BG'].text.should == 'N'

  erythrocin_gtin = '7680202580475' # picked up from zur rose
  erythrocin = checkAndGetArticleWithGTIN(doc, erythrocin_gtin)
  erythrocin.elements['DSCRD'].text.should ==  "ERYTHROCIN i.v. Trockensub 1000 mg Amp" if checkERYTHROCIN

  lansoyl = checkAndGetArticleWithGTIN(doc, Oddb2xml::LANSOYL_GTIN)
  lansoyl.elements['DSCRD'].text.should eq 'LANSOYL Gel 225 g'
  lansoyl.elements['REF_DATA'].text.should eq '1'
  lansoyl.elements['SMNO'].text.should eq '32475019'
  lansoyl.elements['PHAR'].text.should eq '0023722'
  lansoyl.elements['ARTCOMP/COMPNO'].text.should == '7601001002012'

  zyvoxid = checkAndGetArticleWithGTIN(doc, Oddb2xml::ZYVOXID_GTIN)
  zyvoxid.elements['DSCRD'].text.should eq 'ZYVOXID Filmtabl 600 mg 10 Stk'

  XPath.match( doc, "//LIMPTS" ).size.should >= 1
  # TODO: desitin.elements['QTY'].text.should eq '250 mg'
end

def checkProductXml
  product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
  File.exists?(product_filename).should eq true

  # check products
  doc = REXML::Document.new IO.read(product_filename)
  desitin = checkAndGetProductWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  desitin.elements['ATC'].text.should == 'N03AX14'
  desitin.elements['DSCRD'].text.should == "LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk"
  desitin.elements['DSCRF'].text.should == 'LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce'
  desitin.elements['PRODNO'].text.should eq '620691'
  desitin.elements['IT'].text.should eq '01.07.1.'
  desitin.elements['PackGrSwissmedic'].text.should eq '30'
  desitin.elements['EinheitSwissmedic'].text.should eq 'Tablette(n)'
  desitin.elements['SubstanceSwissmedic'].text.should eq 'levetiracetamum'
  desitin.elements['CompositionSwissmedic'].text.should eq 'levetiracetamum 250 mg, excipiens pro compressi obducti pro charta.'

  desitin.elements['CPT/CPTCMP/LINE'].text.should eq '0'
  desitin.elements['CPT/CPTCMP/SUBNO'].text.should eq '8'
  desitin.elements['CPT/CPTCMP/QTY'].text.should eq '250'
  desitin.elements['CPT/CPTCMP/QTYU'].text.should eq 'mg'

  checkAndGetProductWithGTIN(doc, Oddb2xml::THREE_TC_GTIN)
  checkAndGetProductWithGTIN(doc, Oddb2xml::ZYVOXID_GTIN)
  if $VERBOSE
    puts "checkProductXml #{product_filename} #{File.size(product_filename)} #{File.mtime(product_filename)}"
    puts "checkProductXml has #{XPath.match( doc, "//PRD" ).find_all{|x| true}.size} packages"
    puts "checkProductXml has #{XPath.match( doc, "//GTIN" ).find_all{|x| true}.size} GTIN"
    puts "checkProductXml has #{XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size} PRODNO"
  end
  XPath.match( doc, "//PRD" ).find_all{|x| true}.size.should == NrPackages
  XPath.match( doc, "//GTIN" ).find_all{|x| true}.size.should == NrPackages
  XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should == NrProdno

  hirudoid = checkAndGetProductWithGTIN(doc, Oddb2xml::HIRUDOID_GTIN)
  hirudoid.elements['ATC'].text.should == 'C05BA01' # modified by atc.csv!
end

describe Oddb2xml::Builder do
  NrExtendedArticles = 86
  NrSubstances = 12
  NrProdno = 19
  NrPackages = 20
  RegExpDesitin = /1125819012LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk/
  include ServerMockHelper
  def common_run_init
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    Dir.chdir Oddb2xml::WorkDir
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
  end

  after(:all) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  context 'when default options are given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should return produce a oddb_article.xml' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
    end

    it 'oddb_article.xml should contain a SHA256' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      content = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      expect( XPath.match( doc, "//ART").first.attributes['DT']).to match /\d{4}-\d{2}-\d{2}/
      expect( XPath.match( doc, "//ART").first.attributes['SHA256'].size).to eq 64
    end

    it 'should be possible to verify the oddb_article.xml' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      result = Oddb2xml.verify_sha256(@article_xml)
      expect(result)
    end

    it 'should be possible to verify all xml files against our XSD' do
      check_validation_via_xsd
    end
  end

  context 'when -o for fachinfo is given' do
    before(:all) do
      common_run_init
      @oddb_fi_xml  = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_fi.xml'))
      @oddb_fi_product_xml  = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_fi_product.xml'))
      options = Oddb2xml::Options.new
      options.parser.parse!(['-o'])
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should return produce a correct oddb_fi.xml' do
      File.exists?(@oddb_fi_xml).should eq true
      inhalt = IO.read(@oddb_fi_xml)
      /<KMP/.match(inhalt.to_s).to_s.should eq '<KMP'
      /<style><!\[CDATA\[p{margin-top/.match(inhalt.to_s).to_s.should eq '<style><![CDATA[p{margin-top'
      m = /<paragraph><!\[CDATA\[(.+)\n(.*)/.match(inhalt.to_s)
      m[1].should eq '<?xml version="1.0" encoding="utf-8"?><div xmlns="http://www.w3.org/1999/xhtml">'
      expected = '<p class="s2"> </p>'
      skip { m[2].should eq '<p class="s4" id="section1"><span class="s2"><span>Zyvoxid</span></span><sup class="s3"><span>®</span></sup></p>'  }
      File.exists?(@oddb_fi_product_xml).should eq true
      inhalt = IO.read(@oddb_fi_product_xml)
    end

if RUN_ALL
    it 'should produce valid xml files' do
      skip "Niklaus does not know how to create a valid oddb_fi_product.xml"
      # check_validation_via_xsd
    end

    it 'should generate a valid oddb_product.xml' do
      @res.should match(/products/)
      checkProductXml
    end
  end

  context 'when -f dat is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat --log'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      @res.should match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/^..2/), "should have a record with '2' in CMUT field"
      oddb_dat.should match(/^..3/), "should have a record with '3' in CMUT field"
      oddb_dat.should match(RegExpDesitin), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line) }
    end
  end

  context 'when --append -f dat is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('--append -f dat'.split(' '))
      # Oddb2xml::Cli.new(options.opts).run
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should generate a valid oddb_with_migel.dat' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(RegExpDesitin), "should have Desitin"
      @res.should match(/products/)
    end

    it "should match EAN 76806206900842 of Desitin" do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/76806206900842/), "should match EAN of Desitin"
    end
  end

  context 'when --append -I 80 -e is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('--append -I 80 -e'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it "oddb_article with stuf from ZurRose", :skip => "ZurRose contains ERYTHROCIN i.v. Troc*esteekensub 1000 mg Amp [!]" do
      checkArticleXml
    end

    it 'should emit a correct oddb_article.xml' do
      checkArticleXml(false)
    end

    it 'should generate a valid oddb_product.xml' do
      @res.should match(/products/)
      checkProductXml
    end

    it 'should contain the correct (increased) prices' do
      checkPrices(true)
    end
  end
end

if RUN_ALL
  context 'when option -e is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-e'.split(' '))
      Oddb2xml::Cli.new(options.opts)
      if RUN_ALL
        @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
      else
        Oddb2xml::Cli.new(options.opts).run
      end
    end

    it 'should emit a correct oddb_article.xml' do
      checkArticleXml
    end

    it 'should produce a correct oddb_product.xml' do
      checkProductXml
    end

    it 'should report correct output on stdout' do
      @res.should match(/\sPharma products: \d+/)
      @res.should match(/\sNonPharma products: \d+/)
    end if RUN_ALL

    it 'should contain the correct (normal) prices' do
      checkPrices(false)
    end

    it 'should generate the flag non-refdata' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName('non-refdata'))
      XPath.match( doc, "//REF_DATA" ).size.should > 0
      checkItemForRefdata(doc, "1699947", 1) # 3TC Filmtabl 150 mg SMNO 53662013 IKSNR 53‘662, 53‘663
      checkItemForRefdata(doc, "0598003", 0) # SOFRADEX Gtt Auric 8 ml
      checkItemForRefdata(doc, "5366964", 1) # 1-DAY ACUVUE moist jour
      novopen = checkItemForRefdata(doc, "3036984", 1) # NovoPen 4 Injektionsgerät blue In NonPharma (a MiGel product)
      expect(novopen.elements['ARTBAR/BC'].text).to eq '0'
    end

    it 'should generate SALECD A for migel (NINCD 13)' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      article = XPath.match( doc, "//ART[ARTINS/NINCD=13]").first
      article = XPath.match( doc, "//ART[PHAR=5366964]").first
      article.elements['SALECD'].text.should == 'A'
      article.elements['ARTINS/NINCD'].text.should == '13'
    end

    it 'should pass validating via oddb2xml.xsd' do
      check_validation_via_xsd
    end

    it 'should not contain veterinary iksnr 47066 CANIPHEDRIN'  do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      XPath.match( doc, "//BC" ).find_all{|x| x.text.match('47066') }.size.should == 0
      XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/CANIPHEDRIN/) }.size.should == 0
    end

    it 'should handle not duplicate pharmacode 5366964'  do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('5366964') }.size.should == 1
      dscrds.size.should == NrExtendedArticles
      XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size.should >= 1
      XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('002771') }.size.should == 0
      XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('620691') }.size.should == 1
    end

    it 'should load correct number of nonpharma' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      dscrds.size.should == NrExtendedArticles
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('1699947') }.size.should == 1 # swissmedic_packages Cardio-Pulmo-Rénal Sérocytol, suppositoire
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('2465312') }.size.should == 1 # from refdata_pharma.xml"
      XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('0000000') }.size.should == 1 # from refdata_pharma.xml
    end

    it 'should emit a correct oddb_limitation.xml' do
      # check limitations
      limitation_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_limitation.xml'))
      File.exists?(limitation_filename).should eq true
      doc = REXML::Document.new File.new(limitation_filename)
      limitations = XPath.match( doc, "//LIM" )
      limitations.size.should >= 4
      XPath.match( doc, "//SwissmedicNo5" ).find_all{|x| x.text.match('28486') }.size.should == 1
      XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('ZYVOXID') }.size.should == 1
      XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('070240') }.size.should == 1
      XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Gesamthaft zugelassen/) }.size.should == 1
      XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Behandlung nosokomialer Pneumonien/) }.size.should == 1
    end

    it 'should emit a correct oddb_substance.xml' do
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_substance.xml'))
      names = XPath.match( doc, "//NAML" )
      names.size.should == NrSubstances
      names.find_all{|x| x.text.match('Lamivudinum') }.size.should == 1
    end

    it 'should emit a correct oddb_interaction.xml' do
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_interaction.xml'))
      titles = XPath.match( doc, "//TITD" )
      titles.size.should eq 5
      titles.find_all{|x| x.text.match('Keine Interaktion') }.size.should >= 1
      titles.find_all{|x| x.text.match('Erhöhtes Risiko für Myopathie und Rhabdomyolyse') }.size.should == 1
    end

    def checkItemForSALECD(doc, ean13, expected)
      article = XPath.match( doc, "//ART[ARTBAR/BC=#{ean13.to_s}]").first
      name    =  article.elements['DSCRD'].text
      salecd  =  article.elements['SALECD'].text
      if $VERBOSE or article.elements['SALECD'].text != expected.to_s
        puts "checking doc for ean13 #{ean13} expected #{expected} == #{salecd}. #{name}"
        puts article.text
      end
      article.elements['SALECD'].text.should == expected.to_s
    end

    it 'should generate the flag SALECD' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-SALECD.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      XPath.match( doc, "//REF_DATA" ).size.should > 0
      checkItemForSALECD(doc, Oddb2xml::FERRO_GRADUMET_GTIN, 'A') # FERRO-GRADUMET Depottabl 30 Stk
      checkItemForSALECD(doc, Oddb2xml::SOFRADEX_GTIN, 'I') # SOFRADEX
    end
  end
if RUN_ALL
  context 'testing -e -I 80 option' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-e -I 80'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should add 80 percent to zur_rose pubbprice' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      File.exists?(@article_xml).should eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-e80.xml'))
      checkProductXml
      checkArticleXml
      checkPrices(true)
    end

    it 'should generate a correct oddb_product.xml' do
      checkProductXml
    end
    it 'should generate a correct oddb_article.xml' do
      checkArticleXml
    end
  end

  context 'when -f dat -p is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat -p'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should report correct number of items' do
      @res.should match(/products/)
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat.should match(/^..2/), "should have a record with '2' in CMUT field"
      oddb_dat.should match(/^..3/), "should have a record with '3' in CMUT field"
      oddb_dat.should match(RegExpDesitin), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line) }
      # oddb_dat.should match(/^..1/), "should have a record with '1' in CMUT field" # we have no
    end
  end

  context 'when -f dat -I 80 is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat -I 80'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it 'should report correct number of items' do
      @res.should match(/products/)
    end

    it 'should contain the corect prices' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      File.exists?(dat_filename).should eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat_lines = IO.readlines(dat_filename)
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line, 883, true) }
    end
  end
end
end
end