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

# Curated landing page (with live PHARMA/NONPHARMA counts). Lives in the OUT_DIR
# root, which run_oddb2xml.sh never touches (it only rebuilds the per-increment
# subdirs), so it survives rebuilds — and run_oddb2xml.sh refreshes the counts
# after every build via the same generator.
echo "==> Writing landing page ${DOCROOT}/index.html"
"$(dirname "$0")/generate_index_html.sh" "${DOCROOT}"

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
