#!/usr/bin/env bash
#
# Generate the mediupdatexml.oddb.org landing page ($DOCROOT/index.html) with
# live product counts:
#   PHARMA    = Swissmedic-registered medicines (<SMNO> in default/oddb_article.xml)
#   NONPHARMA = GTINs in the GS1 firstbase download (firstbase.csv, minus header)
#
# Usage: generate_index_html.sh DOCROOT [FIRSTBASE_CSV]
#   DOCROOT        where to write index.html (default /home/zdavatz/oddb2xml)
#   FIRSTBASE_CSV  the GS1 firstbase CSV (default <DOCROOT>-build/downloads/firstbase.csv)
#
# Called from run_oddb2xml.sh (after each build) and from
# setup_mediupdatexml_web.sh (initial creation). Counts that can't be computed
# are shown as "—".

set -euo pipefail

DOCROOT="${1:-/home/zdavatz/oddb2xml}"
FIRSTBASE_CSV="${2:-${DOCROOT%/}-build/downloads/firstbase.csv}"
ARTICLE_XML="${DOCROOT%/}/default/oddb_article.xml"

# Swiss-style thousands separator (192807 -> 192'807); "—" passes through.
group() { [[ "$1" =~ ^[0-9]+$ ]] && printf "%s" "$1" | sed -re ":a;s/([0-9])([0-9]{3})($|[^0-9])/\1'\2\3/;ta" || printf "%s" "$1"; }

pharma="—"
[[ -f "$ARTICLE_XML" ]] && pharma=$(grep -c '<SMNO>' "$ARTICLE_XML" || true)

nonpharma="—"
[[ -f "$FIRSTBASE_CSV" ]] && nonpharma=$(( $(wc -l < "$FIRSTBASE_CSV") - 1 ))

stand=$(date '+%d.%m.%Y %H:%M')

