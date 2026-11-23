#!/usr/bin/env python3
"""perfsum.py <log>...: the perf_stats numbers of run_stage logs (one line each) and the md5 of ERGEBNIS without gfx."""
import hashlib
import json
import sys

for path in sys.argv[1:]:
    perf = res = None
    errs = 0
    for line in open(path, errors='replace'):
        if line.startswith('PERF '):
            perf = json.loads(line[5:])
        elif line.startswith('ERGEBNIS '):
            res = json.loads(line[9:])
        if 'SCRIPT ERROR' in line:
            errs += 1
    if perf is None:
        print(path, 'kein PERF')
        continue
    r = dict(res or {})
    r.pop('gfx', None)
    md5 = hashlib.md5(json.dumps(r, sort_keys=True).encode()).hexdigest()[:10]
    st = perf.get('streamer', {})
    ha = perf.get('hooks_ms_avg', {})
    hm = perf.get('hooks_ms_max', {})
    print('%s: render avg %.2f max %.1f | commit max %.1f | collect avg %.2f max %.1f | draw %d prim %d | '
          'landmarks %.3f/%.2f backdrop %.3f/%.2f camera %.3f/%.2f | frame median %.0f ms | script errors %d | ERGEBNIS %s' % (
              path.split('/')[-1], perf['render_ms_avg'], perf['render_ms_max'], st.get('commit_ms_max', 0.0),
              st.get('collect_ms_avg', 0.0), st.get('collect_ms_max', 0.0), perf['draw_calls'], perf['primitives'],
              ha.get('landmarks', 0), hm.get('landmarks', 0), ha.get('backdrop', 0), hm.get('backdrop', 0),
              ha.get('camera', 0), hm.get('camera', 0), perf.get('frame_ms_median', 0), errs, md5))
