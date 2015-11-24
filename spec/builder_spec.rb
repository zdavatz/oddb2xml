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
  expect(article.elements['REF_DATA'].text).to eq(isRefdata.to_s)
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
  expect(typ).to    eq '11'
  puts "check_article_IGM_format: #{price_exf} #{price_public} CKZL is #{ckzl} CIKS is #{ciks} name  #{name} " if $VERBOSE
  found_SL = false
  found_non_SL = false

  if /7680353660163\d$/.match(line) # KENDURAL Depottabl 30 Stk
    puts "found_SL for #{line}" if $VERBOSE
    found_SL = true
    expect(line[60..65]).to eq '000491'
    expect(price_exf).to eq 491
    expect(ckzl).to eq '1'
    expect(price_public).to eq price_kendural     # this is a SL-product. Therefore we may not have a price increase
    expect(line[66..71]).to eq '000'+price_kendural.to_s  # the dat format requires leading zeroes and not point
  end

  if /7680403330459\d$/.match(line) # CARBADERM
    found_non_SL = true
    puts "found_non_SL for #{line}" if $VERBOSE
    expect(ckzl).to eq '3'
    if add_80_percents
      expect(price_reseller).to eq    2919  # = 1545*1.8 this is a non  SL-product. Therefore we must increase its price as requsted
      expect(line[66..71]).to eq '002919' # dat format requires leading zeroes and not poin
    else
      expect(price_reseller).to eq     2770  # this is a non  SL-product, but no price increase was requested
      expect(line[66..71]).to eq '002770' # the dat format requires leading zeroes and not point
    end
    expect(line[60..65]).to eq '001622' # the dat format requires leading zeroes and not point
    expect(price_exf).to eq    1622      # this is a non  SL-product, but no price increase was requested
  end
  return [found_SL, found_non_SL]
end

def check_validation_via_xsd
  @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
  @oddb_calc_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_calc.xsd'))
  expect(File.exists?(@oddb2xml_xsd)).to eq true
  expect(File.exists?(@oddb_calc_xsd)).to eq true
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
        expect(error.message).to be_nil
    end
  }
end

def checkPrices(increased = false)
  doc = REXML::Document.new File.new(checkAndGetArticleXmlName)

  sofradex = checkAndGetArticleWithGTIN(doc, Oddb2xml::SOFRADEX_GTIN)
  expect(sofradex.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text).to eq Oddb2xml::SOFRADEX_PRICE_ZURROSE.to_s
  expect(sofradex.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text).to eq Oddb2xml::SOFRADEX_PRICE_ZURROSEPUB.to_s

  lansoyl = checkAndGetArticleWithGTIN(doc, Oddb2xml::LANSOYL_GTIN)
  expect(lansoyl.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text).to eq Oddb2xml::LANSOYL_PRICE_ZURROSE.to_s
  expect(lansoyl.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text).to eq Oddb2xml::LANSOYL_PRICE_ZURROSEPUB.to_s

  desitin = checkAndGetArticleWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  expect(desitin.elements["ARTPRI[PTYP='PPUB']/PRICE"].text).to eq Oddb2xml::LEVETIRACETAM_PRICE_PPUB.to_s
  expect(desitin.elements["ARTPRI[PTYP='ZURROSE']/PRICE"].text).to eq Oddb2xml::LEVETIRACETAM_PRICE_ZURROSE.to_s
  expect(desitin.elements["ARTPRI[PTYP='ZURROSEPUB']/PRICE"].text.to_f).to eq Oddb2xml::LEVETIRACETAM_PRICE_PPUB.to_f
  if increased
    expect(lansoyl.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text).to eq Oddb2xml::LANSOYL_PRICE_RESELLER_PUB.to_s
    expect(sofradex.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text).to eq Oddb2xml::SOFRADEX_PRICE_RESELLER_PUB.to_s
    expect(desitin.elements["ARTPRI[PTYP='RESELLERPUB']/PRICE"].text).to eq Oddb2xml::LEVETIRACETAM_PRICE_RESELLER_PUB.to_s
  else
    expect(lansoyl.elements["ARTPRI[PTYP='RESELLERPUB']"]).to eq nil
    expect(sofradex.elements["ARTPRI[PTYP='RESELLERPUB']"]).to eq nil
    expect(desitin.elements["ARTPRI[PTYP='RESELLERPUB']"]).to eq nil
  end
