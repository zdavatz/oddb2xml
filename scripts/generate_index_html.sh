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

total="—"
[[ -f "$ARTICLE_XML" ]] && total=$(grep -c '<ART ' "$ARTICLE_XML" || true)

pharma="—"
[[ -f "$ARTICLE_XML" ]] && pharma=$(grep -c '<SMNO>' "$ARTICLE_XML" || true)

nonpharma="—"
[[ -f "$FIRSTBASE_CSV" ]] && nonpharma=$(( $(wc -l < "$FIRSTBASE_CSV") - 1 ))

stand=$(date '+%d.%m.%Y %H:%M')

mkdir -p "$DOCROOT"

# Logo (self-contained SVG): brand-blue rounded badge, white pharma/Swiss cross
# flanked by XML angle brackets "< >". Written atomically next to index.html and
# used both as the top-right header image and as the favicon.
logo_tmp="${DOCROOT%/}/.logo.svg.$$"
cat > "$logo_tmp" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="oddb2xml">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1a6dff"/>
      <stop offset="1" stop-color="#0a3d8f"/>
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="14" fill="url(#g)"/>
  <g stroke="#e2231a" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <polyline points="15,24 9,32 15,40"/>
    <polyline points="49,24 55,32 49,40"/>
  </g>
  <g fill="#ffffff">
    <rect x="26.5" y="18" width="11" height="28" rx="2.5"/>
    <rect x="18" y="26.5" width="28" height="11" rx="2.5"/>
  </g>
</svg>
SVG
chmod 644 "$logo_tmp"
mv -f "$logo_tmp" "${DOCROOT%/}/logo.svg"

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
  <!-- open every link in a new tab -->
  <base target="_blank">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <link rel="icon" type="image/svg+xml" href="logo.svg">
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
    .topbar { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; }
    .topbar .title h1 { margin: 0 0 .2rem; }
    .topbar .logo { width: 64px; height: 64px; flex: 0 0 auto; }
  </style>
</head>
<body>
  <header class="topbar">
    <div class="title">
      <h1>oddb2xml &amp; aips2sqlite Downloads</h1>
      <p class="sub">Schweizer Arzneimitteldaten — täglich aktualisiert (01:00 Uhr). Stand: ${stand}</p>
    </div>
    <a href="mailto:zdavatz@ywesee.com" title="Fragen? zdavatz at ywesee dot com"><img class="logo" src="logo.svg" alt="oddb2xml Logo" width="64" height="64"></a>
  </header>

  <div class="stats">
    <div class="stat"><div class="n">$(group "$pharma")</div><div class="l">Medikamente (PHARMA)</div></div>
    <div class="stat"><div class="n"><a href="https://id.gs1.ch/01/07612345000961">$(group "$nonpharma")</a></div><div class="l">Firstbase-Produkte (NONPHARMA)</div></div>
    <div class="stat"><div class="n"><a href="default/oddb_article.xml">$(group "$total")</a></div><div class="l">Artikel total (<a href="default/oddb_article.xml"><code>oddb_article.xml</code></a>)</div></div>
  </div>

  <h2>oddb2xml — Artikel-/Produkt-Feeds (<code>-b</code> firstbase)</h2>
  <ul>
    <li><a href="default/">default/</a> <span class="desc">— ohne Preisaufschlag</span></li>
    <li><a href="45/">45/</a> <span class="desc">— Wiederverkaufspreis +45&nbsp;%</span></li>
    <li><a href="50/">50/</a> <span class="desc">— Wiederverkaufspreis +50&nbsp;%</span></li>
    <li><a href="55/">55/</a> <span class="desc">— Wiederverkaufspreis +55&nbsp;%</span></li>
  </ul>
  <p class="desc">Jedes Verzeichnis enthält die gleichen Dateien (Direktlinks zum <code>default/</code>-Feed):
  <a href="default/oddb_article.xml">oddb_article.xml</a>,
  <a href="default/oddb_product.xml">oddb_product.xml</a>,
  <a href="default/oddb_calc.xml">oddb_calc.xml</a>,
  <a href="default/oddb_interaction.xml">oddb_interaction.xml</a>,
  <a href="default/oddb_limitation.xml">oddb_limitation.xml</a>,
  <a href="default/oddb_substance.xml">oddb_substance.xml</a>,
  <a href="default/oddb_code.xml">oddb_code.xml</a> sowie
  <a href="default/oddb2xml.zip">oddb2xml.zip</a> (alle Dateien gepackt).</p>

  <h2>aips2sqlite — Fachinformationen &amp; AmiKo-Datenbanken</h2>
  <ul>
    <li><a href="/aips2sqlite/fis/">fis/</a> <span class="desc">— Fachinformationen als XML/HTML (DE/FR/IT)</span></li>
    <li><a href="/aips2sqlite/amiko_db_full_idx_de.db">amiko_db_full_idx_de.db</a> <span class="desc">— AmiKo-Datenbank Deutsch</span></li>
    <li><a href="/aips2sqlite/amiko_db_full_idx_fr.db">amiko_db_full_idx_fr.db</a> <span class="desc">— AmiKo-Datenbank Französisch</span></li>
    <li><a href="/aips2sqlite/oddb2xml_swissmedic_sequences.csv">oddb2xml_swissmedic_sequences.csv</a> <span class="desc">— Swissmedic-Sequenzen</span></li>
    <li><a href="/aips2sqlite/atc_codes_used_set.txt">atc_codes_used_set.txt</a> <span class="desc">— verwendete ATC-Codes</span></li>
    <li><a href="/aips2sqlite/">/aips2sqlite/</a> <span class="desc">— gesamtes Verzeichnis durchsuchen</span></li>
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
