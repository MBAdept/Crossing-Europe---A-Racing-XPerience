"""perf_table.py <perf_dir> : one line per QAPERF json (head/base, stage, mode, preset) and the memory trend."""
import json, glob, os, sys

d = sys.argv[1]
rows = []
for p in sorted(glob.glob(os.path.join(d, '*.json'))):
    try:
        j = json.load(open(p))
    except Exception as e:
        print('BROKEN', p, e)
        continue
    name = os.path.basename(p)[:-5]
    pf = j.get('perf', {})
    st = pf.get('streamer', {})
    dc = j.get('draw_calls', {}); dcs = j.get('draw_calls_shadow', {})
    pr = j.get('primitives', {}); prs = j.get('primitives_shadow', {})
    ft = j.get('frame_ms', {})
    hooks = pf.get('hooks_ms_max', {})
    hk = sorted(hooks.items(), key=lambda kv: -kv[1])[:3]
    cb = st.get('collect_by', {})
    cbm = sorted(((k, v.get('max_ms', 0), v.get('avg_ms', 0)) for k, v in cb.items()), key=lambda t: -t[1])[:3]
    mem = j.get('mem', [])
    print('== %s ok=%s km=%.1f sim=%.0fs wall=%.0fs frames=%d' % (name, j.get('ok'), j.get('km', 0), j.get('sim_s', 0), j.get('wall_s', 0), j.get('frames', 0)))
    print('   frame_ms p50 %.0f p95 %.0f p99 %.0f max %.0f' % (ft.get('p50', 0), ft.get('p95', 0), ft.get('p99', 0), ft.get('max', 0)))
    print('   draw calls vis avg %.0f p95 %.0f max %.0f | shadow avg %.0f p95 %.0f max %.0f | sum max %s' % (
        dc.get('avg', 0), dc.get('p95', 0), dc.get('max', 0), dcs.get('avg', 0), dcs.get('p95', 0), dcs.get('max', 0),
        '%.0f' % (dc.get('max', 0) + dcs.get('max', 0))))
    print('   primitives vis avg %.0fk p95 %.0fk max %.0fk | shadow avg %.0fk p95 %.0fk max %.0fk' % (
        pr.get('avg', 0) / 1e3, pr.get('p95', 0) / 1e3, pr.get('max', 0) / 1e3, prs.get('avg', 0) / 1e3, prs.get('p95', 0) / 1e3, prs.get('max', 0) / 1e3))
    print('   render_ms avg %.2f max %.2f | sim avg %.2f max %.2f | chunks build avg %.1f max %.1f | collect avg %.2f max %.2f | commit avg %.2f max %.2f (n %s)' % (
        pf.get('render_ms_avg', 0), pf.get('render_ms_max', 0), pf.get('sim_avg_ms', 0), pf.get('sim_max_ms', 0),
        st.get('build_ms_avg', 0), st.get('build_ms_max', 0), st.get('collect_ms_avg', 0), st.get('collect_ms_max', 0),
        st.get('commit_ms_avg', 0), st.get('commit_ms_max', 0), st.get('commits', '-')))
    print('   hooks max top3 %s | collect_by max top3 %s' % (
        ', '.join('%s %.2f' % kv for kv in hk), ', '.join('%s %.2f (avg %.3f)' % t for t in cbm)))
    print('   lights omni %s spot %s | lowered %s | fallback %s | prepare %.0f ms prewarm %.0f ms | iu max %s at km %.1f (%s samples)' % (
        pf.get('lights_omni', '-'), pf.get('lights_spot', '-'), pf.get('quality_lowered', '-'), pf.get('fallback_sets', '-'),
        pf.get('prepare_ms', 0), pf.get('prewarm_ms', 0), j.get('iu_instances_max', '-'), j.get('iu_instances_km', 0), j.get('iu_samples', '-')))
    if mem:
        a, b = mem[0], mem[-1]
        mid = mem[len(mem) // 2]
        def f(m):
            return 'w%.0f km%.1f obj %d nodes %d orph %d res %d tex %.0f buf %.0f vid %.0f static %.0f rss %.0f' % (
                m['wall_s'], m['km'], m['objects'], m['nodes'], m['orphans'], m['resources'], m['tex_mb'], m['buf_mb'],
                m['vid_mb'], m['static_mb'], m['rss_mb'])
        print('   mem first %s' % f(a))
        print('   mem mid   %s' % f(mid))
        print('   mem last  %s' % f(b))
        print('   mem max rss %.0f static %.0f vid %.0f' % (max(m['rss_mb'] for m in mem), max(m['static_mb'] for m in mem), max(m['vid_mb'] for m in mem)))
