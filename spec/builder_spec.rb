# encoding: utf-8

require 'spec_helper'
require "rexml/document"
require 'webmock/rspec'
include REXML
RUN_ALL = true

# TODO: Add articles which contain these values
# not done, because it was easy to verify this by running on the command line grep 'LIMPTS' oddb_article.xml | sort | uniq
ARTICLE_ATTRIBUTE_TESTS =   [
  ['ARTICLE', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['ARTICLE', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['ARTICLE', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['ARTICLE/ART', 'SHA256', /[a-f0-9]{32}/],
  ['ARTICLE/ART', 'DT', /\d{4}-\d{2}-\d{2}/],
]

ARTICLE_MISSING_ELEMENTS =    [
  ['ARTICLE/ART/LIMPTS', '10'],
  ['ARTICLE/ART/LIMPTS', '30'],
  ['ARTICLE/ART/LIMPTS', '40'],
  ['ARTICLE/ART/LIMPTS', '50'],
  ['ARTICLE/ART/LIMPTS', '60'],
  ['ARTICLE/ART/LIMPTS', '80'],
  ['ARTICLE/ART/LIMPTS', '100'],
  ['ARTICLE/ART/SLOPLUS', '1'],
]

ARTICLE_ZURROSE_ELEMENTS =    [
  ['ARTICLE/ART/REF_DATA', '0'],
  ['ARTICLE/ART/ARTCOMP/COMPNO', '7601001000896'],
  ['ARTICLE/ART/ARTPRI/PTYP', 'PEXF'],
  ['ARTICLE/ART/ARTPRI/PTYP', 'PPUB'],
  ['ARTICLE/ART/ARTPRI/PTYP', 'ZURROSE'],
  ['ARTICLE/ART/ARTPRI/PTYP', 'ZURROSEPUB'],
  ['ARTICLE/ART/ARTINS/NINCD', '13'],
  ['ARTICLE/ART/ARTINS/NINCD', '20'],
]

ARTICLE_NAROPIN = %(<REF_DATA>1</REF_DATA>
    <PHAR>1882189</PHAR>
    <SMCAT>B</SMCAT>
    <SMNO>54015011</SMNO>
    <PRODNO>5401501</PRODNO>
    <SALECD>I</SALECD>
    <CDBG>N</CDBG>
    <BG>N</BG>
    <DSCRD>NAROPIN Inj Lös 0.2 % 10ml Duofit Amp 5 Stk</DSCRD>
    <DSCRF>NAROPIN sol inj 0.2 % 10ml amp duofit 5 pce</DSCRF>
    <SORTD>NAROPIN INJ LÖS 0.2 % 10ML DUOFIT AMP 5 STK</SORTD>
    <SORTF>NAROPIN SOL INJ 0.2 % 10ML AMP DUOFIT 5 PCE</SORTF>
    <ARTCOMP>
      <COMPNO>7601001402539</COMPNO>
    </ARTCOMP>
    <ARTBAR>
      <CDTYP>E13</CDTYP>
      <BC>7680540150118</BC>
      <BCSTAT>A</BCSTAT>
    </ARTBAR>
  </ART>)
  
ARTICLE_COMMON_ELEMENTS =    [
  ['ARTICLE/ART/REF_DATA', '1'],
  ['ARTICLE/ART/SMCAT', 'A'],
  ['ARTICLE/ART/SMCAT', 'B'],
  ['ARTICLE/ART/SMCAT', 'C'],
  ['ARTICLE/ART/SMCAT', 'D'],
  ['ARTICLE/ART/GEN_PRODUCTION', 'X'],
  ['ARTICLE/ART/DRUG_INDEX', 'd'],
  ['ARTICLE/ART/INSULIN_CATEGORY', 'Insulinanalog: schnell wirkend'],
  ['ARTICLE/ART/SMNO', '16105058'],
  ['ARTICLE/ART/PRODNO', '1610501'],
  ['ARTICLE/ART/VAT', '2'],
  ['ARTICLE/ART/SALECD', 'A'],
  ['ARTICLE/ART/SALECD', 'I'],
  ['ARTICLE/ART/COOL', '1'],
  ['ARTICLE/ART/LIMPTS', '20'],
  ['ARTICLE/ART/CDBG', 'Y'],
  ['ARTICLE/ART/CDBG', 'N'],
  ['ARTICLE/ART/BG', 'Y'],
  ['ARTICLE/ART/BG', 'N'],
  ['ARTICLE/ART/ARTBAR/BC', Oddb2xml::ORPHAN_GTIN.to_s],
  ['ARTICLE/ART/ARTBAR/BC', Oddb2xml::FRIDGE_GTIN.to_s],
  ['ARTICLE/ART/SYN1D', 'Hirudoid'],
  ['ARTICLE/ART/SYN1F', 'Hirudoid'],
  ['ARTICLE/ART/SLOPLUS', '2'],
  ['ARTICLE/ART/ARTINS/NINCD', '10'],
]

CODE_ATTRIBUTE_TESTS =   [
  ['CODE', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['CODE', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['CODE', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['CODE/CD', 'DT', ''],
]

CODE_MISSING_ELEMENT_TESTS = [
]

CODE_ELEMENT_TESTS = [
  ['CODE/CD/CDTYP', '11'],
  ['CODE/CD/CDTYP', '13'],
  ['CODE/CD/CDTYP', '14'],
  ['CODE/CD/CDTYP', '15'],
  ['CODE/CD/CDTYP', '16'],
  ['CODE/CD/CDVAL', 'A'],
  ['CODE/CD/CDVAL', 'B'],
  ['CODE/CD/CDVAL', 'C'],
  ['CODE/CD/CDVAL', 'D'],
  ['CODE/CD/CDVAL', 'X'],
  ['CODE/CD/DSCRSD', 'Kontraindiziert'],
  ['CODE/CD/DSCRSD', 'Kombination meiden'],
  ['CODE/CD/DSCRSD', 'Monitorisieren'],
  ['CODE/CD/DSCRSD', 'Vorsichtsmassnahmen'],
  ['CODE/CD/DSCRSD', 'keine Massnahmen'],
  ['CODE/CD/DEL', 'false'],
]

INTERACTION_ATTRIBUTE_TESTS =   [
  ['INTERACTION', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['INTERACTION', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['INTERACTION', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['INTERACTION/IX', 'SHA256', /[a-f0-9]{32}/],
  ['INTERACTION/IX', 'DT', ''],
]

INTERACTION_MISSING_ELEMENT_TESTS = [
  ['INTERACTION/IX/EFFD', 'Kombination meiden'],
  ['INTERACTION/IX/EFFD', 'Kontraindiziert'],
  ['INTERACTION/IX/EFFD', 'Monitorisieren'],
  ['INTERACTION/IX/EFFD', 'Vorsichtsmassnahmen'],
  ['INTERACTION/IX/DEL', 'true'], # Never found???
]

INTERACTION_ELEMENT_TESTS = [
  ['INTERACTION/IX/IXNO', '2'],
  ['INTERACTION/IX/TITD', 'Keine Interaktion'],
  ['INTERACTION/IX/GRP1D', 'N06AB06'],
  ['INTERACTION/IX/GRP2D', 'M03BX02'],
  ['INTERACTION/IX/EFFD', 'Keine Interaktion.'],
  ['INTERACTION/IX/MECHD', /Tizanidin wird über CYP1A2 metabolisiert/],
  ['INTERACTION/IX/MEASD', /Die Kombination aus Sertralin und Tizanidin/],
  ['INTERACTION/IX/DEL', 'false'],
  ]

LIMITATION_ATTRIBUTE_TESTS =   [
  ['LIMITATION', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['LIMITATION', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['LIMITATION', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['LIMITATION/LIM', 'SHA256', /[a-f0-9]{32}/],
  ['LIMITATION/LIM', 'DT', ''],
]

# Found by  grep LIMTYP oddb_limitation.xml | sort | uniq
LIMITATION_MISSING_ELEMENT_TESTS = [
  ['LIMITATION/LIM/SwissmedicNo8', '62089002'],
  ['LIMITATION/LIM/Pharmacode', '0'],
  ['LIMITATION/LIM/LIMTYP', 'AUD'],
  ['LIMITATION/LIM/LIMTYP', 'KOM'],
  ['LIMITATION/LIM/LIMTYP', 'ZEI'],
]

LIMITATION_ELEMENT_TESTS = [
  ['LIMITATION/LIM/LIMVAL', '10'],
  ['LIMITATION/LIM/LIMVAL', '20'],
  ['LIMITATION/LIM/LIMVAL', '30'],
  ['LIMITATION/LIM/LIMVAL', '40'],
  ['LIMITATION/LIM/LIMVAL', '50'],
  ['LIMITATION/LIM/LIMVAL', '60'],
  ['LIMITATION/LIM/LIMVAL', '80'],
  ['LIMITATION/LIM/LIMVAL', '100'],
  ['LIMITATION/LIM/IT', '07.02.40.'],
  ['LIMITATION/LIM/LIMTYP', 'DIA'],
  ['LIMITATION/LIM/LIMTYP', 'PKT'],
  ['LIMITATION/LIM/LIMNAMEBAG', '070240'],
  ['LIMITATION/LIM/LIMNIV', 'IP'],
  ['LIMITATION/LIM/VDAT', /\d{2}\.\d{2}\.\d{4}/],
  ['LIMITATION/LIM/DSCRD', /Therapiedauer/],
  ['LIMITATION/LIM/DSCRF',  /Traitement de la pneumonie/],
  ['LIMITATION/LIM/SwissmedicNo5', '28486'],
  ]

SUBSTANCE_ATTRIBUTE_TESTS =   [
  ['SUBSTANCE', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['SUBSTANCE', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['SUBSTANCE', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['SUBSTANCE/SB', 'SHA256', /[a-f0-9]{32}/],
  ['SUBSTANCE/SB', 'DT', ''],
]

SUBSTANCE_MISSING_ELEMENT_TESTS = [
]

SUBSTANCE_ELEMENT_TESTS = [
  ['SUBSTANCE/SB/SUBNO', '1'],
  ['SUBSTANCE/SB/NAML', 'Linezolidum'],
]

# Betriebe and Medizinalpersonen don't work at the moment
BETRIEB_ATTRIBUTE_TESTS =   [
  ['Betriebe', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['Betriebe', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['Betriebe', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['Betriebe/Betrieb', 'DT', ''],
]

BETRIEB_MISSING_ELEMENT_TESTS = [
]

BETRIEB_ELEMENT_TESTS = [
  ['Betriebe/Betrieb/GLN_Betrieb', '974633'],
  ['Betriebe/Betrieb/Betriebsname_1', 'Betriebsname_1'],
  ['Betriebe/Betrieb/Betriebsname_2', 'Betriebsname_2'],
  ['Betriebe/Betrieb/Strasse', 'Strasse'],
  ['Betriebe/Betrieb/Nummer', 'Nummer'],
  ['Betriebe/Betrieb/PLZ', 'PLZ'],
  ['Betriebe/Betrieb/Ort', 'Ort'],
  ['Betriebe/Betrieb/Bewilligungskanton', 'Bewilligungskanton'],
  ['Betriebe/Betrieb/Land', 'Land'],
  ['Betriebe/Betrieb/Betriebstyp', 'Betriebstyp'],
  ['Betriebe/Betrieb/BTM_Berechtigung', 'BTM_Berechtigung'],
]

MEDIZINALPERSON_ATTRIBUTE_TESTS =   [
  ['Personen', 'CREATION_DATETIME', Oddb2xml::DATE_REGEXP],
  ['Personen', 'PROD_DATE', Oddb2xml::DATE_REGEXP],
  ['Personen', 'VALID_DATE', Oddb2xml::DATE_REGEXP],
  ['Personen/Person', 'DT', ''],
]

MEDIZINALPERSON_MISSING_ELEMENT_TESTS = [
]

MEDIZINALPERSON_ELEMENT_TESTS = [
  ['Personen/Person/GLN_Person', '56459'],
  ['Personen/Person/Name', 'Name'],
  ['Personen/Person/Vorname', 'Vorname'],
  ['Personen/Person/PLZ', 'PLZ'],
  ['Personen/Person/Ort', 'Ort'],
  ['Personen/Person/Bewilligungskanton', 'Bewilligungskanton'],
  ['Personen/Person/Land', 'Land'],
  ['Personen/Person/Bewilligung_Selbstdispensation', 'Bewilligung_Selbstdispensation'],
  ['Personen/Person/Diplom', 'Diplom'],
  ['Personen/Person/BTM_Berechtigung', 'BTM_Berechtigung'],
]

def check_result(inhalt, nbr_record)
  [ "<NBR_RECORD>",
    "<OK_ERROR>",
    '<OK_ERROR>OK</OK_ERROR>',
    ].each do |what|
    expect(inhalt.scan(what).size).to eq 1
  end
  expect(inhalt.index('<OK_ERROR>OK</OK_ERROR>')).to be > 0
  expect(inhalt.index('<ERROR_CODE/>')).to be > 0
  m = /<NBR_RECORD>(\d+)<\/NBR_RECORD>/.match(inhalt)
  expect(m).not_to be nil
  expect(m[1].to_i).to eq  nbr_record 
end

def checkItemForRefdata(doc, pharmacode, isRefdata)
  article = XPath.match( doc, "//ART[PHAR=#{pharmacode.to_s}]").first
  name =     article.elements['DSCRD'].text
  refdata =  article.elements['REF_DATA'].text
  smno    =  article.elements['SMNO'] ? article.elements['SMNO'].text : 'nil'
  puts "checking doc for gtin #{gtin} isRefdata #{isRefdata} == #{refdata}. SMNO: #{smno} #{name}" if $VERBOSE
  expect(article.elements['REF_DATA'].text).to eq(isRefdata.to_s)
  article
end

['article', 'betrieb', 'code', 'interaction', 'limitation', 'medizinalperson', 'product', 'substance'].each do |cat|
  eval "
    def oddb_#{cat}_xml
      File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_#{cat}.xml'))
    end
  "
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
    expect(line[60..65]).to eq '000496'
    expect(price_exf).to eq 496
    expect(ckzl).to eq '1'
    expect(price_public).to eq price_kendural     # this is a SL-product. Therefore we may not have a price increase
    expect(line[66..71]).to eq '000'+sprintf('%03d', price_kendural)  # the dat format requires leading zeroes and not point
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

def validate_via_xsd(xsd_file, xml_file)
  xsd =open(xsd_file).read
  xsd_rtikelstamm_xml = Nokogiri::XML::Schema(xsd)
  doc = Nokogiri::XML(File.read(xml_file))
  xsd_rtikelstamm_xml.validate(doc).each do
    |error|
      if error.message
        puts "Failed validating #{xml_file} with #{File.size(xml_file)} bytes using XSD from #{xsd_file}"
        puts "CMD: xmllint --noout --schema #{xsd_file} #{xml_file}"
      end
      msg = "expected #{error.message} to be nil\nfor #{xml_file}"
      puts msg
      expect(error.message).to be_nil, msg
  end
end

def check_validation_via_xsd
  files = Dir.glob('*.xml')
  files.each{
    |file|
    next if /#{Time.now.year}/.match(file)
    xsd2use = /oddb_calc/.match(file) ? @oddb_calc_xsd : @oddb2xml_xsd
    validate_via_xsd(xsd2use, File.expand_path(file))
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
  expect(desitin.elements['PRODNO'].text).to eq('6206901')
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

def checkProductXml(nbr_record = -1)
  product_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_product.xml'))
  expect(File.exists?(product_filename)).to eq true

  # check products
  content = IO.read(product_filename)
  doc = REXML::Document.new content
  check_result(content, nbr_record)
  expect(nbr_record).to eq  content.scan(/<PRD/).size if nbr_record != -1

  desitin = checkAndGetProductWithGTIN(doc, Oddb2xml::LEVETIRACETAM_GTIN)
  expect(desitin.elements['ATC'].text).to eq('N03AX14')
  expect(desitin.elements['DSCRD'].text).to eq("LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk")
  expect(desitin.elements['DSCRF'].text).to eq('LEVETIRACETAM DESITIN mini cpr pel 250 mg 30 pce')
  expect(desitin.elements['PRODNO'].text).to eq '6206901'
  expect(desitin.elements['IT'].text).to eq '01.07.1.'
  expect(desitin.elements['PackGrSwissmedic'].text).to eq '30'
  expect(desitin.elements['EinheitSwissmedic'].text).to eq 'Tablette(n)'
  expect(desitin.elements['SubstanceSwissmedic'].text).to eq 'levetiracetamum'
  expect(desitin.elements['CompositionSwissmedic'].text).to eq 'levetiracetamum 250 mg, excipiens pro compressi obducti pro charta.'
  expect(desitin.elements['CPT/CPTCMP/LINE'].text).to eq '0'
  expect(desitin.elements['CPT/CPTCMP/SUBNO'].text).to eq '13'
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
  hirudoid = checkAndGetProductWithGTIN(doc, Oddb2xml::HIRUDOID_GTIN)
  expect(hirudoid.elements['ATC'].text).to eq('C05BA01') # modified by atc.csv!
end

describe Oddb2xml::Builder do
  NrExtendedArticles = 77
  NrSubstances = 27
  NrLimitations = 14
  
  NrInteractions = 2
  NrCodes = 5
  NrProdno = 31
  NrPackages = 43
  NrProducts = 39
  RegExpDesitin = /1125819012LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk/
  include ServerMockHelper
  def common_run_init(options = {})
    @savedDir = Dir.pwd
    @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
    @oddb_calc_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_calc.xsd'))
    expect(File.exist?(@oddb2xml_xsd)).to eq true
    expect(File.exist?(@oddb_calc_xsd)).to eq true
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WorkDir)
    Dir.chdir(Oddb2xml::WorkDir)
    mock_downloads
  end

  after(:all) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  context 'when default options are given' do
    before(:all) do
      common_run_init
      Oddb2xml::Cli.new({}).run # to debug
      @doc = Nokogiri::XML(File.open(oddb_article_xml))
      @inhalt = File.read(oddb_article_xml)
      @rexml = REXML::Document.new File.read(oddb_article_xml)
    end

    it 'should produce a oddb_article.xml' do
      expect(File.exists?(oddb_article_xml)).to eq true
    end

    it 'should have a correct NBR_RECORD in oddb_article.xml' do
      check_result(@inhalt, NrProducts)
    end

    it 'oddb_article.xml should contain a SHA256' do
      expect(XPath.match(@rexml, "//ART" ).first.attributes['SHA256'].size).to eq 64
      expect(XPath.match(@rexml, "//ART" ).size).to eq XPath.match(@rexml, "//ART" ).size
    end

    it 'should be possible to verify the oddb_article.xml' do
      result = Oddb2xml.verify_sha256(oddb_article_xml)
      expect(result)
    end

    it 'should be possible to verify all xml files against our XSD' do
      check_validation_via_xsd
    end

    check_attributes(oddb_article_xml, ARTICLE_ATTRIBUTE_TESTS)
    check_elements(oddb_article_xml, ARTICLE_COMMON_ELEMENTS)
    
    it 'should validate XSD article' do
      @inhalt = File.read(oddb_article_xml)
      # This fails on Ruby < 2.4 as NAROPIN INJ LÖS 0.2 % 10 is wrongly encoded
      expect(File.read(oddb_article_xml).scan(ARTICLE_NAROPIN).size).to eq 1
    end

    context 'XSD betrieb' do
      skip 'At the moment downloading and extractiong the medreg is broken!'
      # check_attributes(oddb_betrieb_xml, BETRIEB_ATTRIBUTE_TESTS)
      # check_elements(oddb_betrieb_xml, BETRIEB_COMMON_ELEMENTS)
    end

    context 'XSD medizinalperson' do
      skip 'At the moment downloading and extractiong the medreg is broken!'
      # check_attributes(oddb_medizinalperson_xml, MEDIZINAPERSON_ATTRIBUTE_TESTS)
      # check_elements(oddb_medizinalperson_xml, MEDIZINAPERSON_COMMON_ELEMENTS)
    end

    it 'should have a correct insulin (gentechnik) for 7680532900196' do
      expect(XPath.match( @rexml, "//ART/[BC='7680532900196']").size).to eq 1
      expect(XPath.match( @rexml, "//ART//GEN_PRODUCTION").size).to be >= 1
      expect(XPath.match( @rexml, "//ART//GEN_PRODUCTION").first.text).to eq 'X'
      expect(XPath.match( @rexml, "//ART//INSULIN_CATEGORY").size).to eq 1
      expect(XPath.match( @rexml, "//ART//INSULIN_CATEGORY").first.text).to eq 'Insulinanalog: schnell wirkend'
    end

    it 'should flag fridge drugs correctly' do
      doc = REXML::Document.new IO.read(checkAndGetArticleXmlName)
      checkAndGetArticleWithGTIN(doc, Oddb2xml::FRIDGE_GTIN)
      expect(XPath.match( doc, "//COOL='1']").size).to eq 1
    end

    ean_with_drug_index = 7680555610041
    it "should have a correct drug information for #{ean_with_drug_index}" do
      doc = REXML::Document.new IO.read(checkAndGetArticleXmlName)
      expect(XPath.match( @rexml, "//ART/[BC='#{ean_with_drug_index}']").size).to eq 1
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
      options = Oddb2xml::Options.parse(['-o', '--log'])
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
      Oddb2xml::Cli.new(options).run
    end

    it 'should have a correct NBR_RECORD in oddb_fi_product.xml' do
      check_result( File.read('oddb_fi_product.xml'), 0)
    end

    it 'should have a correct NBR_RECORD in oddb_fi.xml' do
      check_result( File.read('oddb_fi.xml'), 2)
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

    it 'should produce valid xml files' do
      skip "Niklaus does not know how to create a valid oddb_fi_product.xml"
      # check_validation_via_xsd
    end

    it 'should generate a valid oddb_product.xml' do
      expect(@res).to match(/products/) if @res
      checkProductXml(NrPackages)
    end

  end

  context 'when -f dat is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('-f dat --log')
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
      # Oddb2xml::Cli.new(options).run # to debug
    end

    it 'should contain the correct values fo CMUT from transfer.dat' do
      expect(@res).to match(/products/)
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(/^..2/), "should have a record with '2' in CMUT field"
      expect(oddb_dat).to match(/^..3/), "should have a record with '3' in CMUT field"
      expect(oddb_dat).to match(RegExpDesitin), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line, 0) }
      m = /.+KENDURAL Depottabl 30 Stk.*7680353660163.+/.match(oddb_dat)
      expect(m[0].size).to eq 97 # size of IGM 1 record
      expect(m[0][74]).to eq '3'
    end
  end

  context 'when --append -f dat is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('--append -f dat')
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
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
      options = Oddb2xml::Options.parse('--append -I 80 -e')
      Oddb2xml::Cli.new(options).run
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
    end

    it "oddb_article with stuf from ZurRose", :skip => "ZurRose contains ERYTHROCIN i.v. Troc*esteekensub 1000 mg Amp [!]" do
      checkArticleXml
    end

     # Zeno used oddb2xml -e -I 45 -c zip for oddb_arcticle for artikelstamm 7680172330414 3605520301605
    it 'should add GTIN 7680172330414 which is marked as inactive in transfer.dat' do
      @inhalt = IO.read(oddb_article_xml)
      expect(@inhalt.index('7680172330414')).not_to be nil
    end

    it 'should add GTIN 3605520301605 Armani Attitude which is marked as inactive in transfer.dat' do
      @inhalt = IO.read(oddb_article_xml)
      #     <SALECD>I</SALECD>

      expect(@inhalt.index('3605520301605')).not_to be nil
    end

    context 'XSD' do
      check_attributes(oddb_article_xml, ARTICLE_ATTRIBUTE_TESTS)
      check_elements(oddb_article_xml, ARTICLE_COMMON_ELEMENTS)
      check_elements(oddb_article_xml, ARTICLE_ZURROSE_ELEMENTS)
      it 'should contain NAROPIN' do
        # This fails on Ruby < 2.4 as NAROPIN INJ LÖS 0.2 % 10 is wrongly encoded
        expect(File.read(oddb_article_xml).scan(ARTICLE_NAROPIN).size).to eq 1
      end
    end

    it 'should emit a correct oddb_article.xml' do
      checkArticleXml(false)
    end

    it 'should generate a valid oddb_product.xml' do
      expect(@res).to match(/products/) if @res != nil
      checkProductXml(NrPackages)
    end

    it 'should contain the correct (increased) prices' do
      checkPrices(true)
    end
  end

  context 'when option -e is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('-e')
      puts options
      @cli = Oddb2xml::Cli.new(options)
      if RUN_ALL
        @res = buildr_capture(:stdout){ @cli.run }
      else
        @cli.run
      end
    end

    context 'XSD limitation' do
      check_attributes(oddb_limitation_xml, LIMITATION_ATTRIBUTE_TESTS)
      check_elements(oddb_limitation_xml, LIMITATION_ELEMENT_TESTS)
    end

    context 'XSD code' do
      check_attributes(oddb_code_xml, CODE_ATTRIBUTE_TESTS)
      check_elements(oddb_code_xml, CODE_ELEMENT_TESTS)
    end

    it 'should have a correct NBR_RECORD in oddb_code.xml' do
      check_result(File.read(oddb_code_xml), NrCodes)
    end

    context 'XSD interaction' do
      check_attributes(oddb_interaction_xml, INTERACTION_ATTRIBUTE_TESTS)
      check_elements(oddb_interaction_xml, INTERACTION_ELEMENT_TESTS)
    end

    it 'should have a correct NBR_RECORD in oddb_interaction.xml' do
      check_result(File.read(oddb_interaction_xml), NrInteractions)
    end

    context 'XSD substance' do
      check_attributes(oddb_substance_xml, SUBSTANCE_ATTRIBUTE_TESTS)
      check_elements(oddb_substance_xml, SUBSTANCE_ELEMENT_TESTS)
    end

    it 'should have a correct NBR_RECORD in oddb_substance.xml' do
      check_result(File.read('oddb_substance.xml'), NrSubstances)
    end

    it 'should emit a correct oddb_article.xml' do
      checkArticleXml
    end

    it 'should produce a correct oddb_product.xml' do
      checkProductXml(NrPackages)
    end

    it 'should report correct output on stdout' do
      expect(@res).to match(/\sPharma products: \d+/)
      expect(@res).to match(/\sNonPharma products: \d+/)
    end if RUN_ALL

    it 'should contain the correct (normal) prices' do
      checkPrices(false)
    end

    it 'should generate the flag ORPH for orphan' do
      doc = REXML::Document.new File.new(oddb_product_xml)
      orphan = checkAndGetProductWithGTIN(doc, Oddb2xml::ORPHAN_GTIN)
      expect(orphan).not_to eq nil
      expect(orphan.elements['ORPH'].text).to eq("true")
    end

    it 'should generate the flag non-refdata' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName('non-refdata'))
      expect(XPath.match( doc, "//REF_DATA" ).size).to be > 0
      checkItemForRefdata(doc, "1699947", 1) # 3TC Filmtabl 150 mg SMNO 53662013 IKSNR 53‘662, 53‘663
      checkItemForRefdata(doc, "0598003", 0) # SOFRADEX Gtt Auric 8 ml
      checkItemForRefdata(doc, "5366964", 0) # 1-DAY ACUVUE moist jour
      unless SkipMigelDownloader
        novopen = checkItemForRefdata(doc, "3036984", 1) # NovoPen 4 Injektionsgerät blue In NonPharma (a MiGel product)
        expect(novopen.elements['ARTBAR/BC'].text).to eq '0'
      end
    end

    it 'should generate SALECD A for migel (NINCD 13)' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      article = XPath.match( doc, "//ART[PHAR=4236863]").first
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
      expect(XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('0027701') }.size).to eq(1)
      expect(XPath.match( doc, "//PRODNO" ).find_all{|x| x.text.match('6206901') }.size).to eq(1)
    end

    it 'should load correct number of nonpharma' do
      doc = REXML::Document.new File.new(checkAndGetArticleXmlName)
      dscrds = XPath.match( doc, "//ART" )
      expect(dscrds.size).to eq(NrExtendedArticles)
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('1699947') }.size).to eq(1) # swissmedic_packages Cardio-Pulmo-Rénal Sérocytol, suppositoire
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('2465312') }.size).to eq(1) # from refdata_pharma.xml"
      expect(XPath.match( doc, "//PHAR" ).find_all{|x| x.text.match('0000000') }.size).to eq(0) # 0 is not a valid pharmacode
    end

    it 'should have a correct NBR_RECORD in oddb_limitation.xml' do
      check_result(File.read('oddb_limitation.xml'), NrLimitations)
    end

    it 'should emit a correct oddb_limitation.xml' do
      # check limitations
      limitation_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_limitation.xml'))
      expect(File.exists?(limitation_filename)).to eq true
      doc = REXML::Document.new File.new(limitation_filename)
      limitations = XPath.match( doc, "//LIM" )
      expect(limitations.size).to eql NrLimitations
      expect(XPath.match( doc, "//SwissmedicNo5" ).find_all{|x| x.text.match('28486') }.size).to eq(1)
      expect(XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('ZYVOXID') }.size).to eq(2)
      expect(XPath.match( doc, "//LIMNAMEBAG" ).find_all{|x| x.text.match('070240') }.size).to be >= 1
      expect(XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Gesamthaft zugelassen/) }.size).to be >= 1
      expect(XPath.match( doc, "//DSCRD" ).find_all{|x| x.text.match(/^Behandlung nosokomialer Pneumonien/) }.size).to  be >= 1
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
      expect(titles.size).to eq 2
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
      expect(File.exists?(oddb_article_xml)).to eq true
      FileUtils.cp(oddb_article_xml, File.join(Oddb2xml::WorkDir, 'tst-SALECD.xml'))
      article_xml = IO.read(oddb_article_xml)
      doc = REXML::Document.new File.new(oddb_article_xml)
      expect(XPath.match( doc, "//REF_DATA" ).size).to be > 0
      checkItemForSALECD(doc, Oddb2xml::FERRO_GRADUMET_GTIN, 'A') # FERRO-GRADUMET Depottabl 30 Stk
      checkItemForSALECD(doc, Oddb2xml::SOFRADEX_GTIN, 'I') # SOFRADEX
    end
  end
  context 'testing -e -I 80 option' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('-e -I 80 --log')
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
      @res = Oddb2xml::Cli.new(options).run
    end

    it 'should add 80 percent to zur_rose pubbprice' do
      expect(File.exists?(oddb_article_xml)).to eq true
      FileUtils.cp(oddb_article_xml, File.join(Oddb2xml::WorkDir, 'tst-e80.xml'))
      checkArticleXml
      checkPrices(true)
    end

    it 'should generate an article for EPIMINERAL' do
      expect(File.exists?(oddb_article_xml)).to eq true
      doc = REXML::Document.new IO.read(oddb_article_xml)
      article = XPath.match( doc, "//ART[PHAR=5822801]").first
      expect(article.elements['DSCRD'].text).to match /EPIMINERAL/i
    end

    it 'should generate a correct number of packages in oddb_product.xml' do
      checkProductXml(NrPackages)
    end

    it 'should generate an article with the COOL (fridge) attribute' do
      doc = REXML::Document.new File.new(oddb_article_xml)
      fridge_product = checkAndGetArticleWithGTIN(doc, Oddb2xml::FRIDGE_GTIN)
      expect(fridge_product.elements['COOL'].text).to eq('1')
    end

    it 'should generate a correct oddb_article.xml' do
      checkArticleXml
    end
  end

  context 'when -f dat -p is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('-f dat -p')
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
    end

    it 'should report correct number of items' do
      expect(@res).to match(/products/)
    end

    it 'should contain the correct values fo CMUT from transfer.dat' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      expect(oddb_dat).to match(/^..2/), "should have a record with '2' in CMUT field"
      expect(oddb_dat).to match(/^..3/), "should have a record with '3' in CMUT field"
      expect(oddb_dat).to match(RegExpDesitin), "should have Desitin"
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line, 0) }
      # oddb_dat.should match(/^..1/), "should have a record with '1' in CMUT field" # we have no
    end
  end

  context 'when -f dat -I 80 is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse('-f dat -I 80')
      @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
    end

    it 'should report correct number of items' do
      expect(@res).to match(/products/)
    end

    it 'should contain the corect prices' do
      dat_filename = File.join(Oddb2xml::WorkDir, 'oddb.dat')
      expect(File.exists?(dat_filename)).to eq true
      oddb_dat = IO.read(dat_filename)
      oddb_dat_lines = IO.readlines(dat_filename)
      IO.readlines(dat_filename).each{ |line| check_article_IGM_format(line, 892, true) }
    end
  end
  context 'when utf-8 to iso-8859 fails' do
    it 'should return a correct 8859 line' do
      lines = IO.readlines(File.join(Oddb2xml::SpecData, 'problems.txt'))
      out = Oddb2xml.convert_to_8859_1(lines.first)
      expect(out.encoding.to_s).to eq 'ISO-8859-1'
      expect(out.chomp).to eq '<NAME_DE>SENSURA Mio 1t Uro 10-33 midi con lig so op 10 Stk</NAME_DE>'
    end
  end

end
