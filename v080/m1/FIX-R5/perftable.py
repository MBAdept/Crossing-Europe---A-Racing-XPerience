#!/usr/bin/env python3
"""perftable.py <base.log> <new.log>: markdown table of the last PERF line of two run_stage logs."""
import json, sys


def perf(path):
    last = None
    run = None
    fail = ''
    for line in open(path, encoding='utf-8', errors='replace'):
        if line.startswith('PERF '):
            last = json.loads(line[5:])
        elif line.startswith('RUN '):
            run = json.loads(line[4:])
        elif line.startswith('FEHLER'):
            fail = line.strip()
        elif line.startswith('ERGEBNIS'):
            fail = fail or line.strip()[:120]
    return last, run, fail


rows = [
    ('Ende', lambda p, r, f: f or 'Ziel'),
    ('Wanduhr (s)', lambda p, r, f: '%.0f' % r['wall_s']),
    ('Spielzeit (s)', lambda p, r, f: '%.1f' % r['sim_s']),
    ('Bilder', lambda p, r, f: p['frames']),
    ('Bildzeit Median / p95 (ms, llvmpipe)', lambda p, r, f: '%.0f / %.0f' % (p['frame_ms_median'], p['frame_ms_p95'])),
    ('render() Mittel / max (ms)', lambda p, r, f: '%.2f / %.1f' % (p['render_ms_avg'], p['render_ms_max'])),
    ('sim_avg_ms / max (Lastmaß)', lambda p, r, f: '%.2f / %.0f' % (p['sim_avg_ms'], p['sim_max_ms'])),
    ('Stück-Commit Mittel / max (ms)', lambda p, r, f: '%.2f / %.2f' % (p['streamer']['commit_ms_avg'], p['streamer']['commit_ms_max'])),
    ('Stück-Bau Worker Mittel / max (ms)', lambda p, r, f: '%.1f / %.1f' % (p['streamer']['build_ms_avg'], p['streamer']['build_ms_max'])),
    ('Haken tunnel Mittel / max (ms)', lambda p, r, f: '%.3f / %.1f' % (p['hooks_ms_avg'].get('tunnel', 0), p['hooks_ms_max'].get('tunnel', 0))),
    ('Haken bridge Mittel / max (ms)', lambda p, r, f: '%.3f / %.1f' % (p['hooks_ms_avg'].get('bridge', 0), p['hooks_ms_max'].get('bridge', 0))),
    ('Haken far_ground Mittel / max (ms)', lambda p, r, f: '%.3f / %.1f' % (p['hooks_ms_avg'].get('far_ground', 0), p['hooks_ms_max'].get('far_ground', 0))),
    ('Zeichenaufrufe / Primitive (letztes Bild)', lambda p, r, f: '%d / %d' % (p['draw_calls'], p['primitives'])),
    ('Schatten-Primitive (letztes Bild)', lambda p, r, f: p['primitives_shadow']),
    ('Texturspeicher (MB)', lambda p, r, f: '%.1f' % p['tex_mem_mb']),
    ('prepare_ms', lambda p, r, f: '%.0f' % p['prepare_ms']),
]
a = perf(sys.argv[1])
b = perf(sys.argv[2])
print('| | Basis 5558bdc | FIX-R5 |')
print('|---|---|---|')
for name, fn in rows:
    vals = []
    for p, r, f in (a, b):
        try:
            vals.append(str(fn(p, r, f)))
        except Exception as e:  # missing key
            vals.append('–')
    print('| %s | %s | %s |' % (name, vals[0], vals[1]))
