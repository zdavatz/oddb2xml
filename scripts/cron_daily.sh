#!/usr/bin/env bash
#
# cron_daily.sh — nightly orchestration, driven from /etc/crontab:
#   aips2sqlite FI/CSV -> oddb2xml feeds (45/50/55/none) -> transfer to HIN.
#
# Sets up the environment cron does not provide (rbenv on PATH, RBENV_VERSION),
# because .ruby-version pins an uninstalled Ruby and cron's PATH is minimal.
# The transfer only runs once SCP_DEST is set (build-only until then).
#
set -uo pipefail

export RBENV_VERSION="${RBENV_VERSION:-3.4.5}"
export PATH="/home/zdavatz/.rbenv/shims:/usr/local/bin:/usr/bin:/bin"
# export SCP_DEST="user@host:/var/www/download.hin.ch/htdocs/download"   # set to enable transfer

/home/zdavatz/software/aips2sqlite/scripts/generate_aips_fi

[ -n "${SCP_DEST:-}" ] && export RUN_TRANSFER=1
/home/zdavatz/software/oddb2xml/scripts/run_oddb2xml.sh
