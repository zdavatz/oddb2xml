#!/usr/bin/env python3
# visitor_stats.py — build a small, self-contained "visitors & sessions" graph
# (inline SVG HTML fragment) for the mediupdatexml.oddb.org landing page from
# the Apache combined access log, broken down by day and by region (country).
#
#   Besucher  (visitors) = distinct client IPs per day
#   Sitzungen (sessions) = 30-min-inactivity sessions per (IP, User-Agent) per day
#   Regionen  (regions)  = top countries of the distinct IPs in the window
#
# Region resolution is fully self-contained: it uses the free DB-IP country-lite
# CSV (CC-BY 4.0, no licence key) cached next to the other runtime downloads and
# refreshed monthly — NO apt package, NO gem, NO system GeoIP database.
#
# Usage: visitor_stats.py LOG_GLOB CACHE_DIR [DAYS]
#   LOG_GLOB   e.g. "/var/log/apache2/mediupdatexml.oddb.org_access.log*"
#   CACHE_DIR  dir to cache the DB-IP CSV (the build downloads/ dir)
#   DAYS       window length, default 14
#
# Prints an HTML fragment to stdout on success. Prints NOTHING and exits 0 when
# the logs cannot be read or contain no usable data, so the caller can embed the
# output unconditionally and the page degrades gracefully.

import sys, os, re, gzip, glob, csv, bisect, html, datetime, urllib.request, ipaddress

DAYS = 14
SESSION_GAP = datetime.timedelta(minutes=30)

# Requests we don't count as human "visitors". Conservative: obvious crawlers,
# monitors and scripted clients. Empty UA ("-") is also dropped.
BOT_RE = re.compile(
    r"bot|crawl|spider|slurp|bingpreview|facebookexternalhit|embedly|"
    r"monitor|uptime|pingdom|statuscake|nagios|zabbix|"
    r"curl|wget|python-requests|go-http|libwww|httpclient|okhttp|"
    r"scan|nmap|masscan|semrush|ahrefs|mj12|dotbot|petalbot|dataprovider",
    re.I,
)

# Combined log: IP - - [10/Oct/2000:13:55:36 -0700] "GET / HTTP/1.0" 200 2326 "ref" "UA"
LINE_RE = re.compile(
    r'^(?P<ip>\S+)\s+\S+\s+\S+\s+\[(?P<ts>[^\]]+)\]\s+'
    r'"[^"]*"\s+\d{3}\s+\S+\s+"[^"]*"\s+"(?P<ua>[^"]*)"'
)
TS_FMT = "%d/%b/%Y:%H:%M:%S %z"

# Minimal CH-relevant country code -> (German name, flag emoji). Anything not
# listed falls back to the bare code; ZZ/unknown -> "Unbekannt".
CC_NAMES = {
    "CH": "Schweiz", "DE": "Deutschland", "AT": "Österreich", "FR": "Frankreich",
    "IT": "Italien", "LI": "Liechtenstein", "US": "USA", "GB": "Grossbritannien",
    "NL": "Niederlande", "BE": "Belgien", "ES": "Spanien", "PT": "Portugal",
    "PL": "Polen", "CZ": "Tschechien", "SE": "Schweden", "DK": "Dänemark",
    "NO": "Norwegen", "FI": "Finnland", "IE": "Irland", "RU": "Russland",
    "CN": "China", "IN": "Indien", "JP": "Japan", "BR": "Brasilien",
    "CA": "Kanada", "AU": "Australien", "UA": "Ukraine", "TR": "Türkei",
    "RO": "Rumänien", "HU": "Ungarn", "GR": "Griechenland", "LU": "Luxemburg",
}


def flag(cc):
    if not cc or len(cc) != 2 or cc == "ZZ" or not cc.isalpha():
        return "🏳"
    return chr(0x1F1E6 + ord(cc[0].upper()) - 65) + chr(0x1F1E6 + ord(cc[1].upper()) - 65)


def cc_label(cc):
    if not cc or cc == "ZZ":
        return ("🏳", "Unbekannt")
    return (flag(cc), CC_NAMES.get(cc, cc))


