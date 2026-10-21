"""Download SPY 1-minute bars from Massive (formerly Polygon.io) into the intraday CSV format.

Output columns: Time,Open,High,Low,Close
  Time = New York local minute END (09:31:00 .. 16:00:00), regular session only.
The API key is read from the MASSIVE_API_KEY environment variable (or the Windows user
environment, if this process started before `setx`). It is never printed.

Usage: python download_massive_1m.py [TICKER] [FROM yyyy-mm-dd] [TO yyyy-mm-dd] [OUT.csv]
"""
import datetime as dt, json, os, sys, time, urllib.request, urllib.error
from collections import defaultdict


def api_key():
    k = os.environ.get('MASSIVE_API_KEY')
    if not k and os.name == 'nt':
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as h:
                k = winreg.QueryValueEx(h, 'MASSIVE_API_KEY')[0]
        except OSError:
            pass
    if not k:
        sys.exit('MASSIVE_API_KEY is not set.')
    return k


def ny_offset(day):
    """US Eastern UTC offset in hours: DST from 2nd Sunday of March to 1st Sunday of November."""
    def nth_sunday(y, m, n):
        d = dt.date(y, m, 1)
        d += dt.timedelta(days=(6 - d.weekday()) % 7)
        return d + dt.timedelta(weeks=n - 1)
    return -4 if nth_sunday(day.year, 3, 2) <= day < nth_sunday(day.year, 11, 1) else -5


def to_ny(ms):
    utc = dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).replace(tzinfo=None)
    # Offset is decided by the NY date; bars between 06:00 and 21:00 UTC never straddle a switch.
    return utc + dt.timedelta(hours=ny_offset((utc - dt.timedelta(hours=5)).date()))


def fetch(ticker, start, end, key):
    url = (f'https://api.polygon.io/v2/aggs/ticker/{ticker}/range/1/minute/{start}/{end}'
           f'?adjusted=true&sort=asc&limit=50000')
    bars = []
    while url:
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {key}'})
        for attempt in range(6):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    data = json.load(r)
                break
            except urllib.error.HTTPError as e:
                if e.code == 429:            # free tier: 5 calls per minute
                    time.sleep(65); continue
                sys.exit(f'HTTP {e.code} for {start}..{end}: {e.read()[:200]!r}')
        else:
            sys.exit('Too many retries.')
        bars += data.get('results', [])
        url = data.get('next_url')
        time.sleep(12.5)                     # stay under 5 calls per minute
    return bars


def main():
    a = sys.argv[1:]
    ticker = a[0] if len(a) > 0 else 'SPY'
    end = dt.date.fromisoformat(a[2]) if len(a) > 2 else dt.date.today()
    start = dt.date.fromisoformat(a[1]) if len(a) > 1 else end - dt.timedelta(days=730)
    out = a[3] if len(a) > 3 else os.path.join(os.path.dirname(__file__), '..', 'data', 'massive', f'{ticker}_1m_{start:%Y%m%d}_{end:%Y%m%d}.csv')
    key = api_key()
    rows = {}
    s = start
    while s <= end:                          # ~45 calendar days per call keeps each under 50,000 bars
        e = min(end, s + dt.timedelta(days=44))
        got = fetch(ticker, s.isoformat(), e.isoformat(), key)
        for b in got:
            t_end = to_ny(b['t']) + dt.timedelta(minutes=1)
            if dt.time(9, 31) <= t_end.time() <= dt.time(16, 0):
                rows[t_end] = (b['o'], b['h'], b['l'], b['c'])
        print(f'{s}..{e}: {len(got)} bars', flush=True)
        s = e + dt.timedelta(days=1)
    by_day = defaultdict(list)
    for t in rows:
        by_day[t.date()].append(t)
    full, partial = [], []
    for d, ts in sorted(by_day.items()):
        (full if len(ts) == 390 and max(ts).time() == dt.time(16, 0) else partial).append(d)
    with open(out, 'w', newline='') as f:
        f.write('Time,Open,High,Low,Close\n')
        for d in full:                       # complete sessions only; the backtest rejects gaps
            for t in sorted(by_day[d]):
                o, h, l, c = rows[t]
                f.write(f'{t:%Y-%m-%d %H:%M:%S},{o},{max(h, o, c)},{min(l, o, c)},{c}\n')
    print(f'Wrote {out}: {len(full)} full sessions, {len(full) * 390} rows')
    print(f'Dropped {len(partial)} incomplete sessions (early closes or missing minutes):')
    for d in partial:
        print(f'  {d}: {len(by_day[d])} bars, last {max(by_day[d]).time()}')


if __name__ == '__main__':
    main()
