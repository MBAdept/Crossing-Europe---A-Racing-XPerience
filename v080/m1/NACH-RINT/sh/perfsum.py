"""perfsum.py <log> : the budget numbers of a stage_shots.gd run (PERF line)."""
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if not line.startswith("PERF "):
        continue
    p = json.loads(line[5:])
    st = p.get("streamer", {})
    print("BUDGET preset=%s frames=%s render_ms_avg=%.2f render_ms_max=%.2f commit_ms_max=%.2f commit_ms_avg=%.2f steps=%s commits=%s collect_ms_max=%.2f draw=%s prim=%s frame_med=%.1f p95=%.1f" % (
        p.get("preset"), p.get("frames"), p.get("render_ms_avg", 0), p.get("render_ms_max", 0), st.get("commit_ms_max", 0),
        st.get("commit_ms_avg", 0), st.get("commit_steps"), st.get("commits"), st.get("collect_ms_max", 0),
        p.get("draw_calls"), p.get("primitives"), p.get("frame_ms_median", 0), p.get("frame_ms_p95", 0)))
    print("UPDATE_MS_MAX " + json.dumps(st.get("update_ms_max", {}), sort_keys=True))
    print("COMMIT_BY_MAX " + json.dumps({k: v.get("max_ms") for k, v in st.get("commit_by", {}).items()}, sort_keys=True))
    print("COLLECT_BY_MAX " + json.dumps({k: v.get("max_ms") for k, v in st.get("collect_by", {}).items()}, sort_keys=True))
    print("SPIKES " + json.dumps(p.get("spikes", [])))
    print("HOOKS_MAX " + json.dumps(p.get("hooks_ms_max", {}), sort_keys=True))
    print("HOOKS_AVG " + json.dumps(p.get("hooks_ms_avg", {}), sort_keys=True))
