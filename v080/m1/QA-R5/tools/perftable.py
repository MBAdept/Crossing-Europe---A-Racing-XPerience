#!/usr/bin/env python3
"""Perf table (markdown) from logs/perf_{kh,u1}_{r5,base}.log."""
import json, re
Q = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5/logs/'


def load(name):
    try:
        txt = open(Q + 'perf_%s.log' % name).read()
    except OSError:
        return None
    perf = run = None
    km = None
    for l in txt.splitlines():
        if l.startswith('PERF '):
            perf = json.loads(l[5:])
        elif l.startswith('RUN '):
            run = json.loads(l[4:])
        m = re.match(r'\.\.\. km ([0-9.]+)', l)
        if m:
            km = float(m.group(1))
    m = re.search(r'Zeitlimit überschritten bei km ([0-9.]+)', txt)
    if m:
        km = float(m.group(1))
    return perf, run, km


rows = [
    ('Strecke erreicht (km)', lambda p, r, k: '%.1f%s' % (k or 0, '' if not r or r.get('ok') else ' (Zeitlimit)')),
    ('Bilder', lambda p, r, k: str(p.get('frames'))),
    ('`render()` Mittel / max (ms)', lambda p, r, k: '%.2f / %.1f' % (p['render_ms_avg'], p['render_ms_max'])),
    ('Bildzeit Median / p95 (ms, llvmpipe)', lambda p, r, k: '%.0f / %.0f' % (p['frame_ms_median'], p['frame_ms_p95'])),
    ('`sim_avg_ms` / max (Lastmaß, R5 berührt es nicht)', lambda p, r, k: '%.2f / %.0f' % (p.get('sim_avg_ms', 0), p.get('sim_max_ms', 0))),
    ('Haken `bridge` Mittel / max (ms)', lambda p, r, k: '%.3f / %.1f' % (p['hooks_ms_avg'].get('bridge', 0), p['hooks_ms_max'].get('bridge', 0)) if 'bridge' in p['hooks_ms_avg'] else '–'),
    ('Haken `tunnel` Mittel / max (ms)', lambda p, r, k: '%.3f / %.1f' % (p['hooks_ms_avg'].get('tunnel', 0), p['hooks_ms_max'].get('tunnel', 0))),
    ('Haken `far_ground` Mittel / max (ms)', lambda p, r, k: '%.3f / %.1f' % (p['hooks_ms_avg'].get('far_ground', 0), p['hooks_ms_max'].get('far_ground', 0))),
    ('Stück-Bau Worker Mittel / max (ms)', lambda p, r, k: '%.1f / %.1f' % (p['chunk_build_ms_avg'], p['chunk_build_ms_max'])),
    ('`chunk_commit_ms_max` (Budget deck 3 ms)', lambda p, r, k: '%.2f' % p['chunk_commit_ms_max']),
    ('Zeichenaufrufe / Primitive (letztes Bild; Budget deck 650 / 450 000)', lambda p, r, k: '%s / %s' % (p['draw_calls'], p['primitives'])),
    ('Schatten-Primitive (letztes Bild)', lambda p, r, k: str(p.get('primitives_shadow'))),
    ('Texturspeicher (MB)', lambda p, r, k: '%.1f' % p['tex_mem_mb'] if p.get('tex_mem_mb') is not None else '–'),
    ('Vorbereitung `prepare_ms`', lambda p, r, k: '%.1f s' % (p['prepare_ms'] / 1000.0)),
    ('Wanduhr (s)', lambda p, r, k: '%.0f' % r['wall_s'] if r else '–'),
]
out = []
for stage, title in [('kh', 'Kiel – Hamburg ab km 76 (Köhlbrandbrücke, Elbbrücken), 12 Uhr, Seed 11'),
                     ('u1', 'Bern – Mailand ab km 183 (Gotthard-Portal und Röhre), 12 Uhr, Seed 16')]:
    a = load(stage + '_base')
    b = load(stage + '_r5')
    out.append('**%s**\n' % title)
    out.append('| | Basis 6e48405 | R5 5558bdc |')
    out.append('|---|---|---|')
    for name, f in rows:
        def cell(x):
            if x is None or x[0] is None:
                return '(fehlt)'
            try:
                return f(*x)
            except Exception as e:
                return '?'
        out.append('| %s | %s | %s |' % (name, cell(a), cell(b)))
    out.append('')
print('\n'.join(out))
