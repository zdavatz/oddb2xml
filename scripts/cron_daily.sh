#!/usr/bin/env bash
#
# cron_daily.sh — nightly orchestration, meant to be driven from /etc/crontab.
#
#   1. aips2sqlite  -> Fachinformation XML + swissmedic-sequences CSV
#   2. oddb2xml     -> firstbase feeds at increments 45/50/55/none
#   3. transfer     -> scp both to the HIN download server (only if SCP_DEST set)
#
# Sets up the environment cron does NOT provide (rbenv on PATH, RBENV_VERSION),
# because .ruby-version pins an uninstalled Ruby and cron has a minimal PATH.
#
# Configure the transfer destination here (or export it from the crontab):
#   SCP_DEST   scp target base, e.g. user@host:/var/www/.../download
#              Leave empty to build WITHOUT transferring (the default until the
#              new HIN host:path is known).
#
set -uo pipefail

export RBENV_VERSION="${RBENV_VERSION:-3.4.5}"
export PATH="/home/zdavatz/.rbenv/shims:/usr/local/bin:/usr/bin:/bin"

# export SCP_DEST="user@host:/var/www/download.hin.ch/htdocs/download"   # <-- set when known
SCP_DEST="${SCP_DEST:-}"

LOG_DIR="${LOG_DIR:-/home/zdavatz/log}"
mkdir -p "$LOG_DIR"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "$(ts) ===== nightly run START ====="

echo "$(ts) [1/2] aips2sqlite generate_aips_fi"
if /home/zdavatz/software/aips2sqlite/scripts/generate_aips_fi >> "$LOG_DIR/aips.log" 2>&1; then
  echo "$(ts)       aips OK"
else
  echo "$(ts)       aips FAILED (rc=$?) — see $LOG_DIR/aips.log"
fi

echo "$(ts) [2/2] oddb2xml run_oddb2xml.sh"
if [ -n "$SCP_DEST" ]; then
  export SCP_DEST RUN_TRANSFER=1
  echo "$(ts)       transfer ENABLED -> $SCP_DEST"
else
  echo "$(ts)       transfer DISABLED (SCP_DEST not set) — building only"
fi
if /home/zdavatz/software/oddb2xml/scripts/run_oddb2xml.sh >> "$LOG_DIR/oddb2xml.log" 2>&1; then
  echo "$(ts)       oddb2xml OK"
else
  echo "$(ts)       oddb2xml FAILED (rc=$?) — see $LOG_DIR/oddb2xml.log"
fi

echo "$(ts) ===== nightly run DONE ====="
