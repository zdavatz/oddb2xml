# Fragen und Antworten zu oddb2xml

#### 1. Wann werden Medikamenten-Stammdaten aktualisiert, an welchem tag im Monat?
* Refdata ändert täglich Pharmacodes.
* SL Preise werden am Anfang des Monats publiziert, jeweils immer am 1. Ganz selten auch am 15.
* Fachinfos werden täglich publiziert.
* Swissmedic-Codes erscheinen einmal pro Monat, normalerweise in der ersten Woche.

Wer will kann oddb2xml einmal pro Tag laufen lassen für die neusten Pharmacodes.

#### 2. Haben Sie eine Spezifikation der XML Files? 
* Ja, siehe: https://github.com/zdavatz/oddb2xml/blob/master/oddb2xml.xsd

#### 3. Wo finde ich die Mehrwertsteuer?
* Der Mwst.-Code ist bei allen Produkten bei denen der GTIN mit 7680 (Medi in der SL) beginnt bei 2.5% (reduzierter Satz, Art. 49 MWSTV). 
* Siehe auch: http://www.estv.admin.ch/mwst/themen/00155/#sprungmarke0_4

#### 4. Was für eine Nummer findet man im Feld PRODNO?
* Mit dem Release 1.4.8 finden Sie auch die PRODNO im XML. Die PRODNO setzen wir zusammen aus der 5-stelligen Swissmedic-Nummer und der Swissmedic Sequenz Nummer. Die Squenznummer unterscheidet nicht nach Packungsgrösse. Produkte mit der gleichen Dosierung und der gleichen galenischen Form aber einer unterschiedlicher Packungsgrösse, haben die gleiche PRODNO.

#### 5. Was ist der Unterschied zwischen oddb_article.xml und oddb_product.xml
* oddb_article.xml enhält alle Artikel. oddb_product.xml enthält nur die Produkte von der Swissmedic, also die Medikamente.

#### 6. Warum hat nicht jedes Produkt im oddb_article.xml einen GTIN?
* Nicht alle Produkte haben zur Zeit einen GTIN. Dieser wird jedoch laufend ergänzt. Ab 1.1.2019 sollte der Pharmacode komplett verschwinden.

#### 7. Wie kann ich Medikamente und Nicht-Medikament unterscheiden?
* Alle GTINs der Medikamente beginnen mit 7680 (76=Schweiz, 80=Swissmedic).