end

def checkAndGetArticleXmlName(tst=nil)
  article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
  expect(File.exists?(article_xml)).to eq true
  FileUtils.cp(article_xml, File.join(Oddb2xml::WorkDir, "tst-#{tst}.xml")) if tst
  article_xml
end

def checkAndGetProductWithGTIN(doc, gtin)
  products = XPath.match( doc, "//PRD[GTIN=#{gtin.to_s}]")
  gtins    = XPath.match( doc, "//PRD[GTIN=#{gtin.to_s}]/GTIN")
  binding.pry unless gtins.size == 1
  expect(gtins.size).to eq 1
  expect(gtins.first.text).to eq gtin.to_s
  # return product
  return products.size == 1 ? products.first : nil
end

def checkAndGetArticleWithGTIN(doc, gtin)
  articles = XPath.match( doc, "//ART[ARTBAR/BC=#{gtin}]")
  gtins    = XPath.match( doc, "//ART[ARTBAR/BC=#{gtin}]/ARTBAR/BC")
  expect(gtins.size).to eq 1
  expect(gtins.first.text).to eq gtin.to_s
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
  expect(desitin).not_to eq nil
  # TODO: why is this now nil? desitin.elements['ATC'].text.should == 'N03AX14'
  expect(desitin.elements['DSCRD'].text).to eq("LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk")
  expect(desitin.elements['DSCRF'].text).to eq('LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce')
  expect(desitin.elements['REF_DATA'].text).to eq('1')
  expect(desitin.elements['PHAR'].text).to eq('5819012')
  expect(desitin.elements['SMCAT'].text).to eq('B')
  expect(desitin.elements['SMNO'].text).to eq('62069008')
  expect(desitin.elements['VAT'].text).to eq('2')
  expect(desitin.elements['PRODNO'].text).to eq('620691')
  expect(desitin.elements['SALECD'].text).to eq('A')
  expect(desitin.elements['CDBG'].text).to eq('N')
  expect(desitin.elements['BG'].text).to eq('N')

  erythrocin_gtin = '7680202580475' # picked up from zur rose
  erythrocin = checkAndGetArticleWithGTIN(doc, erythrocin_gtin)
  expect(erythrocin.elements['DSCRD'].text).to eq("ERYTHROCIN i.v. Trockensub 1000 mg Amp") if checkERYTHROCIN

  lansoyl = checkAndGetArticleWithGTIN(doc, Oddb2xml::LANSOYL_GTIN)
  expect(lansoyl.elements['DSCRD'].text).to eq 'LANSOYL Gel 225 g'
  expect(lansoyl.elements['REF_DATA'].text).to eq '1'
  expect(lansoyl.elements['SMNO'].text).to eq '32475019'
  expect(lansoyl.elements['PHAR'].text).to eq '0023722'
  expect(lansoyl.elements['ARTCOMP/COMPNO'].text).to eq('7601001002012')

  zyvoxid = checkAndGetArticleWithGTIN(doc, Oddb2xml::ZYVOXID_GTIN)
  expect(zyvoxid.elements['DSCRD'].text).to eq 'ZYVOXID Filmtabl 600 mg 10 Stk'

  expect(XPath.match( doc, "//LIMPTS" ).size).to be >= 1
  # TODO: desitin.elements['QTY'].text.should eq '250 mg'
end