# ---------------------------------------------------------------- DB-IP CSV ---
def ensure_dbip(cache_dir):
    """Return path to a current DB-IP country-lite CSV, downloading if needed."""
    month = datetime.date.today().strftime("%Y-%m")
    path = os.path.join(cache_dir, f"dbip-country-lite-{month}.csv")
    if os.path.exists(path) and os.path.getsize(path) > 1_000_000:
        return path
    url = f"https://download.db-ip.com/free/dbip-country-lite-{month}.csv.gz"
    try:
        os.makedirs(cache_dir, exist_ok=True)
        req = urllib.request.Request(url, headers={"User-Agent": "oddb2xml-stats/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = gzip.decompress(r.read())
        tmp = path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
        # prune older months so the cache doesn't grow unbounded
        for old in glob.glob(os.path.join(cache_dir, "dbip-country-lite-*.csv")):
            if old != path:
                try:
                    os.remove(old)
                except OSError:
                    pass
        return path
    except Exception:
        # fall back to any cached copy we already have
        existing = sorted(glob.glob(os.path.join(cache_dir, "dbip-country-lite-*.csv")))
        return existing[-1] if existing else None


def load_geo(csv_path):
    """Load DB-IP CSV into sorted (start_int -> cc) tables for v4 and v6."""
    v4s, v4e, v4c, v6s, v6e, v6c = [], [], [], [], [], []
    with open(csv_path, newline="") as f:
        for row in csv.reader(f):
            if len(row) < 3:
                continue
            start, end, cc = row[0], row[1], row[2]
            try:
                if ":" in start:
                    v6s.append(int(ipaddress.IPv6Address(start)))
                    v6e.append(int(ipaddress.IPv6Address(end)))
                    v6c.append(cc)
                else:
                    v4s.append(int(ipaddress.IPv4Address(start)))
                    v4e.append(int(ipaddress.IPv4Address(end)))
                    v4c.append(cc)
            except ipaddress.AddressValueError:
                continue
    return (v4s, v4e, v4c, v6s, v6e, v6c)


def lookup(geo, ip_str):
    v4s, v4e, v4c, v6s, v6e, v6c = geo
    try:
        ip = ipaddress.ip_address(ip_str)
    except ValueError:
        return "ZZ"
    n = int(ip)
    if ip.version == 4:
        starts, ends, ccs = v4s, v4e, v4c
    else:
        starts, ends, ccs = v6s, v6e, v6c
    i = bisect.bisect_right(starts, n) - 1
    if 0 <= i < len(starts) and n <= ends[i]:
        return ccs[i] or "ZZ"
    return "ZZ"


# ------------------------------------------------------------------- parse ---
def open_log(path):
    return gzip.open(path, "rt", errors="replace") if path.endswith(".gz") \
        else open(path, "rt", errors="replace")


def parse_logs(log_glob, days):
    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
    # per day: set of IPs (visitors); per (ip,ua): sorted timestamps for sessions
    day_ips = {}            # "YYYY-MM-DD" -> set(ip)
    last_seen = {}          # (day, ip, ua) -> last datetime  (for session gaps)
    day_sessions = {}       # day -> session count
    all_ips = set()
    any_line = False

    files = sorted(glob.glob(log_glob))
    for path in files:
        try:
            fh = open_log(path)
        except OSError:
            continue
        with fh:
            for line in fh:
                m = LINE_RE.match(line)
                if not m:
                    continue
                ua = m.group("ua")
                if not ua or ua == "-" or BOT_RE.search(ua):
                    continue
                try:
                    ts = datetime.datetime.strptime(m.group("ts"), TS_FMT)
                except ValueError:
                    continue
                if ts.astimezone(datetime.timezone.utc) < cutoff:
                    continue
                any_line = True
                ip = m.group("ip")
                day = ts.strftime("%Y-%m-%d")
                day_ips.setdefault(day, set()).add(ip)
                all_ips.add(ip)
                key = (day, ip, ua)
                prev = last_seen.get(key)
                if prev is None or (ts - prev) > SESSION_GAP:
                    day_sessions[day] = day_sessions.get(day, 0) + 1
                last_seen[key] = ts
    if not any_line:
        return None
    return day_ips, day_sessions, all_ips


# ------------------------------------------------------------------ render ---
def esc(s):
    return html.escape(str(s), quote=True)


def render(day_ips, day_sessions, region_counts, days):
    today = datetime.date.today()
    span = [(today - datetime.timedelta(days=i)) for i in range(days - 1, -1, -1)]
    labels = [d.strftime("%Y-%m-%d") for d in span]
    visitors = [len(day_ips.get(l, ())) for l in labels]
    sessions = [day_sessions.get(l, 0) for l in labels]
    peak = max(visitors + sessions + [1])

    # geometry
    W, H = 760, 200
    pad_l, pad_r, pad_t, pad_b = 34, 12, 14, 34
    plot_w = W - pad_l - pad_r
    plot_h = H - pad_t - pad_b
    n = len(labels)
    slot = plot_w / n
    bw = min(slot * 0.36, 16)            # bar width per series
    gap = bw * 0.15

    def x_of(i):
        return pad_l + slot * i + slot / 2

    def y_of(v):
        return pad_t + plot_h - (v / peak) * plot_h

    parts = [f'<svg viewBox="0 0 {W} {H}" width="100%" role="img" '
             f'aria-label="Besucher und Sitzungen pro Tag" '
             f'style="max-width:{W}px;font-family:system-ui,sans-serif">']

    # y gridlines + labels (0, mid, peak)
    for frac in (0, 0.5, 1):
        val = round(peak * frac)
        y = y_of(val)
        parts.append(f'<line x1="{pad_l}" y1="{y:.1f}" x2="{W-pad_r}" y2="{y:.1f}" '
                     f'stroke="#e6ecf5" stroke-width="1"/>')
        parts.append(f'<text x="{pad_l-6}" y="{y+3:.1f}" text-anchor="end" '
                     f'font-size="9" fill="#9aa6b2">{val}</text>')

    # bars
    for i in range(n):
        cx = x_of(i)
        vx = cx - bw - gap / 2
        sx = cx + gap / 2
        vy, sy = y_of(visitors[i]), y_of(sessions[i])
        parts.append(f'<rect x="{vx:.1f}" y="{vy:.1f}" width="{bw:.1f}" '
                     f'height="{pad_t+plot_h-vy:.1f}" rx="1.5" fill="#0a58ca">'
                     f'<title>{esc(labels[i])}: {visitors[i]} Besucher</title></rect>')
        parts.append(f'<rect x="{sx:.1f}" y="{sy:.1f}" width="{bw:.1f}" '
                     f'height="{pad_t+plot_h-sy:.1f}" rx="1.5" fill="#7eb0f4">'
                     f'<title>{esc(labels[i])}: {sessions[i]} Sitzungen</title></rect>')
        # x label: short day (only every other if crowded)
        if n <= 16 or i % 2 == 0:
            parts.append(f'<text x="{cx:.1f}" y="{H-pad_b+13}" text-anchor="middle" '
                         f'font-size="9" fill="#7a8896">{esc(span[i].strftime("%d.%m"))}</text>')

    parts.append("</svg>")
    chart = "".join(parts)

    # legend
    legend = ('<div class="vs-legend">'
              '<span><i style="background:#0a58ca"></i>Besucher (eindeutige IP/Tag)</span>'
              '<span><i style="background:#7eb0f4"></i>Sitzungen (30-Min-Inaktivität)</span>'
              '</div>')

    # region bars
    total_ips = sum(c for _, c in region_counts) or 1
    rows = []
    for cc, cnt in region_counts:
        fl, name = cc_label(cc)
        pct = cnt / total_ips * 100
        rows.append(
            f'<div class="vs-row"><span class="vs-cc">{fl}&nbsp;{esc(name)}</span>'
            f'<span class="vs-bar"><i style="width:{pct:.1f}%"></i></span>'
            f'<span class="vs-num">{cnt}</span></div>')
    regions = ('<div class="vs-regions"><div class="vs-rt">Regionen (nach IP)</div>'
               + "".join(rows) + "</div>")

    tot_v = sum(visitors)
    tot_s = sum(sessions)
    style = (
        "<style>"
        ".vs-wrap{margin:.4rem 0 0}"
        ".vs-legend{display:flex;gap:1.2rem;flex-wrap:wrap;font-size:.8rem;color:#555;margin:.3rem 0 .8rem}"
        ".vs-legend i{display:inline-block;width:11px;height:11px;border-radius:2px;margin-right:.35rem;vertical-align:-1px}"
        ".vs-regions{margin-top:1rem;max-width:480px}"
        ".vs-rt{font-size:.85rem;color:#555;margin-bottom:.4rem}"
        ".vs-row{display:flex;align-items:center;gap:.6rem;margin:.18rem 0;font-size:.85rem}"
        ".vs-cc{flex:0 0 150px}"
        ".vs-bar{flex:1;background:#eef2f8;border-radius:4px;height:11px;overflow:hidden}"
        ".vs-bar i{display:block;height:100%;background:#0a58ca}"
        ".vs-num{flex:0 0 46px;text-align:right;color:#555;font-variant-numeric:tabular-nums}"
        "</style>"
    )
    return (
        f'{style}<h2>Zugriffe (letzte {days} Tage, ohne Bots)</h2>'
        f'<div class="vs-wrap">{legend}{chart}'
        f'<p class="desc">Summe: {tot_v} Besucher · {tot_s} Sitzungen · '
        f'{len(region_counts)} Regionen.</p>{regions}</div>'
    )


def main():
    if len(sys.argv) < 3:
        return 0
    log_glob, cache_dir = sys.argv[1], sys.argv[2]
    days = int(sys.argv[3]) if len(sys.argv) > 3 else DAYS

    parsed = parse_logs(log_glob, days)
    if not parsed:
        return 0                       # no readable/usable logs -> emit nothing
    day_ips, day_sessions, all_ips = parsed

    region_counts = []
    csv_path = ensure_dbip(cache_dir)
    if csv_path:
        geo = load_geo(csv_path)
        counts = {}
        for ip in all_ips:
            counts[lookup(geo, ip)] = counts.get(lookup(geo, ip), 0) + 1
        region_counts = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:6]

    sys.stdout.write(render(day_ips, day_sessions, region_counts, days))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)               # never break the page build