mkdir -p "$DOCROOT"
# Write atomically via temp + mv so the page can be refreshed regardless of who
# owns the existing index.html (setup runs as root, run_oddb2xml.sh as the user);
# mv only needs write on the directory, which both have.
tmp="${DOCROOT%/}/.index.html.$$"
cat > "$tmp" <<HTML
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>mediupdatexml.oddb.org — Downloads</title>
  <style>
    body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
           max-width: 820px; margin: 2.5rem auto; padding: 0 1.2rem; color: #1a1a1a; line-height: 1.5; }
    h1 { font-size: 1.6rem; margin-bottom: .2rem; }
    h2 { font-size: 1.15rem; margin-top: 2rem; border-bottom: 1px solid #ddd; padding-bottom: .3rem; }
    .sub { color: #666; margin-top: 0; }
    ul { list-style: none; padding-left: 0; }
    li { margin: .4rem 0; }
    a { color: #0a58ca; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .desc { color: #666; font-size: .9rem; }
    code { background: #f4f4f4; padding: .1rem .3rem; border-radius: 3px; }
    .stats { display: flex; gap: 1.5rem; margin: 1rem 0; flex-wrap: wrap; }
    .stat { background: #f4f7fb; border: 1px solid #dce4ef; border-radius: 8px; padding: .8rem 1.2rem; }
    .stat .n { font-size: 1.5rem; font-weight: 600; color: #0a58ca; }
    .stat .l { color: #555; font-size: .85rem; }
    footer { margin-top: 3rem; color: #888; font-size: .85rem; }
    ul.firms { columns: 2; column-gap: 2rem; }
    ul.firms li { margin: .25rem 0; break-inside: avoid; }
  </style>
</head>
<body>
  <h1>oddb2xml &amp; aips2sqlite Downloads</h1>
  <p class="sub">Schweizer Arzneimitteldaten — täglich aktualisiert (01:00 Uhr). Stand: ${stand}</p>

  <div class="stats">
    <div class="stat"><div class="n">$(group "$pharma")</div><div class="l">Medikamente (PHARMA)</div></div>
    <div class="stat"><div class="n">$(group "$nonpharma")</div><div class="l">Firstbase-Produkte (NONPHARMA)</div></div>
  </div>

  <h2>oddb2xml — Artikel-/Produkt-Feeds (<code>-b</code> firstbase)</h2>
  <ul>
    <li><a href="default/">default/</a> <span class="desc">— ohne Preisaufschlag</span></li>
    <li><a href="45/">45/</a> <span class="desc">— Wiederverkaufspreis +45&nbsp;%</span></li>
    <li><a href="50/">50/</a> <span class="desc">— Wiederverkaufspreis +50&nbsp;%</span></li>
    <li><a href="55/">55/</a> <span class="desc">— Wiederverkaufspreis +55&nbsp;%</span></li>
  </ul>
  <p class="desc">Jedes Verzeichnis enthält <code>oddb_article.xml</code>, <code>oddb_product.xml</code>,
  <code>oddb_calc.xml</code>, <code>oddb_interaction.xml</code>, <code>oddb_limitation.xml</code>,
  <code>oddb_substance.xml</code>, <code>oddb_code.xml</code> sowie <code>oddb2xml.zip</code> (alle Dateien gepackt).</p>

  <h2>aips2sqlite — Fachinformationen &amp; AmiKo-Datenbanken</h2>
  <ul>
    <li><a href="/aips2sqlite/">/aips2sqlite/</a> <span class="desc">— FI-XML (<code>fis/</code>), AmiKo-Datenbanken (<code>amiko_db_full_idx_{de,fr}.db</code>), <code>oddb2xml_swissmedic_sequences.csv</code></span></li>
  </ul>

  <h2>MediUpdate XML bei HIN</h2>
  <ul>
    <li><a href="https://www.hin.ch/de/services/mediupdate-xml.cfm">www.hin.ch/de/services/mediupdate-xml.cfm</a></li>
  </ul>

  <h2>Softwarehäuser, die oddb2xml einsetzen</h2>
  <ul class="firms">
    <li><a href="https://www.advancedconcepts.ch/">Advanced Concepts AG</a></li>
    <li><a href="https://www.bluecare.ch/">Bluecare AG</a></li>
    <li><a href="https://corona.ch/">Corona Informatik AG</a></li>
    <li><a href="https://www.derma2go.com/de/">derma2go AG</a></li>
    <li><a href="https://www.diagnosia.com/">Diagnosia Internetservices GmbH</a></li>
    <li><a href="https://elexis.ch/glp/index.html">Elexis</a></li>
    <li><a href="https://www.emedswiss.ch/">emedSwiss SA</a></li>
    <li><a href="https://gartenmann.ch/">Gartenmann Software AG</a></li>
    <li><a href="https://hexabit.ch/">Hexabit GmbH</a></li>
    <li><a href="https://www.hausarztmedizin.uzh.ch/de.html">Institut für Hausarztmedizin</a></li>
    <li><a href="https://www.itw-informatik.ch/de/">ITW INFORMATIK AG</a></li>
    <li><a href="https://www.lama-media.com/">Lama Media</a></li>
    <li><a href="https://medab.org/country/ch">MEDAB</a></li>
    <li><a href="https://www.pharmedsolutions.ch/">Pharmed Solutions GmbH</a></li>
    <li><a href="https://praxinova.ch/">Praxinova AG</a></li>
    <li><a href="https://seantis.ch/">seantis gmbh</a></li>
    <li><a href="https://www.geteyesoft.ch/">Siplus SA – Eyesoft</a></li>
    <li><a href="https://swiss-mr.ch/">SMR – Swiss Medical Record GmbH</a></li>
    <li><a href="https://triboni.com/site/">Triboni AG</a></li>
    <li><a href="https://www.vitabyte.ch/">Vitabyte AG</a></li>
    <li><a href="https://zollsoft.de/">zollsoft GmbH</a></li>
  </ul>

  <footer>
    Fragen: <a href="mailto:zdavatz@ywesee.com">zdavatz at ywesee dot com</a> &middot; Tel: 043 540 05 50
  </footer>
</body>
</html>
HTML
chmod 644 "$tmp"
mv -f "$tmp" "${DOCROOT%/}/index.html"

echo "Wrote ${DOCROOT%/}/index.html  (PHARMA=$pharma NONPHARMA=$nonpharma)"
