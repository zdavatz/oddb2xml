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

creates .dat files according to ([IGM-11](http://dev.ywesee.com/uploads/att/IGM.pdf))

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

## usage

see `--help`.

```
/usr/local/bin/oddb2xml ver.1.7.8
Usage:
  oddb2xml [option]
    produced files are found under data
    -a T, --append=T     Additional target. T, only 'nonpharma' is available.
    -c F, --compress=F   Compress format F. {tar.gz|zip}
    -e    --extended     pharma, non-pharma plus prices and non-pharma from zurrose. Products without EAN-Code will also be listed.
    -f F, --format=F     File format F, default is xml. {xml|dat}
                         If F is given, -o option is ignored.
    -i I, --include=I    Include target option for 'dat' format. only 'ean14' is available.
                         'xml' format includes always ean14 records.
    -o O, --option=O     Optional output. O, only 'fi' is available.
    -p P, --price=P      Price source (transfer.dat). P, only 'zurrose' is available.
    -t S, --tag-suffix=S XML tag suffix S. Default is none. [A-z0-9]
                         If S is given, it is also used as prefix of filename.
    -x N, --context=N    context N {product|address}. product is default.
                         
                         For debugging purposes
    --skip-download      skips downloading files it the file is already under data/downloads.
                         Downloaded files are saved under data/downloads
    -h,   --help         Show this help message.

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

## XSD files
If you need the XSD files, generate them yourself using the javabeans tool:

* http://xmlbeans.apache.org/docs/2.0.0/guide/tools.html#inst2xsd

this will generate you a valid XSD file that can be used to validate against the XML file.

i.e.:
* /home/zeno/.software/xmlbeans-2.6.0/bin/inst2xsd oddb_article.xml -outPrefix oddb_article

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
<ARTICLE xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://wiki.oddb.org/wiki.php?pagename=Swissmedic.Datendeklaration" CREATION_DATETIME="2012-11-21T13:09:23.6787110+0900" PROD_DATE="2012-11-21T13:09:23.6787110+0900" VALID_DATE="2012-11-21T13:09:23.6787110+0900">
  <ART DT="">
    <PHAR>31532</PHAR>
    <PRDNO>4123</PRDNO>
    <SMCAT>D</SMCAT>
    <SMNO>29152039</SMNO>
    <SALECD>A</SALECD>
    <QTY>10 Stk</QTY>
    <DSCRD>BEN-U-RON Supp 250 mg Kind</DSCRD>
    <DSCRF>BEN-U-RON supp 250 mg enf</DSCRF>
    <SORTD>BEN-U-RON SUPP 250 MG KIND</SORTD>
    <SORTF>BEN-U-RON SUPP 250 MG ENF</SORTF>
    <SYN1D>Ben-u-ron</SYN1D>
    <SYN1F>Ben-u-ron</SYN1F>
    <SLOPLUS>2</SLOPLUS>
    <ARTCOMP/>
    <ARTBAR>
      <CDTYP>E13</CDTYP>
      <BC>7680291520390</BC>
      <BCSTAT>A</BCSTAT>
    </ARTBAR>
    <ARTPRI>
      <VDAT>01.11.2012</VDAT>
      <PTYP>PEXF</PTYP>
      <PRICE>1.780086</PRICE>
    </ARTPRI>
    <ARTPRI>
      <VDAT>01.11.2012</VDAT>
      <PTYP>PPUB</PTYP>
      <PRICE>3.3</PRICE>
    </ARTPRI>
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
  <PRD_SWISS DT="">
    <GTIN_SWISS>7680353660163</GTIN_SWISS>
    <PRODNO_SWISS>353661</PRODNO_SWISS>
    <DSCRD_SWISS>Kendural Depottabl </DSCRD_SWISS>
    <DSCRF_SWISS>Kendural cpr dépôt </DSCRF_SWISS>
    <ATC_SWISS>B03AE10</ATC_SWISS>
    <IT_SWISS>06.07.1.</IT_SWISS>
    <CPT_SWISS>
      <CPTCMP_SWISS>
        <LINE_SWISS>0</LINE_SWISS>
        <SUBNO_SWISS>507</SUBNO_SWISS>
        <QTY_SWISS>105</QTY_SWISS>
        <QTYU_SWISS>mg</QTYU_SWISS>
      </CPTCMP_SWISS>
      <CPTCMP_SWISS>
        <LINE_SWISS>1</LINE_SWISS>
        <SUBNO_SWISS>23</SUBNO_SWISS>
        <QTY_SWISS>500</QTY_SWISS>
        <QTYU_SWISS>mg</QTYU_SWISS>
      </CPTCMP_SWISS>
    </CPT_SWISS>
    <PackGrSwissmedic_SWISS>30</PackGrSwissmedic_SWISS>
    <EinheitSwissmedic_SWISS>Tablette(n)</EinheitSwissmedic_SWISS>
    <SubstanceSwissmedic_SWISS>ferrum(II), acidum ascorbicum</SubstanceSwissmedic_SWISS>
  </PRD_SWISS>
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
  <SB DT="">
    <SUBNO>1</SUBNO>
    <NAML>3-Methoxy-butylis acetas</NAML>
  </SB>
  <SB DT="">
    <SUBNO>2</SUBNO>
    <NAML>4-Methylbenzylidene camphor</NAML>
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
