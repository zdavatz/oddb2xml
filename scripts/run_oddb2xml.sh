#!/usr/bin/env bash
#
# run_oddb2xml — build the firstbase (-b) oddb2xml feed at several price
# increments and stage the results for transfer.
#
# The upstream sources are downloaded ONCE: the first build fetches them, and
# every subsequent increment re-uses the cached ./downloads via --skip-download.
# All builds therefore run in a single shared working directory ($BUILD_DIR) —
# the original deploy script cd'd into a separate dir per increment, where
# --skip-download could not find downloads/ (DOWNLOADS is cwd-relative) and
# silently re-downloaded everything each time.
#
# Output layout (under $OUT_DIR, default /home/zdavatz/oddb2xml):
#   <OUT_DIR>/45/           oddb_*.xml built with +45 %
#   <OUT_DIR>/50/           oddb_*.xml built with +50 %
#   <OUT_DIR>/55/           oddb_*.xml built with +55 %
#   <OUT_DIR>/default/      oddb_*.xml built with no increment
#   <OUT_DIR>/artikelstamm/ Elexis Artikelstamm v6 + legacy v5 (xml + csv),
#                           served at https://mediupdatexml.oddb.org/artikelstamm
# Each destination dir also keeps the source archive as oddb2xml.zip.
# The working dir ($BUILD_DIR, default <OUT_DIR>-build) holds the shared
# downloads/ cache and the transient zip; it lives OUTSIDE $OUT_DIR so the
# transfer's `scp -r $OUT_DIR/*` never uploads the multi-hundred-MB cache.
#
# Configurable via environment:
#   OUT_DIR           destination root          (default /home/zdavatz/oddb2xml)
#   BUILD_DIR         working dir               (default <OUT_DIR>-build)
#   INCREMENTS        space-separated percents   (default "45 50 55")
#   ODDB2XML_BIN      oddb2xml executable        (default oddb2xml)
#   SKIP_GEM_INSTALL  set to 1 to skip `gem install oddb2xml`
#   RUN_TRANSFER      set to 1 to run the transfer (scripts/transfer.sh) at the end
#   TRANSFER_CMD      transfer command (default: sudo, preserving
#                     ODDB2XML_TRANSFER_DIR, scripts/transfer.sh next to this file)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-/home/zdavatz/oddb2xml}"
BUILD_DIR="${BUILD_DIR:-${OUT_DIR%/}-build}"
INCREMENTS="${INCREMENTS:-45 50 55}"
ODDB2XML_BIN="${ODDB2XML_BIN:-oddb2xml}"
TRANSFER_CMD="${TRANSFER_CMD:-$SCRIPT_DIR/transfer.sh}"
# Transient upstream download failures (e.g. Swissmedic resetting the
# connection, Errno::ECONNRESET) used to abort the whole nightly run under
# `set -e`. Retry the oddb2xml build a few times before giving up.
ODDB2XML_RETRIES="${ODDB2XML_RETRIES:-3}"
ODDB2XML_RETRY_DELAY="${ODDB2XML_RETRY_DELAY:-120}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# run_with_retry <description> -- <command...>
# Retry a flaky command up to ODDB2XML_RETRIES times, sleeping
# ODDB2XML_RETRY_DELAY seconds between attempts. Running the command as the
# `until` condition keeps it exempt from `set -e`, so a failed attempt retries
# instead of killing the script; the final failure is propagated via return.
run_with_retry() {
  local desc="$1"; shift
  [[ "${1:-}" == "--" ]] && shift
  local attempt=1 rc=0
  until "$@"; do
    rc=$?
    if [[ $attempt -ge $ODDB2XML_RETRIES ]]; then
      log "ERROR: $desc failed after $attempt attempts (last exit $rc)"
      return $rc
    fi
    log "WARNING: $desc failed (exit $rc), attempt $attempt/$ODDB2XML_RETRIES; retrying in ${ODDB2XML_RETRY_DELAY}s"
    sleep "$ODDB2XML_RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

# 1. Install / update the published gem unless told otherwise.
if [[ "${SKIP_GEM_INSTALL:-0}" != "1" ]]; then
  log "Installing oddb2xml gem"
  gem install oddb2xml
fi

# 2. Fresh working dir (keeps a shared downloads/ cache across increments).
log "Preparing build dir $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 3. ZurRose transfer.zip source. get_transfer.sh (crontab 00:30) downloads
# transfer.dat straight from zurrose.ch on THIS host and mirrors the zip locally
# (it also uploads it to http://pillbox.oddb.org/TRANSFER.ZIP). The build seeds
# this local copy into a fresh downloads/ (see seed_downloads below) so the first
# build reuses it via --skip-download instead of fetching pillbox — which refused
# connections around 01:00 every night from 2026-07-04 on and aborted the whole
# run at the ZurRose step (downloader.rb:221, transfer.dat ENOENT). Everything
# else is still fetched fresh: --skip-download only reuses files already present
# in downloads/ and downloads the rest.
GET_TRANSFER_ZIP="${GET_TRANSFER_ZIP:-/home/zdavatz/software/get_transfer/TRANSFER.ZIP}"
[[ -s "$GET_TRANSFER_ZIP" ]] || log "WARNING: $GET_TRANSFER_ZIP missing - ZurRose will fall back to pillbox.oddb.org"

# 3b. Firstbase (GS1 NONPHARMA) last-good cache. Because the first build now runs
# with --skip-download (to keep the ZurRose seed, see above), firstbase.csv must
# NOT be pre-seeded into downloads/: under --skip-download a present firstbase.csv
# would be reused verbatim and never refreshed from GS1. Instead firstbase is
# fetched fresh every run (GS1's id.gs1.ch route works) and the fresh file is
# archived to this persistent cache after the build for reference / recovery.
FIRSTBASE_CACHE="${FIRSTBASE_CACHE:-${OUT_DIR%/}-state/firstbase.csv}"

# seed_downloads — reset downloads/ so it contains only the ZurRose transfer.zip
# seed. A following --skip-download build reuses that zip (no pillbox fetch) and
# downloads every other source fresh. Called before each attempt of the first
# build, so a retry restarts from a clean cache (clearing any partial download)
# while preserving the seed.
seed_downloads() {
  rm -rf "$BUILD_DIR/downloads"
  mkdir -p "$BUILD_DIR/downloads"
  if [[ -s "$GET_TRANSFER_ZIP" ]]; then
    cp -p "$GET_TRANSFER_ZIP" "$BUILD_DIR/downloads/transfer.zip"
    log "Seeded ZurRose transfer.zip from $GET_TRANSFER_ZIP ($(date -r "$GET_TRANSFER_ZIP" '+%Y-%m-%d %H:%M'))"
  fi
}

# first_build_attempt — seed downloads/, then run the first (downloading) build.
# Wrapped in run_with_retry so each retry re-seeds and re-downloads cleanly.
first_build_attempt() {
  seed_downloads
  "$ODDB2XML_BIN" --skip-download -b "$@" -c zip
}

first=1

# build_one <increment-percent|""> <destination-subdir>
build_one() {
  local inc="$1" name="$2" dest="$OUT_DIR/$2"
  local inc_opt=()
  [[ -n "$inc" ]] && inc_opt=(-I "$inc")

  log "Building increment '${inc:-none}' -> $dest"
  rm -f oddb*.zip
  if [[ $first -eq 1 ]]; then
    first=0
    # First build: seed the ZurRose zip into a clean downloads/, then fetch every
    # other source fresh. Runs with --skip-download so cli.rb does not wipe
    # downloads/ and the seeded transfer.zip survives (no pillbox fetch).
    run_with_retry "oddb2xml build '${inc:-none}'" -- first_build_attempt "${inc_opt[@]}"
  else
    # Subsequent increments re-use the fully-populated downloads/ cache (firstbase
    # and everything else were downloaded once by the first build).
    run_with_retry "oddb2xml build '${inc:-none}'" -- \
      "$ODDB2XML_BIN" --skip-download -b "${inc_opt[@]}" -c zip
  fi

  shopt -s nullglob
  local zips=(oddb*.zip)
  shopt -u nullglob
  [[ ${#zips[@]} -ge 1 ]] || { log "ERROR: no zip produced for increment '${inc:-none}'"; exit 1; }
  local zip="${zips[0]}"

  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -o -q -d "$dest" "$zip"
  mv "$zip" "$dest/oddb2xml.zip"
  log "Staged $dest"
}

# build_artikelstamm — build the Elexis Artikelstamm (v6 + legacy v5) and stage
# it at $OUT_DIR/artikelstamm, served at
# https://mediupdatexml.oddb.org/artikelstamm. Re-uses the shared downloads/
# cache (--skip-download), so it adds no extra upstream fetch beyond the few
# sources the firstbase builds don't pull (e.g. the ZurRose transfer.dat).
build_artikelstamm() {
  local dest="$OUT_DIR/artikelstamm"
  log "Building Artikelstamm (v6 + v5) -> $dest"
  rm -f artikelstamm_*.xml artikelstamm_*.csv
  run_with_retry "oddb2xml artikelstamm" -- \
    "$ODDB2XML_BIN" --skip-download --artikelstamm --artikelstamm-v5

  shopt -s nullglob
  local out=(artikelstamm_*.xml artikelstamm_*.csv)
  shopt -u nullglob
  [[ ${#out[@]} -ge 1 ]] || { log "ERROR: no artikelstamm output produced"; exit 1; }

  mkdir -p "$dest"
  # Remove only oddb2xml's own top-level files; keep sub-directories such as
  # rust2xml/ (published independently by rust2xml's own cron at 03:00) intact.
  # A plain `rm -rf "$dest"` used to wipe that sibling output every night.
  rm -f "$dest"/artikelstamm_*.xml "$dest"/artikelstamm_*.csv
  # Publish under date-less, stable names so the download URLs never change:
  # artikelstamm_01072026_v6.xml -> artikelstamm_v6.xml (same for _v5 / .csv).
  local f base
  for f in "${out[@]}"; do
    base="$(basename "$f" | sed -E 's/_[0-9]{8}_/_/')"
    cp -p "$f" "$dest/$base"
  done
  log "Staged ${#out[@]} file(s) to $dest"
}

# Build order: default first (it downloads the shared sources), then the
# Artikelstamm right after so it is published early, then the price increments.
build_one "" "default"           # first run: downloads sources, no increment

# Refresh the last-good firstbase.csv cache after the downloading build. When
# GS1 answered, downloads/firstbase.csv now holds fresh data; when it 403'd, the
# gem kept the seeded copy - either way a non-empty file is worth caching so the
# next run can fall back to it. An empty file means both today's download AND the
# seed were missing, so leave the previous cache untouched.
FIRSTBASE_LIVE="$BUILD_DIR/downloads/firstbase.csv"
if [[ -s "$FIRSTBASE_LIVE" ]]; then
  mkdir -p "$(dirname "$FIRSTBASE_CACHE")"
  cp -p "$FIRSTBASE_LIVE" "$FIRSTBASE_CACHE"
  log "Cached firstbase.csv as last-good ($(($(wc -l < "$FIRSTBASE_LIVE") - 1)) rows) -> $FIRSTBASE_CACHE"
else
  log "WARNING: firstbase.csv is empty after the build (GS1 403 and no cache) - NONPHARMA missing this run"
fi

build_artikelstamm               # Elexis Artikelstamm (v6 + legacy v5)
for inc in $INCREMENTS; do
  build_one "$inc" "$inc"        # price increments re-use the cached downloads/
done

# 2b. Refresh the download landing page with the live PHARMA/NONPHARMA counts
#     (PHARMA from default/oddb_article.xml, NONPHARMA from the GS1 firstbase CSV).
if [[ -x "$SCRIPT_DIR/generate_index_html.sh" ]]; then
  log "Refreshing landing page index.html"
  "$SCRIPT_DIR/generate_index_html.sh" "$OUT_DIR" "$BUILD_DIR/downloads/firstbase.csv" || \
    log "WARNING: could not regenerate index.html"
fi

# 3. Optional hand-off to the transfer step (scripts/transfer.sh).
if [[ "${RUN_TRANSFER:-0}" == "1" ]]; then
  log "Running transfer: $TRANSFER_CMD"
  export ODDB2XML_TRANSFER_DIR="$OUT_DIR"   # keep transfer.sh in sync with OUT_DIR
  $TRANSFER_CMD
fi

log "Done. Output under $OUT_DIR"
