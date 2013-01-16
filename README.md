# oddb2xml

oddb2xml, creates xml files using swissINDEX, BAG-XML and Swissmedic.

The following additional data is in the files:

* Wirkstoffe
* Kühlkette (gemäss Swissmedic)
* Orphan Drugs (gemäss Swissmedic)
* FI (de und fr)
* Limitation-Texte (gemäss BAG XML)
* Interaktionen (EPha.ch)
* Betäubungsmittel und psychotrope Stoffe (gemäss Swissmedic)
* Non-Pharma from Refdata and Suppliers

## usage

see `--help`.

```
$ oddb2xml --help
oddb2xml ver.1.0.7
Usage:
  oddb2xml [option]
    -c F, --compress=F   Compress format F. {tar.gz|zip}
    -a T, --append=T     Additional target. T, only 'nonpharma' is available.
    -t S, --tag-suffix=S XML tag suffix S. Default is none. [A-z0-9_]
                         If S is given, it is also used as prefix of filename.
    -h,   --help         Show this help message.
```


## example

option examples.

```
$ oddb2xml                              # => oddb_article.xml, oddb_product.xml, oddb_substance.xml
$ oddb2xml -t md                        # => md_article.xml, md_product.xml, md_substance.xml
$ oddb2xml -a nonpharma -t md -c tar.gz # => md_xml_dd.mm.yyyy_hh.mm.tar.gz
```

output.

```
$ oddb2xml
DE
        Pharma products: 14801
FR
        Pharma products: 14801
```

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
    <PRDNO_SWISS>1167149</PRDNO_SWISS>
    <DSCRD_SWISS>Allergovit Artemisia Inj Susp Kombi</DSCRD_SWISS>
    <DSCRF_SWISS>Allergovit Artemisia susp inj combi </DSCRF_SWISS>
    <ATC_SWISS>V01AA10</ATC_SWISS>
    <IT_SWISS>07.13.30.</IT_SWISS>
    <CPT_SWISS>
      <CPTCMP_SWISS>
        <LINE_SWISS>0</LINE_SWISS>
        <SUBNO_SWISS>100</SUBNO_SWISS>
        <QTY_SWISS>1000</QTY_SWISS>
        <QTYU_SWISS>U.</QTYU_SWISS>
      </CPTCMP_SWISS>
      <CPTCMP_SWISS>
        <LINE_SWISS>1</LINE_SWISS>
        <SUBNO_SWISS>105</SUBNO_SWISS>
        <QTY_SWISS>10000</QTY_SWISS>
        <QTYU_SWISS>U.</QTYU_SWISS>
      </CPTCMP_SWISS>
    </CPT_SWISS>
  </PRD_SWISS>
  ...
  <RESULT_SWISS>
    <OK_ERROR_SWISS>OK</OK_ERROR_SWISS>
    <NBR_RECORD_SWISS>5850</NBR_RECORD_SWISS>
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
## For Windows Users: You have to save the Certificate file permanently
1. Control Panel > System > Advanced system settings (Das öffnet "System Properties" Window.)
2. Click "Advanced" Tab.
3. Click "Environment Variables" Button.
4. User kann einfach die Umgebungsvariable "SSL_CERT_FILE=C:\Ruby193\lib\ruby\gems\1.9.1\gems\oddb2xml-x.x.x\cacert.pem setzen.
