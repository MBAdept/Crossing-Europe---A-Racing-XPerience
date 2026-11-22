"""perf_md.py <perf_dir> : markdown table rows of all QAPERF jsons (one row per run)."""
import json, glob, os, sys

d = sys.argv[1]
print('| Lauf (Stand, Etappe, Voreinst.) | Bilder | Bild p50 / p95 ms | Draw-Calls Ø / p95 / max | Primitive Ø / p95 / max (k) | Schatten-Primitive max (k) | `render()` Ø / max ms | Einhängen max ms | collect() max ms (Baustein) | Instanzuniform max | RSS Ende MB | Textur / Video MB |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|')
for p in sorted(glob.glob(os.path.join(d, '*.json'))):
    try:
        j = json.load(open(p))
    except Exception:
        continue
    n = os.path.basename(p)[:-5]
    pf = j.get('perf', {})
    st = pf.get('streamer', {})
    ft, dc, pr, prs = j.get('frame_ms', {}), j.get('draw_calls', {}), j.get('primitives', {}), j.get('primitives_shadow', {})
    cb = st.get('collect_by', {})
    top = max(cb.items(), key=lambda kv: kv[1].get('max_ms', 0)) if cb else None
    mem = j.get('mem', [])
    last = mem[-1] if mem else {}
    print('| %s | %d | %.0f / %.0f | %.0f / %.0f / %.0f | %.0f / %.0f / %.0f | %.0f | %.2f / %.1f | %.2f | %s | %s | %s | %s |' % (
        n, j.get('frames', 0), ft.get('p50', 0), ft.get('p95', 0), dc.get('avg', 0), dc.get('p95', 0), dc.get('max', 0),
        pr.get('avg', 0) / 1e3, pr.get('p95', 0) / 1e3, pr.get('max', 0) / 1e3, prs.get('max', 0) / 1e3,
        pf.get('render_ms_avg', 0), pf.get('render_ms_max', 0), st.get('commit_ms_max', 0),
        ('%.2f (%s)' % (top[1].get('max_ms', 0), top[0])) if top else '–', j.get('iu_instances_max', '–'),
        ('%.0f' % last.get('rss_mb', 0)) if last.get('rss_mb') else '–',
        ('%.0f / %.0f' % (last.get('tex_mb', 0), last.get('vid_mb', 0))) if last else '–'))
