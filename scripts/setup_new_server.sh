#!/usr/bin/env bash
#
# setup_new_server.sh — bring a bare Debian host up to the point where it can
# run the mediupdatexml.oddb.org download site and its nightly builds.
#
# Written after HIN deleted the previous server (2026-07-28): everything that
# had accumulated by hand on that box is captured here, so a rebuild is one
# command instead of a day of archaeology.
#
# Run with:  sudo scripts/setup_new_server.sh
#
# Idempotent — safe to re-run. It installs packages, creates the build/output
# directories, installs the oddb2xml gem, writes /etc/cron.d/mediupdatexml and
# a logrotate rule, and finally hands over to setup_mediupdatexml_web.sh for the
# Apache vhost + Let's Encrypt certificate.
#
# What it deliberately does NOT do (run these as the build user afterwards):
#   scripts/setup_rust2xml.sh   Rust toolchain for the rust2xml artikelstamm job
#
# Configurable via environment:
#   RUN_USER   build/cron user            (default zdavatz)
#   OUT_DIR    published download root    (default /home/<RUN_USER>/oddb2xml)
#   SKIP_WEB   set to 1 to skip the Apache/certbot step
#   SKIP_GEM   set to 1 to skip `gem install oddb2xml`
#
set -euo pipefail

RUN_USER="${RUN_USER:-zdavatz}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
OUT_DIR="${OUT_DIR:-${RUN_HOME}/oddb2xml}"
BUILD_DIR="${OUT_DIR%/}-build"
STATE_DIR="${OUT_DIR%/}-state"
WATCH_DIR="${OUT_DIR%/}-watch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RUST2XML_DIR="${RUST2XML_DIR:-${RUN_HOME}/software/rust2xml}"
GET_TRANSFER_DIR="${GET_TRANSFER_DIR:-${RUN_HOME}/software/get_transfer}"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo $0" >&2
  exit 1
fi
if [[ -z "$RUN_HOME" ]]; then
  echo "User $RUN_USER does not exist" >&2
  exit 1
fi

# --- 1. System packages ------------------------------------------------------
# ruby-full     Debian 13 ships Ruby 3.3, matching the repo's .ruby-version --
#               no rbenv needed (the old box carried an rbenv 3.4.5 install).
# unzip/zip     run_oddb2xml.sh unpacks the build zip; ZurroseDownloader shells
#               out to `unzip` for transfer.zip, and to `iconv` (libc-bin).
# cron          not installed by default on a minimal Debian 13 image.
# poppler-utils pdftotext, for tools/generate_bag_sl_group_prices.rb.
# lib*-dev      native build fallbacks for nokogiri/ffi when no precompiled gem
#               matches the platform.
step "Installing system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  apache2 certbot python3-certbot-apache \
  ruby-full ruby-dev build-essential \
  cron unzip zip curl wget git ca-certificates \
  poppler-utils libxml2-dev libxslt1-dev zlib1g-dev libyaml-dev pkg-config
systemctl enable --now cron >/dev/null 2>&1 || true

# --- 2. User, groups, permissions -------------------------------------------
# "adm" lets visitor_stats.py read /var/log/apache2/*access.log for the graph.
step "Granting $RUN_USER read access to the Apache logs (group adm)"
usermod -aG adm "$RUN_USER"

# www-data must traverse (not list) the home dir to reach $OUT_DIR.
step "Setting $RUN_HOME to 711 so Apache can traverse it"
chmod 711 "$RUN_HOME"

# --- 3. The gem --------------------------------------------------------------
if [[ "${SKIP_GEM:-0}" != "1" ]]; then
  step "Installing the oddb2xml gem (system-wide, binstub in /usr/local/bin)"
  gem install oddb2xml --no-document
  oddb2xml --version 2>/dev/null || true
fi

# --- 4. Directory layout -----------------------------------------------------
# OUT_DIR    published, served by Apache (per-increment subdirs + landing page)
# BUILD_DIR  shared downloads/ cache; wiped at the start of every build
# STATE_DIR  last-good firstbase.csv + cron logs; must survive the wipe
# WATCH_DIR  swissmedic_watch.sh stamps and log
step "Creating $OUT_DIR, $BUILD_DIR, $STATE_DIR, $WATCH_DIR"
for d in "$OUT_DIR" "$BUILD_DIR" "$STATE_DIR" "$WATCH_DIR"; do
  mkdir -p "$d"
  chown "$RUN_USER:$RUN_USER" "$d"
done

# --- 5. Cron -----------------------------------------------------------------
# One /etc/cron.d file instead of the old scattered per-user crontab, so the
# whole schedule is visible (and re-creatable) in one place.
step "Writing /etc/cron.d/mediupdatexml"
cat > /etc/cron.d/mediupdatexml <<EOF
# mediupdatexml.oddb.org — nightly feed builds and download-site upkeep.
# Managed by oddb2xml/scripts/setup_new_server.sh; edit there, not here.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=$RUN_USER

# 00:30  Mirror the ZurRose transfer.dat locally (seeds the build's downloads/).
30 0 * * *   $RUN_USER  [ -x $GET_TRANSFER_DIR/get_transfer.sh ] && $GET_TRANSFER_DIR/get_transfer.sh >> $STATE_DIR/get_transfer.log 2>&1

# 01:00  Nightly oddb2xml build: default + artikelstamm (v6/v5) + 45/50/55.
0 1 * * *    $RUN_USER  $SCRIPT_DIR/run_oddb2xml.sh >> $STATE_DIR/run_oddb2xml.log 2>&1

# 03:00  rust2xml's own Artikelstamm, published under /artikelstamm/rust2xml/.
0 3 * * *    $RUN_USER  [ -x $RUST2XML_DIR/scripts/run_artikelstamm.sh ] && $RUST2XML_DIR/scripts/run_artikelstamm.sh >> $STATE_DIR/run_artikelstamm.log 2>&1

# hourly  Refresh the landing page (live counts + visitor graph).
5 * * * *    $RUN_USER  $SCRIPT_DIR/generate_index_html.sh $OUT_DIR >> $STATE_DIR/index_html.log 2>&1

# every 30 min  Rebuild automatically once Swissmedic answers again after a block.
*/30 * * * * $RUN_USER  $SCRIPT_DIR/swissmedic_watch.sh
EOF
chmod 644 /etc/cron.d/mediupdatexml

step "Writing /etc/logrotate.d/mediupdatexml"
cat > /etc/logrotate.d/mediupdatexml <<EOF
$STATE_DIR/*.log $WATCH_DIR/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    su $RUN_USER $RUN_USER
    create 0644 $RUN_USER $RUN_USER
}
EOF
chmod 644 /etc/logrotate.d/mediupdatexml

# --- 6. Apache vhost + HTTPS -------------------------------------------------
if [[ "${SKIP_WEB:-0}" != "1" ]]; then
  step "Provisioning the Apache vhost (setup_mediupdatexml_web.sh)"
  "$SCRIPT_DIR/setup_mediupdatexml_web.sh"
fi

cat <<EOF

==> Host provisioning done.

Next steps (as $RUN_USER, not root):
  1. Rust toolchain for the 03:00 job:   $SCRIPT_DIR/setup_rust2xml.sh
  2. First build (takes ~1-2 h):         $SCRIPT_DIR/run_oddb2xml.sh
  3. Landing page:                       $SCRIPT_DIR/generate_index_html.sh $OUT_DIR

Check the schedule with:  cat /etc/cron.d/mediupdatexml
EOF
