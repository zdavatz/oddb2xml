#!/usr/bin/env bash
#
# setup_aips2sqlite.sh — provision the aips2sqlite half of mediupdatexml.oddb.org.
#
# The landing page links a whole section of aips2sqlite output (Fachinformationen
# as XML, the AmiKo databases, the Swissmedic-sequences CSV), served by Apache
# through the alias
#
#     /aips2sqlite/  ->  $AIPS_DIR/jars/output
#
# written by setup_mediupdatexml_web.sh. That alias is only half the story: the
# directory it points at is produced by a Java job that has to run on this host.
# On the rebuilt server (2026-07-28) neither the JRE nor the output directory
# existed, so every /aips2sqlite/ link answered 403 — Apache denies a path that
# does not exist, because the granting <Directory> block never matches.
#
# This script installs the runtime, restores the checkout, creates the output
# directory and schedules the nightly regeneration.
#
# Run with:  sudo scripts/setup_aips2sqlite.sh
#
# Idempotent — safe to re-run. It does NOT generate the data (that takes ~1 h
# and belongs to the build user); run scripts/generate_aips_fi afterwards, or
# wait for the cron entry it installs.
#
# Configurable via environment:
#   RUN_USER    build/cron user       (default zdavatz)
#   AIPS_DIR    checkout location     (default /home/<RUN_USER>/software/aips2sqlite)
#   AIPS_REPO   clone URL             (default https://github.com/zdavatz/aips2sqlite)
#   OUT_DIR     published root, only used to locate the log dir
#   SKIP_CRON   set to 1 to leave /etc/cron.d/mediupdatexml alone
#
set -euo pipefail

RUN_USER="${RUN_USER:-zdavatz}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
AIPS_DIR="${AIPS_DIR:-${RUN_HOME}/software/aips2sqlite}"
AIPS_REPO="${AIPS_REPO:-https://github.com/zdavatz/aips2sqlite}"
OUT_DIR="${OUT_DIR:-${RUN_HOME}/oddb2xml}"
STATE_DIR="${OUT_DIR%/}-state"
CRON_FILE=/etc/cron.d/mediupdatexml

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo $0" >&2
  exit 1
fi
if [[ -z "$RUN_HOME" ]]; then
  echo "User $RUN_USER does not exist" >&2
  exit 1
fi

# --- 1. Java runtime ---------------------------------------------------------
# aips2sqlite ships a prebuilt fat jar (jars/aips2sqlite.jar), so a JRE is
# enough — no JDK and no Gradle unless the jar itself is rebuilt. README asks
# for Java 21+; Debian 13 has both 21 and 25, pin 21 to match what the jar was
# built and tested against.
#
# The font libraries are NOT optional, even though Debian lists them as mere
# Recommends of the headless JRE: every Fachinfo carries a rendered EAN13
# barcode (RealExpertInfo.updateSectionPackungen -> BarCode.encode -> barcode4j),
# and drawing its digits loads libfontmanager.so. Installing the JRE with
# --no-install-recommends therefore gets through the whole download phase and
# then dies on the first medicine with
#   UnsatisfiedLinkError: libfontmanager.so: libharfbuzz.so.0: cannot open ...
# so they are listed explicitly here rather than left to apt's recommends
# handling. fonts-dejavu-core gives fontconfig an actual font to find.
step "Installing the Java runtime (openjdk-21-jre-headless + font stack)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  openjdk-21-jre-headless \
  libfreetype6 libharfbuzz0b libfontconfig1 fonts-dejavu-core
java -version

# --- 2. Checkout -------------------------------------------------------------
step "Ensuring the aips2sqlite checkout at $AIPS_DIR"
if [[ -d "$AIPS_DIR/.git" ]]; then
  echo "already present — leaving it alone (generate_aips_fi does its own git pull)"
else
  install -d -o "$RUN_USER" -g "$RUN_USER" "$(dirname "$AIPS_DIR")"
  sudo -u "$RUN_USER" git clone "$AIPS_REPO" "$AIPS_DIR"
fi

# --- 3. Output + download directories ----------------------------------------
# jars/output is the Apache alias target: it must exist even while empty, or
# /aips2sqlite/ answers 403 instead of an (empty) listing.
step "Creating $AIPS_DIR/jars/{output,downloads}"
for d in "$AIPS_DIR/jars/output" "$AIPS_DIR/jars/downloads"; do
  install -d -o "$RUN_USER" -g "$RUN_USER" -m 755 "$d"
done

# --- 4. Nightly regeneration -------------------------------------------------
# The schedule lives in the one cron file setup_new_server.sh writes; append
# only when that file exists and does not already carry the entry, so the two
# scripts can be run in either order without fighting over it.
if [[ "${SKIP_CRON:-0}" != "1" ]]; then
  step "Scheduling the nightly Fachinfo generation (04:30)"
  install -d -o "$RUN_USER" -g "$RUN_USER" "$STATE_DIR"
  if [[ ! -f "$CRON_FILE" ]]; then
    echo "!! $CRON_FILE does not exist yet — run setup_new_server.sh first,"
    echo "   it writes the full schedule including this entry."
  elif grep -q 'generate_aips_fi' "$CRON_FILE"; then
    echo "entry already present in $CRON_FILE"
  else
    cat >> "$CRON_FILE" <<EOF

# 04:30  aips2sqlite Fachinfo XMLs + AmiKo DBs + Swissmedic sequences,
#        published under /aips2sqlite/.
30 4 * * *   $RUN_USER  [ -x $AIPS_DIR/scripts/generate_aips_fi ] && $AIPS_DIR/scripts/generate_aips_fi >> $STATE_DIR/generate_aips_fi.log 2>&1
EOF
    echo "appended to $CRON_FILE"
  fi
fi

cat <<EOF

==> aips2sqlite provisioning done.

The alias /aips2sqlite/ -> $AIPS_DIR/jars/output now resolves; it stays empty
until the generator has run once. As $RUN_USER (takes ~1 h, ~8 GB heap):

    $AIPS_DIR/scripts/generate_aips_fi

Optional: export REFDATA_API_KEY (developer.refdata.ch) to also fetch the
Refdata Partner GLN data. It is only consumed by the Takeda partner export,
so the Fachinfo/sequences output is complete without it — the run just logs
one download exception.

Known upstream gap: BAG's resource index
https://epl.bag.admin.ch/api/sl/public/resources/current currently reports
"fhir": {"fileUrl": null}, so aips2sqlite's FHIR download resolves to
/static/null and the run parses 0 preparations (no SL flags, no prices). The
export itself is alive at the fixed path oddb2xml uses:

    https://epl.bag.admin.ch/static/fhir/foph-sl-export-latest-de.ndjson

Until the jar learns that fallback, seed it before the run:

    cp <oddb2xml downloads>/foph-sl-export-latest-de.ndjson \\
       $AIPS_DIR/jars/downloads/fhir-sl.ndjson
EOF
