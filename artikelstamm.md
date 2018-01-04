# Artikelstamm Readme

odd2xml unterstützt seit Ende 2017 den von Elexis gebrauchten Artikelstamm wie folgt:

* Mit der Option --artikelstamm werden ArtikelstammDaten in der Version 3 und 5 erzeugt
* compare_v5 erlaubt es, zwei v5 (oder v3) XML-Dateien zu vergleichen

## Herkunft der Artikelstamm Daten

Die für den Artikelstamm gebrauchten Ursprungs-Dateien werden 

* unter downloads in einem leicht lesbaren Format abgespeichert 
** CSV für XLSX-Dateien. Dazu wird die Utility ssconvert des Gnumeric verwendet, was viel schneller geht, als die Dateien per Ruby-Script zu laden
** mit xmllint --format schön formattierten XML 

### Herkunft der einzelenen Dateien

* epha_interactions.csv   https://download.epha.ch/cleaned/matrix.csv'
* swissmedic_orphan.csv   https://www.swissmedic.ch/dam/swissmedic/de/dokumente/listen/humanarzneimittel.orphan.xlsx.download.xlsx/humanarzneimittel.xlsx'
* swissmedic_package.csv  https://www.swissmedic.ch/dam/swissmedic/de/dokumente/listen/excel-version_zugelasseneverpackungen.xlsx.download.xlsx/excel-version_zugelasseneverpackungen.xlsx
* oddb2xml_files_lppv.txt https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/LPPV.txt
* XMLPublications.zip     http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip   Dieses enthält
** Preparations.xml
* transfer.zip            http://pillbox.oddb.org/TRANSFER.ZIP Dieses enthält
** transfer.dat

## UnitTests

Dafür werden Ruby RSpec tests verwendet. Die Testabdeckung ist gut.

Im der Datei spec/spec_helper.rb findet man die Methode mock_downloads, welche mocks für die zu holenden Dateien (werden via ruby open-uri geöffnet) definiert. Als Ursprung werden die unter spec/data abgelegten Dateien (teilweiche auch beim Testlauf in Zip-Dateien umgewandelt) verwendet. Damit ist auf eine einfache Art möglich, neue Testfälle in die XML/XLSX-Dateien einzufügen. Vor 2017 wurde das Ruby-Gem vcr dazu verwendet, was jedoch einen zu hohen Wartungsbedarf mit sich brachte

## Entstehungsgeschichte

Elexis braucht seit der Version 3.0 vom August 2014 eine XML-Datei mit den Stammdaten für Artikel.

Bis Ende 2017 wurde
* via oddb2xml die Dateien oddb_article.xml und oddb_product.xml generiert
* mit einen AdHoc geschriebenen Tool von Marco Descher in das Artikelstamm Format (in Versionen 1,2,3,4) umgewandelt
* dann von Elexis eingelesen

2017 investierte Niklaus Giger über 60 Arbeitsstunden, um für die neue Version 5 die Dateien direkt via oddb2xml zu erstellen.

Bei dieser Ueberarbeitung wurden dann auch noch gleichzeitig eine Version 3 erstellt.

Dazu kam auch das Werkzeug compare_v5 um zwei v5 (oder v3) XML-Dateien zu vergleichen, womit die pro Monat neu eintreffenden Anpassungen leicht vervolgbar werden.
