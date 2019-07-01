# oddb2xml

[![Build Status](https://secure.travis-ci.org/zdavatz/oddb2xml.png)](http://travis-ci.org/zdavatz/oddb2xml)

* oddb2xml -a nonpharma -o fi

creates the following xml files:

* oddb_substance.xml
* oddb_limitation.xml
* oddb_interaction.xml
* oddb_code.xml
* oddb_product.xml
* oddb_article.xml
* oddb_fi.xml
* oddb_fi_product.xml

and

* oddb2xml -f dat
* oddb2xml -f dat -a nonpharma

creates .dat files according to ([IGM-11](http://dev.ywesee.com/uploads/att/IGM.pdf)). IGM-11 describes the structure of the zurrose_transfer.dat.

* oddb.dat
* oddb_with_migel.dat

the files are using [swissINDEX](http://www.refdata.ch/downloads/company/download/swissindex_TechnischeBeschreibung.pdf), [BAG-XML](http://bag.e-mediat.net/SL2007.Web.External/Default.aspx?webgrab=ignore) and [Swissmedic](http://www.swissmedic.ch/daten/00080/00251/index.html?lang=de) as sources.

The following additional data is in the files:

* [Wirkstoffe](http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip) (BAG XML)
* [Kühlkette](http://www.swissmedic.ch/daten/00080/00254/index.html?lang=de&download=NHzLpZeg7t,lnp6I0NTU042l2Z6ln1acy4Zn4Z2qZpnO2Yuq2Z6gpJCDdH57e2ym162epYbg2c_JjKbNoKOn6A--) (Swissmedic)
* [Orphan Drugs](http://www.swissmedic.ch/daten/00081/index.html?lang=de&download=NHzLpZeg7t,lnp6I0NTU042l2Z6ln1acy4Zn4Z2qZpnO2Yuq2Z6gpJCDdH55f2ym162epYbg2c_JjKbNoKSn6A--&.xls) (Swissmedic)
* [FI: de, fr](http://download.swissmedicinfo.ch) (Swissmedic)
* Limitation-Texte (BAG XML)
* Interaktionen [EPha.ch](http://epha.ch)
* [Betäubungsmittel](http://www.swissmedic.ch/produktbereiche/00447/00536/index.html?lang=de&download=NHzLpZeg7t,lnp6I0NTU042l2Z6ln1acy4Zn4Z2qZpnO2Yuq2Z6gpJCDdH1,fWym162epYbg2c_JjKbNoKSn6A--&.pdf) und psychotrope Stoffe (Swissmedic)
* Non-Pharma from Refdata and Suppliers (swissINDEX)

The top elements of all XML files have a SHA256 attribute over their content. The content corresponds to Nokogiris text method of the node which is essentially join by "\n" + some whitespaces of each element.
Consumers of the data file may use it to check whether they have to replace the corresponding nodes.

Generating files for Elexis Artikelstamm is discussed in the [Readme for the Artikelstamm](artikelstamm.md)


## usage

HIN (http://hin.ch) creates daily the actual file. They can be downloaded from `https://download.hin.ch/download/oddb2xml`, e.g. using  `wget https://download.hin.ch/download/oddb2xml/oddb_article.xml`

see `--help`.

```
    /opt/src/oddb2xml_v5/bin/oddb2xml version 2.4.3
    Usage:
    oddb2xml [option]
      produced files are found under data
    -a, --append              Additional target nonpharma
    -r, --artikelstamm        Create Artikelstamm Version 3 and 5 for Elexis >= 3.1
    -c, --compress-ext=<s>    format F. {tar.gz|zip}
    -e, --extended            pharma, non-pharma plus prices and non-pharma from zurrose.
                                                          Products without EAN-Code will also be listed.
                                                          File oddb_calc.xml will also be generated
    -f, --format=<s>          File format F, default is xml. {xml|dat}
                                                          If F is given, -o option is ignored. (Default: xml)
    -i, --include             Include target option for ean14  for 'dat' format.
                                                          'xml' format includes always ean14 records.
    -I, --increment=<i>       Increment price by x percent. Forces -f dat -p zurrose.
                                                          create additional field price_resellerpub as
                                                          price_extfactory incremented by x percent (rounded to the next 0.05 francs)
                                                          in oddb_article.xml. In generated zurrose_transfer.dat PRPU is set to this price
                                                          Forces -f dat -p zurrose.
    -o, --fi                  Optional fachinfo output.
    -p, --price               Price source (transfer.dat) from ZurRose
    -t, --tag-suffix=<s>      XML tag suffix S. Default is none. [A-z0-9]
                                                          If S is given, it is also used as prefix of filename.
    -x, --context=<s>         {product|address}. product is default. (Default: product)
    -l, --calc                create only oddb_calc.xml with GTIN, name and galenic information
    -s, --skip-download       skips downloading files it the file is already under downloads.
                                                          Downloaded files are saved under downloads
    --log                     log important actions
    -u, --use-ra11zip=<s>     Use the ra11.zip (a zipped transfer.dat from Galexis)
    -v, --version             Print version and exit
    -h, --help                Show this message
```

## Option examples

```
$ oddb2xml -t md                        # => md_article.xml, md_product.xml, md_substance.xml
$ oddb2xml -a nonpharma -t md -c tar.gz # => md_xml_dd.mm.yyyy_hh.mm.tar.gz
$ oddb2xml -f dat                       # => oddb.dat
$ oddb2xml -f dat -a nonpharma          # => oddb_with_migel.dat
$ oddb2xml -e                           # => oddb_article.xml
```

output.

```
$ oddb2xml
DE
        Pharma products: 14801
FR
        Pharma products: 14801
```

## Supported ruby version

We run tests on travis-ci.org for the Ruby versions mentioned in the .travis.yml file. You will need ruby > 2.4 to work correctly.
Ruby 2.2/2.3 have problems with i18n encoding and fail a spec test for Naropin


## XSD files

The file oddb2xml.xsd was manually created by merging the output of the xmlbeans tools inst2xsd and trang

* http://xmlbeans.apache.org/docs/2.0.0/guide/tools.html#inst2xsd
* http://www.thaiopensource.com/relaxng/trang.html

Running rake spec will validated the XML-files generated during the tests using the Nokogiri validator.
We have two XSD files. One for oddb_calc.xml and one for the rest.

Manually you can also validate (assuming that you have installed the xmlbeans tools) all generated XML-files using

* xsdvalidate oddb_calc.xsd oddb_article.xml oddb_calc.xml
* xsdvalidate oddb2xml.xsd oddb_article.xml oddb_code.xml oddb_interaction.xml oddb_product.xml oddb_substance.xml

## XML files

xml files generated are:

* oddb_substance.xml
* oddb_limitation.xml
* oddb_interaction.xml
* oddb_code.xml
* oddb_product.xml
* oddb_article.xml
* oddb_fi.xml
* oddb_fi_product.xml

### article.xml

oddb2xml creates article.xml as oddb_article.xml by default.

```
<?xml version="1.0" encoding="utf-8"?>
<ARTICLE xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration" CREATION_DATETIME="2015-09-09T09:50:28+0000" PROD_DATE="2015-09-09T09:50:28+0000" VALID_DATE="2015-09-09T09:50:28+0000">
  <ART DT="2015-09-09 00:00:00 +0000" SHA256="896dd24bfb4cfd56dcfd3709150da9b652626a430adefbe57cb405a9d46684c6">
    <REF_DATA>1</REF_DATA>
    <PHAR>2731179</PHAR>
    <SMCAT>D</SMCAT>
    <SMNO>16105058</SMNO>
    <PRODNO>161051</PRODNO>
    <VAT>2</VAT>
    <SALECD>A</SALECD>
    <CDBG>N</CDBG>
    <BG>N</BG>
    <DSCRD>HIRUDOID Creme 3 mg/g 40 g</DSCRD>
    <DSCRF>HIRUDOID crème 3 mg/g 40 g</DSCRF>
    <SORTD>HIRUDOID CREME 3 MG/G 40 G</SORTD>
    <SORTF>HIRUDOID CRèME 3 MG/G 40 G</SORTF>
    <SYN1D>Hirudoid</SYN1D>
    <SYN1F>Hirudoid</SYN1F>
    <SLOPLUS>2</SLOPLUS>
    <ARTCOMP>
      <COMPNO>7601001002258</COMPNO>
    </ARTCOMP>
    <ARTBAR>
      <CDTYP>E13</CDTYP>
      <BC>7680161050583</BC>
      <BCSTAT>A</BCSTAT>
    </ARTBAR>
    <ARTPRI>
      <PTYP>PEXF</PTYP>
      <PRICE>4.768575</PRICE>
    </ARTPRI>
    <ARTPRI>
      <PTYP>PPUB</PTYP>
      <PRICE>8.8</PRICE>
    </ARTPRI>
    <ARTPRI>
      <PTYP>ZURROSE</PTYP>
      <PRICE>4.77</PRICE>
    </ARTPRI>
    <ARTPRI>
      <PTYP>ZURROSEPUB</PTYP>
      <PRICE>8.80</PRICE>
    </ARTPRI>
    <ARTINS>
      <NINCD>10</NINCD>
    </ARTINS>
  </ART>
  ...
  <RESULT>
    <OK_ERROR>OK</OK_ERROR>
    <NBR_RECORD>14801</NBR_RECORD>
    <ERROR_CODE/>
    <MESSAGE/>
  </RESULT>
</ARTICLE>
```

### product.xml

For example, if `-t _swiss` is given then oddb2xml creates product.xml as swiss_product.xml.

```
<?xml version="1.0" encoding="utf-8"?>
<PRODUCT_SWISS xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration" CREATION_DATETIME="2012-11-21T13:01:29.5903756+0900" PROD_DATE="2012-11-21T13:01:29.5903756+0900" VALID_DATE="2012-11-21T13:01:29.5903756+0900">
  <PRD_SWISS DT="" SHA256="aa82eee2d542787cf2cb8b7f17d748223ec723b935ce20cd29d89e284d16fea1">
    <GTIN>7680353660163</GTIN>
    <PRODNO>353661</PRODNO>
    <DSCRD>KENDURAL Depottabl 30 Stk</DSCRD>
    <DSCRF>KENDURAL cpr dépot 30 pce</DSCRF>
    <ATC>B03AE10</ATC>
    <IT>06.07.1.</IT>
    <CPT>
      <CPTCMP>
        <LINE>0</LINE>
        <SUBNO>5</SUBNO>
        <QTY>105</QTY>
        <QTYU>mg</QTYU>
      </CPTCMP>
      <CPTCMP>
        <LINE>1</LINE>
        <SUBNO>1</SUBNO>
        <QTY>500</QTY>
        <QTYU>mg</QTYU>
      </CPTCMP>
    </CPT>
    <PackGrSwissmedic>30</PackGrSwissmedic>
    <EinheitSwissmedic>Tablette(n)</EinheitSwissmedic>
    <SubstanceSwissmedic>ferrum(II), acidum ascorbicum</SubstanceSwissmedic>
    <CompositionSwissmedic>ferrum(II) 105 mg ut ferrosi sulfas dessiccatus, acidum ascorbicum 500 mg ut natrii ascorbas, color.: E 124, excipiens pro compresso obducto.</CompositionSwissmedic>
  </PRD>
  ...
  <RESULT_SWISS>
    <OK_ERROR_SWISS>OK</OK_ERROR_SWISS>
    <NBR_RECORD_SWISS>14336</NBR_RECORD_SWISS>
    <ERROR_CODE_SWISS/>
    <MESSAGE_SWISS/>
  </RESULT_SWISS>
</PRODUCT_SWISS>
```

### substance.xml

product.xml has relation to substance as `<SUBNO>`.

```
<?xml version="1.0" encoding="utf-8"?>
<SUBSTANCE xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration" CREATION_DATETIME="2012-12-11T14:27:17.4444763+0900" PROD_DATE="2012-12-11T14:27:17.4444763+0900" VALID_DATE="2012-12-11T14:27:17.4444763+0900">
  <SB DT="" SHA256="a510f9b1e7216cda2d5e0c3b82bacef96da963e14f36c97e0e1a8baf55d00287">
    <SUBNO>1</SUBNO>
    <NAML>Acidum ascorbicum (Vitamin C, E300)</NAML>
  </SB>
  <SB DT="" SHA256="de64fcc718b7f30bfe4283fb40c8b558cf2f30a8acc4a7bf6a643e82dfe82931">
    <SUBNO>2</SUBNO>
    <NAML>Alprostadilum</NAML>
  </SB>
  ...
  <RESULT>
    <OK_ERROR>OK</OK_ERROR>
    <NBR_RECORD>1441</NBR_RECORD>
    <ERROR_CODE/>
    <MESSAGE/>
  </RESULT>
</SUBSTANCE>
```

## Data sources

We use the following files:

* https://www.swissmedic.ch/arzneimittel/00156/00221/00222/00230/index.html?lang=de (Präparateliste und zugelassene Packungen)
* https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/interactions_de_utf8.csv
* http://refdatabase.refdata.ch/Service/Article.asmx
* http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip
* https://www.medregbm.admin.ch/Publikation/CreateExcelListBetriebs
* https://www.medregbm.admin.ch/Publikation/CreateExcelListMedizinalPersons
* http://zurrose.com/fileadmin/main/lib/download.php?file=/fileadmin/user_upload/downloads/ProduktUpdate/IGM11_mit_MwSt/Vollstamm/transfer.dat
* https://index.ws.e-mediat.net/Swissindex/NonPharma/ws_NonPharma_V101.asmx
* https://index.ws.e-mediat.net/Swissindex/NonPharma/ws_Pharma_V101.asmx
* http://download.swissmedicinfo.ch/ (AipsDownload)
* https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/LPPV.txt
* https://raw.githubusercontent.com/epha/robot/master/data/manual/swissmedic/atc.csv

## Rules for matching GTIN (aka EAN13), product number and IKSNR

For drugs which appear in Packungen.xlsx file published by Swissmedic the following rule is used to create the GTIN
* First 4 digits identify SwissMedic and are fixed to 7680
* next 5 digits corresponding to IKSNR (authorization) number
* next 3 digits corresponding to Packungscode
* last digit is checksum

The product number is calculated as
* 5 digits corresponding to IKSNR (authorization) number
* 2 digits corresponding to Dosisstärke (aka sequence number)

In oddb_article.xml you find
* GTIN is found as "BC" inside "ARTBAR"
* The product number as field PRODNO

Example given. For the IKSNR 48305 sequence number 1 named "Felden, Gel" with Packungscode "024" we get GTIN 7680483050247 and a product number 483051.


## SSLv3 cert for Windows Users

Some websites need SSLv3 connection.
If you don't have these root CA files (x509), Please install these Certificates before running.  
see [cURL Website](http://curl.haxx.se/ca/)

You can confirm wit `ruby -ropenssl -e 'p OpenSSL::X509::DEFAULT_CERT_FILE'`.

### Windows User: Making your SSL Certificate permanent via your PATH

1. Download this [cacert.pem](http://curl.haxx.se/ca/cacert.pem) (cURL) into your HOME directory.
 * or directly select cacert.pem from your oddb2xml-x.x.x gems directory.
 * tools/cacert.pem is bundled with the oddb2xml gem.
2. Then Choose Menu "Control Panel" > "System" > "Advanced system settings"
 * This opens the "System Properties" Window.
3. Click "Advanced" Tab.
4. Click "Environment Variables" button.
5. Add set variable entry "SSL\_CERT\_FILE=%HOMEPATH%\cacert.pem"
  * Variable name: SSL\_CERT\_FILE
  * Variable value: %HOMEPATH%\cacert.pem
  * with "New..." button into upper are "User variables for xxx"
6. Do not remove this cacert.pem. All SSLv3 connections use this file.

### win_fetch_cacerts.rb
You can also run

* tools/win_fetch_cacerts.rb

for your currently open Terminal to download and set the Certificate.


## Testing

* Calling rake spec runs spec tests.
* Calling rake test installs the gems and runs oddb2xml with the most commonly used combinations. All output is placed under under ausgabe/<timestamp>. These files should be manually compared to the ones generated by the last release to check for possible problems.
* we use the gem VCR to record real HTTP responses.
** Removing the directory fixtures and running @bundle exec rspec spec/downloader_spec.rb@ gets the actual content from the different servers
** To minimize the downloaded size we use several @before_record@ hooks to select the desired content, eg. only the 5 items from EPha.

