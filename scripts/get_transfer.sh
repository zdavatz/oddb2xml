#!/usr/bin/env bash
#
# get_transfer — mirror the ZurRose IGM11 "Vollstamm" article master locally.
#
# ZurRose publishes the full article master as a fixed-width transfer.dat. The
# nightly build (run_oddb2xml.sh, 01:00) seeds the zip produced here into its
# downloads/ cache, so oddb2xml reads ZurRose from this host instead of
# fetching http://pillbox.oddb.org/TRANSFER.ZIP — see seed_downloads() there.
#
# History worth keeping: this script used to live ONLY in
# /home/zdavatz/software/get_transfer on the old server, so when that host was
# deleted (2026-07-28) the mirror went with it, together with its download URL.
# It now lives in the repo and $DATA_DIR/get_transfer.sh is a symlink to it, so
# a rebuilt server gets it back from the checkout (setup_new_server.sh).
#
# The download URL moved too: the old
# zurrose.com/fileadmin/main/lib/download.php?file=... path 301s to the
# marketing homepage since roughly mid-July 2026. The current one is below.
#
# ZurRose refreshes the master roughly every 14 days, so most runs legitimately
# fetch a file identical to yesterday's; that is not an error.
#
# Configurable via environment:
#   TRANSFER_URL   source URL       (default: the ZurRose IGM11 de/transfer.dat)
#   DATA_DIR       where TRANSFER.ZIP lands (default /home/zdavatz/software/get_transfer)
#   MIN_LINES      reject a file with fewer records  (default 100000)
#
set -euo pipefail

TRANSFER_URL="${TRANSFER_URL:-https://www.zurrose.ch/sites/default/files/media/downloads/medi/produktupdate/igm11/de/transfer.dat}"
DATA_DIR="${DATA_DIR:-/home/zdavatz/software/get_transfer}"
MIN_LINES="${MIN_LINES:-100000}"

ZIP="$DATA_DIR/TRANSFER.ZIP"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$DATA_DIR"

# Work in a scratch dir so a failed or truncated download can never replace a
# good TRANSFER.ZIP. The build reads that zip unconditionally at 01:00; half a
# file there would abort the whole nightly run at oddb2xml's unzip step.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/get_transfer.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

log "Downloading $TRANSFER_URL"
curl -fsSL --max-time 900 --retry 3 --retry-delay 30 \
     -o "$WORK/transfer.dat" "$TRANSFER_URL" \
  || die "download failed - keeping $( [[ -s $ZIP ]] && echo "the previous TRANSFER.ZIP" || echo "nothing, there is no previous TRANSFER.ZIP" )"

# Validate before publishing. transfer.dat is a fixed-width IGM11 file: every
# record is exactly 98 bytes. A login page, an error page or a truncated
# transfer would sail through a plain size check but fails this one.
lines=$(wc -l < "$WORK/transfer.dat")
(( lines >= MIN_LINES )) \
  || die "only $lines records (< $MIN_LINES) - looks like an error page, not the Vollstamm"
badlen=$(awk 'length != 98 { n++ } END { print n+0 }' "$WORK/transfer.dat")
(( badlen == 0 )) \
  || die "$badlen of $lines records are not 98 chars - not an IGM11 fixed-width file"

# The zip entry MUST be named transfer.dat (lowercase): oddb2xml unzips it into
# downloads/ and then opens downloads/transfer.dat by that exact name
# (ZurroseDownloader, lib/oddb2xml/downloader.rb).
( cd "$WORK" && zip -q TRANSFER.ZIP transfer.dat )

if cmp -s "$WORK/transfer.dat" <(unzip -p "$ZIP" transfer.dat 2>/dev/null); then
  log "Unchanged since the last run ($lines records) - refreshing the mirror anyway"
fi

# Atomic publish: same filesystem, so mv is a rename. A reader either sees the
# old zip or the new one, never a partial.
mv "$WORK/TRANSFER.ZIP" "$ZIP.new" && mv "$ZIP.new" "$ZIP"

log "Wrote $ZIP ($(stat -c %s "$ZIP") bytes, $lines records)"
