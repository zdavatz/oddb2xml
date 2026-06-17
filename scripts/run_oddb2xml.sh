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
#   <OUT_DIR>/45/        oddb_*.xml built with +45 %
#   <OUT_DIR>/50/        oddb_*.xml built with +50 %
#   <OUT_DIR>/55/        oddb_*.xml built with +55 %
#   <OUT_DIR>/default/   oddb_*.xml built with no increment
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

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

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

first=1

# build_one <increment-percent|""> <destination-subdir>
build_one() {
  local inc="$1" name="$2" dest="$OUT_DIR/$2"
  local inc_opt=() dl_opt=()
  [[ -n "$inc" ]] && inc_opt=(-I "$inc")

  if [[ $first -eq 1 ]]; then
    first=0                      # first build downloads the sources
  else
    dl_opt=(--skip-download)     # the rest re-use the cached downloads/
  fi

  log "Building increment '${inc:-none}' -> $dest"
  rm -f oddb*.zip
  "$ODDB2XML_BIN" "${dl_opt[@]}" -b "${inc_opt[@]}" -c zip

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

for inc in $INCREMENTS; do
  build_one "$inc" "$inc"
done
build_one "" "default"           # final run with no increment

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
