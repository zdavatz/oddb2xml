# Artikelstamm Readme

odd2xml unterstützt seit Ende 2017 den von Elexis gebrauchten Artikelstamm wie folgt:

* Mit der Option --artikelstamm werden ArtikelstammDaten in der Version 3 und 5 erzeugt
* compare_v5 erlaubt es, zwei v5 (oder v3) XML-Dateien zu vergleichen

## Herkunft der Artikelstamm Daten

Die für den Artikelstamm gebrauchten Ursprungs-Dateien werden 

* Unter downloads in einem leicht lesbaren Format abgespeichert. 
* Dazu wird die Utility ssconvert des Gnumeric verwendet, was viel schneller geht, als die Dateien per Ruby-Script zu laden.
* Mit _xmllint --format_ können die XML Daten schön formatiert werden.
* _transfer.utf8 ISO8859-1 transfer.dat_ als utf-8 um leichter unter Linux greppen zu können

Damit ist möglich nach einem Durchlauf den Ursprung der Daten zu ermitteln, z.B. `grep -r 7680273040281 downloads` git dann folgende Zeilen zurück

    downloads/transfer.dat:1120098878HALDOL Tabl 1 mg 50 Stk                           000278000660100B010500076802730402812
    downloads/transfer.utf8:1120098878HALDOL Tabl 1 mg 50 Stk                           000278000660100B010500076802730402812
    downloads/Preparations.xml:        <GTIN>7680273040281</GTIN>
    downloads/refdata_Pharma.xml:        <GTIN>7680273040281</GTIN>

Oder

    > grep -ri FERRO-GRADUMET downloads
    downloads/transfer.dat:1120020244FERRO-GRADUMET Depottabl 30 Stk                   000896001380300C060710076803164401152
    downloads/transfer.dat:1121245933FERRO-GRADUMET Depottabl 90 Stk                   002296003540300C060710076803164403822
    downloads/swissmedic_package.csv:31644,2,"Ferro-Gradumet, compresse a rilascio prolungato","FARMACEUTICA TEOFARMA SUISSE SA","Synthetika human",06.07.1.,B03AA07,1967/06/22,1994/03/28,2022/02/15,11,30,Tablette(n),C,C,C,ferrum(II),"ferrum(II) 105 mg ut ferrosi sulfas dessiccatus, arom.: saccharinum natricum, color.: E 127, excipiens pro compresso.","Anemia da carenza di ferro con carenza di ferro accertata",,,,
    downloads/swissmedic_package.csv:31644,2,"Ferro-Gradumet, compresse a rilascio prolungato","FARMACEUTICA TEOFARMA SUISSE SA","Synthetika human",06.07.1.,B03AA07,1967/06/22,1994/03/28,2022/02/15,38,90,Tablette(n),C,C,C,ferrum(II),"ferrum(II) 105 mg ut ferrosi sulfas dessiccatus, arom.: saccharinum natricum, color.: E 127, excipiens pro compresso.","Anemia da carenza di ferro con carenza di ferro accertata",,,,
    downloads/refdata_Pharma.xml:        <NAME_DE>FERRO-GRADUMET Depottabl 30 Stk</NAME_DE>
    downloads/refdata_Pharma.xml:        <NAME_FR>FERRO-GRADUMET cpr dépôt 30 pce</NAME_FR>
    downloads/refdata_Pharma.xml:        <NAME_DE>FERRO-GRADUMET Depottabl 90 Stk</NAME_DE>
    downloads/refdata_Pharma.xml:        <NAME_FR>FERRO-GRADUMET cpr dépôt 90 pce</NAME_FR>

### Herkunft der einzelenen Dateien

* Siehe: https://github.com/zdavatz/oddb2xml/blob/master/README.md#data-sources

Beim Transfer.dat werden Zeilen ausgelassen, wenn eine der folgenden Bedingungen zutrifft (siehe extractor.rb ZurroseExtractor)

    * Die GTIN ist 0000000000000
    * Die Zeile beginnt mit 113 (inaktiv) und die GTIN beginnt mit 7680 (aka Swissmedic)
    * Die Zeile beginnt mit 113 (inaktiv) und sowohl der Public als auch der Extfactory Preis is 0

### GTIN

GTIN may be  8, 12, 13 or 14 chars long (https://en.wikipedia.org/wiki/Global_Trade_Item_Number)

The EAN-8 code is an eight-digit barcode used usually for very small articles, such as a battery for hearing aid, where fitting a larger code onto the item would be difficult

You may test GTIN via the  GS1 information GEPIR for Switzerland, eg www.gepir.ch or globally http://gepir.gs1.org/

Drugs registered in Switzerland have GTINs starting with 7680 (which is reserved by Swissmedic)


## UnitTests

Dafür werden Ruby RSpec tests verwendet. Die Testabdeckung ist gut.

Im der Datei spec/spec_helper.rb findet man die Methode mock_downloads, welche mocks für die zu holenden Dateien (werden via ruby open-uri geöffnet) definiert. Als Ursprung werden die unter spec/data abgelegten Dateien (teilweiche auch beim Testlauf in Zip-Dateien umgewandelt) verwendet. Damit ist auf eine einfache Art möglich, neue Testfälle in die XML/XLSX-Dateien einzufügen. Vor 2017 wurde das Ruby-Gem vcr dazu verwendet, was jedoch einen zu hohen Wartungsbedarf mit sich brachte

## Entstehungsgeschichte

Bis Ende 2017 wurde
* via oddb2xml die Dateien oddb_article.xml und oddb_product.xml generiert
* mit einen AdHoc geschriebElexisenen Tool von Marco Descher in das Artikelstamm Format (in Versionen 1,2,3,4) umgewandelt
* dann von Elexis eingelesen

2017 erweiterte https://github.com/ngiger/ oddb2xml auf die Bedürfnisse von Elexis und dessen Artikelstammanforderungen, um für die neue Version 5 die Dateien direkt via oddb2xml zu erstellen.

Dazu kam auch das Werkzeug compare_v5 um zwei v5 XML-Dateien zu vergleichen, womit die pro Monat neu eintreffenden Anpassungen leicht verfolgbar werden.
