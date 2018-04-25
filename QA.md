# Fragen und Antworten zu oddb2xml

#### 1. Wann werden Medikamenten-Stammdaten aktualisiert, an welchem Tag im Monat?
* [Refdata](http://www.refdata.ch/content/article_d.aspx?Nid=6&Aid=909&ID=411) ändert täglich Pharmacodes.
* SL Preise werden am Anfang des Monats publiziert, jeweils immer am 1. Es kann auch vorkommen, dass das BAG die SL-Preise/Limitationen während dem Monat anpasst.
* Fachinfos werden täglich publiziert.
* Swissmedic-Codes erscheinen einmal pro Monat, normalerweise in der ersten Woche.
* Die Daten unter [MEDIupdate XML](https://www.hin.ch/services/mediupdate-xml/) werden täglich generiert.

#### 2. Haben Sie eine Spezifikation der XML Files? 
* Ja, siehe [oddb2xml.xsd](https://github.com/zdavatz/oddb2xml/blob/master/oddb2xml.xsd)

#### 3. Wo finde ich die Mehrwertsteuer?
* Der Mwst.-Code ist bei allen Produkten bei denen der GTIN mit 7680 (Medi in der SL) beginnt bei 2.5% (reduzierter Satz, Art. 49 MWSTV). 
* Siehe auch [ESTV](https://www.estv.admin.ch/estv/de/home/mehrwertsteuer/fachinformationen/steuersaetze/steuersaetze-bis-2017.html)
* Siehe auch VAT im [XSD](https://github.com/zdavatz/oddb2xml/blob/master/oddb2xml.xsd#L43) File.

#### 4. Was für eine Nummer findet man im Feld PRODNO?
* Die PRODNO setzen wir zusammen aus der 5-stelligen Swissmedic-Nummer und der Swissmedic Sequenz Nummer. Die Squenznummer unterscheidet nicht nach Packungsgrösse. Produkte mit der gleichen Dosierung und der gleichen galenischen Form aber einer unterschiedlicher Packungsgrösse, haben die gleiche PRODNO.
* Sequenznamen ohne Packungsgrösse aber mit Dosisstärke und galenischer Form findet man im [oddb2xml_swissmedic_sequences.csv](https://download.hin.ch/download/oddb2xml/oddb2xml_swissmedic_sequences.csv)
* Damit man _Registrations-_ und _Sequenznummer_ besser verstehen kann, muss man einmal das File [excel-version_zugelasseneverpackungen.xlsx](https://www.swissmedic.ch/dam/swissmedic/de/dokumente/listen/excel-version_zugelasseneverpackungen.xlsx.download.xlsx/excel-version_zugelasseneverpackungen.xlsx) öffnen und die ersten paar Spalten anschauen.

#### 5. Was ist der Unterschied zwischen oddb_article.xml und oddb_product.xml
* [oddb_article.xml](http://download.hin.ch/download/oddb2xml/oddb_article.xml) enhält alle Artikel. 
* [oddb_product.xml](http://download.hin.ch/download/oddb2xml/oddb_product.xml) enthält nur die Produkte von der Swissmedic, also die Medikamente.

#### 6. Warum hat nicht jedes Produkt im oddb_article.xml einen GTIN?
* Nicht alle Produkte haben zur Zeit einen GTIN. Dieser wird jedoch laufend ergänzt. Ab 1.1.2019 sollte der Pharmacode komplett verschwinden. Dies wurde von der Stiftung [Refdata](http://www.refdata.ch) auch so bestätigt.

#### 7. Wie kann ich Medikamente und Nicht-Medikament unterscheiden?
* Alle GTINs der Medikamente beginnen mit 7680 (76=Schweiz, 80=Swissmedic).
* Siehe [EANCode](http://www.ywesee.com/Main/EANCode)
* Medikamente haben zudem auch eine [Swissmedic Kategorie](https://github.com/zdavatz/oddb2xml/blob/master/oddb2xml.xsd#L78).

#### 8. Ich möchte gerne ein XML-File welches alle Produkte (Pharma und Non-Pharma) und die dazugehörigen Sequenznamen enthält. Gibt es das?
* Ja! Einfach _oddb2xml_ mit der Option _-r_ laufen lassen, siehe [usage](https://github.com/zdavatz/oddb2xml#usage) - Option "_--artikelstamm_".
* Dieses File wird zur Zeit nicht via [MEDIupdate XML](https://www.hin.ch/services/mediupdate-xml/) zum Download zur Verfügung gestellt. Es muss selber generiert werden mittels _oddb2xml -r_.

#### 9. Wie installiere ich _oddb2xml_?
* Ruby installieren.
* _gem install oddb2xml_ ausführen und Installation abwarten. Sollte auch auf Windows mit Ubuntu Bash funktionieren. Mindestens 8 GB RAM notwending.
* _oddb2xml_ mit der entsprechenden Option laufen lassen, z.B. _oddb2xml -r_