def checkProductXml
  product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
  expect(File.exists?(product_filename)).to eq true

  # check products
  doc = REXML::Document.new IO.read(product_filename)
  desitin = checkAndGetProductWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  expect(desitin.elements['ATC'].text).to eq('N03AX14')
  expect(desitin.elements['DSCRD'].text).to eq("LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk")
  expect(desitin.elements['DSCRF'].text).to eq('LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce')
  expect(desitin.elements['PRODNO'].text).to eq '620691'
  expect(desitin.elements['IT'].text).to eq '01.07.1.'
  expect(desitin.elements['PackGrSwissmedic'].text).to eq '30'
  expect(desitin.elements['EinheitSwissmedic'].text).to eq 'Tablette(n)'
  expect(desitin.elements['SubstanceSwissmedic'].text).to eq 'levetiracetamum'
  expect(desitin.elements['CompositionSwissmedic'].text).to eq 'levetiracetamum 250 mg, excipiens pro compressi obducti pro charta.'

  expect(desitin.elements['CPT/CPTCMP/LINE'].text).to eq '0'
  expect(desitin.elements['CPT/CPTCMP/SUBNO'].text).to eq '9'
  expect(desitin.elements['CPT/CPTCMP/QTY'].text).to eq '250'
  expect(desitin.elements['CPT/CPTCMP/QTYU'].text).to eq 'mg'

  checkAndGetProductWithGTIN(doc, Oddb2xml::THREE_TC_GTIN)
  checkAndGetProductWithGTIN(doc, Oddb2xml::ZYVOXID_GTIN)
  if $VERBOSE
    puts "checkProductXml #{product_filename} #{File.size(product_filename)} #{File.mtime(product_filename)}"
    puts "checkProductXml has #{XPath.match( doc, "//PRD" ).find_all{|x| true}.size} packages"
    puts "checkProductXml has #{XPath.match( doc, "//GTIN" ).find_all{|x| true}.size} GTIN"
    puts "checkProductXml has #{XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size} PRODNO"
  end
  expect(XPath.match( doc, "//PRD" ).find_all{|x| true}.size).to eq(NrPackages)
  expect(XPath.match( doc, "//GTIN" ).find_all{|x| true}.size).to eq(NrPackages)
  expect(XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size).to eq(NrProdno)

  hirudoid = checkAndGetProductWithGTIN(doc, Oddb2xml::HIRUDOID_GTIN)
  expect(hirudoid.elements['ATC'].text).to eq('C05BA01') # modified by atc.csv!
end

