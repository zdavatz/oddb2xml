#!/usr/bin/env bash
#
# Provision Apache to serve the oddb2xml output at https://mediupdatexml.oddb.org
# (Let's Encrypt HTTPS + browsable downloads, like pillbox.oddb.org).
#
# Serves two areas on one domain:
#   /              -> $DOCROOT          (oddb2xml feeds: default/ 45/ 50/ 55/)
#   /aips2sqlite/  -> $AIPS_OUT         (FI XMLs, AmiKo .db, sequences CSV)
# plus a curated landing page ($DOCROOT/index.html) linking both.
#
# Run with:  sudo scripts/setup_mediupdatexml_web.sh
#
# Idempotent: safe to re-run. HTTPS is issued/renewed automatically once the
# domain's DNS points at this host.

set -euo pipefail

DOMAIN="mediupdatexml.oddb.org"
DOCROOT="/home/zdavatz/oddb2xml"
AIPS_OUT="/home/zdavatz/software/aips2sqlite/jars/output"
EMAIL="zdavatz@gmail.com"
SITE="/etc/apache2/sites-available/${DOMAIN}.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo $0" >&2
  exit 1
fi

echo "==> Installing apache2 + certbot"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y apache2 certbot python3-certbot-apache

echo "==> Enabling required Apache modules"
a2enmod autoindex headers >/dev/null

echo "==> Allowing www-data to traverse /home/zdavatz (711 = no listing, path access only)"
chmod 711 /home/zdavatz

echo "==> Writing vhost $SITE"
cat > "$SITE" <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        Options +Indexes +FollowSymLinks
        IndexOptions FancyIndexing HTMLTable NameWidth=* SuppressDescription FoldersFirst
        Require all granted
        AllowOverride None
    </Directory>

    ErrorLog  \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF

echo "==> Writing aips2sqlite download alias (/aips2sqlite -> jars/output)"
cat > /etc/apache2/conf-available/mediupdatexml-aips.conf <<EOF
# aips2sqlite output (FI XMLs, AmiKo .db, swissmedic sequences CSV)
# Served on both the HTTP and HTTPS vhosts of ${DOMAIN}.
Alias /aips2sqlite ${AIPS_OUT}
<Directory ${AIPS_OUT}>
    Options +Indexes +FollowSymLinks
    IndexOptions FancyIndexing HTMLTable NameWidth=* SuppressDescription FoldersFirst
    Require all granted
    AllowOverride None
</Directory>
EOF
a2enconf mediupdatexml-aips >/dev/null

# Curated landing page. Lives in the OUT_DIR root, which run_oddb2xml.sh never
# touches (it only rebuilds the per-increment subdirs), so it survives rebuilds.
echo "==> Writing landing page ${DOCROOT}/index.html"
mkdir -p "${DOCROOT}"
cat > "${DOCROOT}/index.html" <<'HTML'
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
    footer { margin-top: 3rem; color: #888; font-size: .85rem; }
  </style>
</head>
<body>
  <h1>oddb2xml &amp; aips2sqlite Downloads</h1>
  <p class="sub">Schweizer Arzneimitteldaten — täglich aktualisiert (01:00 Uhr).</p>

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

  <footer>
    Fragen: <a href="mailto:zdavatz@ywesee.com">zdavatz at ywesee dot com</a> &middot; Tel: 043 540 05 50
  </footer>
</body>
</html>
HTML

echo "==> Enabling site, disabling default"
a2ensite "${DOMAIN}.conf" >/dev/null
a2dissite 000-default.conf >/dev/null 2>&1 || true

echo "==> Testing config and reloading Apache"
apache2ctl configtest
systemctl reload apache2
systemctl enable apache2 >/dev/null 2>&1 || true

echo
echo "==> HTTP is live: http://${DOMAIN}/  (serving ${DOCROOT})"
echo

# --- HTTPS via Let's Encrypt -------------------------------------------------
# Check a public resolver (Cloudflare DoH), not the local one, which may still
# hold a negative cache. Let's Encrypt validates from its own resolvers anyway.
resolved=$(curl -s --max-time 8 \
  "https://1.1.1.1/dns-query?name=${DOMAIN}&type=A" \
  -H 'accept: application/dns-json' \
  | python3 -c "import sys,json; a=json.load(sys.stdin).get('Answer',[]); print(a[0]['data'] if a else '')" 2>/dev/null || true)
if [[ -z "$resolved" ]]; then
  echo "!! ${DOMAIN} does not resolve in public DNS yet."
  echo "   Once the A/AAAA records propagate, run:"
  echo "     sudo certbot --apache -d ${DOMAIN} --redirect -m ${EMAIL} --agree-tos -n"
  exit 0
fi

echo "==> ${DOMAIN} resolves to ${resolved} — requesting Let's Encrypt cert"
certbot --apache -d "${DOMAIN}" --redirect -m "${EMAIL}" --agree-tos -n
echo
echo "==> Done. HTTPS is live: https://${DOMAIN}/"
echo "    Certbot installed a systemd timer for auto-renewal."
