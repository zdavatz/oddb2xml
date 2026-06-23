#!/usr/bin/env bash
#
# swissmedic_watch.sh — recover the nightly build automatically after a
# Swissmedic outage/block.
#
# Background: since the Swissmedic platform migration (~2026-06-23, now on a
# Swisscom-operated gateway) www.swissmedic.ch resets this host's automated
# connections after the TLS handshake (TCP RST), so run_oddb2xml.sh aborts and
# the feeds go stale. The block may be a temporary migration artefact. Rather
# than rebuild blindly, this watcher polls Swissmedic with the *same* client
# oddb2xml uses (Ruby open-uri) and, the moment it answers again, kicks off one
# build — then emails. Meant to run every 30 min from /etc/crontab:
#
#   */30 * * * * zdavatz /home/zdavatz/software/oddb2xml/scripts/swissmedic_watch.sh
#
# It is a no-op while Swissmedic is still blocked, while a build is already
# running, or once today's feeds are fresh — and it fires at most once per day.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-/home/zdavatz/oddb2xml}"
BUILD_DIR="${BUILD_DIR:-${OUT_DIR%/}-build}"
# State (log + once-per-day stamp) lives OUTSIDE BUILD_DIR, which run_oddb2xml.sh
# deletes at the start of every build.
STATE_DIR="${STATE_DIR:-${OUT_DIR%/}-watch}"
ARTICLE_XML="$OUT_DIR/default/oddb_article.xml"
CANARY_URL="https://www.swissmedic.ch/swissmedic/de/home/services/listen_neu.html"

# Match the nightly cron's rbenv environment (the repo's .ruby-version points at
# a Ruby that isn't installed here; cron pins RBENV_VERSION instead).
export RBENV_VERSION="${RBENV_VERSION:-3.4.5}"
export PATH="/home/zdavatz/.rbenv/shims:/usr/bin:/bin"

mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/swissmedic_watch.log"
today="$(date +%F)"
stamp="$STATE_DIR/.built.$today"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

notify() {  # best-effort local mail; silently skipped if no MTA
  local subj="$1" body="${2:-$1}" sm=""
  command -v sendmail >/dev/null 2>&1 && sm="$(command -v sendmail)"
  [[ -z "$sm" && -x /usr/sbin/sendmail ]] && sm=/usr/sbin/sendmail
  [[ -n "$sm" ]] && printf 'To: zdavatz\nSubject: %s\n\n%s\n' "$subj" "$body" | "$sm" -t 2>/dev/null || true
}

# Already attempted a watcher-triggered build today? (set when we launch, so a
# failed build is not relaunched every 30 min — the nightly cron / a human can.)
[[ -e "$stamp" ]] && exit 0

# A build (nightly or earlier watcher) already running? Leave it alone.
if pgrep -f 'run_oddb2xml\.sh' >/dev/null 2>&1; then
  exit 0
fi

# Today's feeds already fresh (nightly cron succeeded)? Nothing to do.
if [[ -f "$ARTICLE_XML" && "$(date -r "$ARTICLE_XML" +%F)" == "$today" ]]; then
  exit 0
fi

# Canary: can THIS host reach Swissmedic with oddb2xml's own client (open-uri)?
# Exit 0 only on HTTP 200; any reset/timeout/non-200 means still blocked.
if ! ruby -ropen-uri -e '
  begin
    URI.open(ARGV[0], open_timeout: 20, read_timeout: 25) { |f| exit(f.status[0].to_i == 200 ? 0 : 3) }
  rescue => e
    warn "#{e.class}: #{e.message}"; exit 1
  end' "$CANARY_URL" >>"$LOG" 2>&1
then
  # Still blocked — stay quiet (don't spam the log every 30 min; one line/day).
  [[ -e "$STATE_DIR/.blocked.$today" ]] || { log "Swissmedic still unreachable; waiting."; : >"$STATE_DIR/.blocked.$today"; }
  exit 0
fi

# Reachable again and feeds are stale -> launch exactly one build.
: >"$stamp"
log "Swissmedic reachable again — launching run_oddb2xml.sh"
notify "oddb2xml: Swissmedic reachable again — build started" \
       "Swissmedic answered the open-uri canary at $(date). Starting run_oddb2xml.sh; output in $STATE_DIR/run_oddb2xml.watch.log."

nohup "$SCRIPT_DIR/run_oddb2xml.sh" >>"$STATE_DIR/run_oddb2xml.watch.log" 2>&1 &
log "launched run_oddb2xml.sh (pid $!)"
exit 0