describe Oddb2xml::Builder do
  NrExtendedArticles = 86
  NrSubstances = 12
  NrProdno = 21
  NrPackages = 22
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
      # Oddb2xml::Cli.new(options.opts).run # to debug
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      @doc = Nokogiri::XML(File.open(@article_xml))
      @rexml = REXML::Document.new File.read(@article_xml)
    end

    it 'should return produce a oddb_article.xml' do
      expect(File.exists?(@article_xml)).to eq true
    end

    it 'oddb_article.xml should contain a SHA256' do
      expect(XPath.match(@rexml, "//ART" ).first.attributes['SHA256'].size).to eq 64
      expect(XPath.match(@rexml, "//ART" ).size).to eq XPath.match(@rexml, "//ART" ).size
    end

    it 'should be possible to verify the oddb_article.xml' do
      result = Oddb2xml.verify_sha256(@article_xml)
      expect(result)
    end

    it 'should be possible to verify all xml files against our XSD' do
      check_validation_via_xsd
    end

    it 'should have a correct insulin (gentechnik) for 7680532900196' do
      expect(XPath.match( @rexml, "//ART/[BC='7680532900196']").size).to eq 1
      expect(XPath.match( @rexml, "//ART//GEN_PRODUCTION").size).to eq 1
      expect(XPath.match( @rexml, "//ART//GEN_PRODUCTION").first.text).to eq 'X'
      expect(XPath.match( @rexml, "//ART//INSULIN_CATEGORY").size).to eq 1
      expect(XPath.match( @rexml, "//ART//INSULIN_CATEGORY").first.text).to eq 'Insulinanalog: schnell wirkend'
    end

    it 'should have a correct drug information for 7680555610041' do
      expect(XPath.match( @rexml, "//ART/[BC='7680555610041']").size).to eq 1
      expect(XPath.match( @rexml, "//ART//DRUG_INDEX").size).to eq 1
      expect(XPath.match( @rexml, "//ART//DRUG_INDEX").first.text).to eq 'd'
      found = false
      XPath.match( @rexml, "//ART//CDBG").each{
        |flag|
          if  flag.text.eql?('Y')
            found = true
            break
          end
      }
      expect(found)
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
      expect(File.exists?(@oddb_fi_xml)).to eq true
      inhalt = IO.read(@oddb_fi_xml)
      expect(/<KMP/.match(inhalt.to_s).to_s).to eq '<KMP'
      expect(/<style><!\[CDATA\[p{margin-top/.match(inhalt.to_s).to_s).to eq '<style><![CDATA[p{margin-top'
      m = /<paragraph><!\[CDATA\[(.+)\n(.*)/.match(inhalt.to_s)
      expect(m[1]).to eq '<?xml version="1.0" encoding="utf-8"?><div xmlns="http://www.w3.org/1999/xhtml">'
      expected = '<p class="s2"> </p>'
      skip { m[2].should eq '<p class="s4" id="section1"><span class="s2"><span>Zyvoxid</span></span><sup class="s3"><span>®</span></sup></p>'  }
      expect(File.exists?(@oddb_fi_product_xml)).to eq true
      inhalt = IO.read(@oddb_fi_product_xml)
    end

if RUN_ALL
    it 'should produce valid xml files' do
      skip "Niklaus does not know how to create a valid oddb_fi_product.xml"
      # check_validation_via_xsd
    end

    it 'should generate a valid oddb_product.xml' do
      expect(@res).to match(/products/)
      checkProductXml
    end
  end

  context 'when -f dat is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('-f dat --log'.split(' '))
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
      # Oddb2xml::Cli.new(options.opts).run # to debug
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      expect(@res).to match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(/^..2/), "should have a record with '2' in CMUT field"
      expect(oddb_dat).to match(/^..3/), "should have a record with '3' in CMUT field"
      expect(oddb_dat).to match(RegExpDesitin), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line) }
      m = /.+DIAPHIN Trocke.*7680555610041.+/.match(oddb_dat)
      expect(m[0].size).to eq 97 # size of IGM 1 record
      expect(m[0][74]).to eq '3'
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
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(RegExpDesitin), "should have Desitin"
      expect(@res).to match(/products/)
    end

    it "should match EAN 76806206900842 of Desitin" do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb_with_migel.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(/76806206900842/), "should match EAN of Desitin"
    end
  end

  context 'when --append -I 80 -e is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.new
      options.parser.parse!('--append -I 80 -e'.split(' '))
      Oddb2xml::Cli.new(options.opts).run
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options.opts).run }
    end

    it "oddb_article with stuf from ZurRose", :skip => "ZurRose contains ERYTHROCIN i.v. Troc*esteekensub 1000 mg Amp [!]" do
      checkArticleXml
    end

    it 'should emit a correct oddb_article.xml' do
      checkArticleXml(false)
    end

    it 'should generate a valid oddb_product.xml' do
      expect(@res).to match(/products/)
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
      expect(@res).to match(/\sPharma products: \d+/)
      expect(@res).to match(/\sNonPharma products: \d+/)
    end if RUN_ALL

    it 'should contain the correct (normal) prices' do
      checkPrices(false)
    end

    it 'should generate the flag non-refdata' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName('non-refdata'))
      expect(XPath.match( doc, "//REF_DATA" ).size).to be > 0
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
      expect(article.elements['SALECD'].text).to eq('A')
      expect(article.elements['ARTINS/NINCD'].text).to eq('13')
    end

    it 'should pass validating via oddb2xml.xsd' do
      check_validation_via_xsd
    end

    it 'should not contain veterinary iksnr 47066 CANIPHEDRIN'  do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      expect(XPath.match( doc, "//BC" ).find_all{|x| x.text.match('47066') }.size).to eq(0)
      expect(XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/CANIPHEDRIN/) }.size).to eq(0)
    end

    it 'should handle not duplicate pharmacode 5366964'  do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('5366964') }.size).to eq(1)
      expect(dscrds.size).to eq(NrExtendedArticles)
      expect(XPath.match( doc, "//PRODNO" ).find_all{|x| true}.size).to be >= 1
      expect(XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('002771') }.size).to eq(0)
      expect(XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('620691') }.size).to eq(1)
    end

    it 'should load correct number of nonpharma' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      expect(dscrds.size).to eq(NrExtendedArticles)
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('1699947') }.size).to eq(1) # swissmedic_packages Cardio-Pulmo-Rénal Sérocytol, suppositoire
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('2465312') }.size).to eq(1) # from refdata_pharma.xml"
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('0000000') }.size).to eq(1) # from refdata_pharma.xml
    end

    it 'should emit a correct oddb_limitation.xml' do
      # check limitations
      limitation_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_limitation.xml'))
      expect(File.exists?(limitation_filename)).to eq true
      doc = REXML::Document.new File.new(limitation_filename)
      limitations = XPath.match( doc, "//LIM" )
      expect(limitations.size).to be >= 4
      expect(XPath.match( doc, "//SwissmedicNo5" ).find_all{|x| x.text.match('28486') }.size).to eq(1)
      expect(XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('ZYVOXID') }.size).to eq(1)
      expect(XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('070240') }.size).to eq(1)
      expect(XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Gesamthaft zugelassen/) }.size).to eq(1)
      expect(XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Behandlung nosokomialer Pneumonien/) }.size).to eq(1)
    end

    it 'should emit a correct oddb_substance.xml' do
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_substance.xml'))
      names = XPath.match( doc, "//NAML" )
      expect(names.size).to eq(NrSubstances)
      expect(names.find_all{|x| x.text.match('Lamivudinum') }.size).to eq(1)
    end

    it 'should emit a correct oddb_interaction.xml' do
      doc = REXML::Document.new File.new(File.join(Oddb2xml::WorkDir, 'oddb_interaction.xml'))
      titles = XPath.match( doc, "//TITD" )
      expect(titles.size).to eq 5
      expect(titles.find_all{|x| x.text.match('Keine Interaktion') }.size).to be >= 1
      expect(titles.find_all{|x| x.text.match('Erhöhtes Risiko für Myopathie und Rhabdomyolyse') }.size).to eq(1)
    end

    def checkItemForSALECD(doc, ean13, expected)
      article = XPath.match( doc, "//ART[ARTBAR/BC=#{ean13.to_s}]").first
      name    =  article.elements['DSCRD'].text
      salecd  =  article.elements['SALECD'].text
      if $VERBOSE or article.elements['SALECD'].text != expected.to_s
        puts "checking doc for ean13 #{ean13} expected #{expected} == #{salecd}. #{name}"
        puts article.text
      end
      expect(article.elements['SALECD'].text).to eq(expected.to_s)
    end

    it 'should generate the flag SALECD' do
      @article_xml = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_article.xml'))
      expect(File.exists?(@article_xml)).to eq true
      FileUtils.cp(@article_xml, File.join(Oddb2xml::WorkDir, 'tst-SALECD.xml'))
      article_xml = IO.read(@article_xml)
      doc = REXML::Document.new File.new(@article_xml)
      expect(XPath.match( doc, "//REF_DATA" ).size).to be > 0
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
      expect(File.exists?(@article_xml)).to eq true
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
      expect(@res).to match(/products/)
    end

    it 'should contain the correct values fo CMUT from zurrose_transfer.dat' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(/^..2/), "should have a record with '2' in CMUT field"
      expect(oddb_dat).to match(/^..3/), "should have a record with '3' in CMUT field"
      expect(oddb_dat).to match(RegExpDesitin), "should have Desitin"
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
      expect(@res).to match(/products/)
    end

    it 'should contain the corect prices' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat_lines = IO.readlines(dat_filename)
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line, 883, true) }
    end
  end
end
end
end