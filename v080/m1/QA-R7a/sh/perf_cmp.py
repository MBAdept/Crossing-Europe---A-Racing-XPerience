#!/usr/bin/env python3
"""R7a: PERF lines of tests/race/run_stage.gd side by side.  perf_cmp.py <log>..."""
import json
import os
import sys

KEYS = ["render_ms_avg", "render_ms_max", "frame_ms_median", "frame_ms_p95", "frames", "streamer.collect_ms_avg",
        "streamer.collect_ms_max", "streamer.commit_ms_max", "load.collect_ms_avg", "load.collect_ms_max",
        "load.commit_ms_max", "chunk_build_ms_avg", "chunk_build_ms_max", "streamer.corridor_warm_ms_avg",
        "streamer.corridor_warm_ms_max", "streamer.corridor_sync_ms_max", "streamer.corridor_sync_ms_sum", "streamer.corridor_sync_calls", "streamer.commit_ms_avg", "streamer.update_ms_max.collect", "hooks_ms_avg.props", "hooks_ms_max.props", "hooks_ms_avg.streamer",
        "hooks_ms_max.streamer", "draw_calls", "primitives", "primitives_shadow", "prepare_ms", "prewarm_ms"]


def flat(d, pre=""):
    out = {}
    for k, v in d.items():
        if isinstance(v, dict):
            out.update(flat(v, pre + k + "."))
        else:
            out[pre + k] = v
    return out


rows = {}
for p in sys.argv[1:]:
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            rows[os.path.basename(p)[:-4]] = flat(json.loads(line[5:]))
        if line.startswith("RUN "):
            r = json.loads(line[4:])
            rows.setdefault(os.path.basename(p)[:-4], {})["wall_s"] = r.get("wall_s")
names = list(rows)
print("| Wert | " + " | ".join(names) + " |")
print("|---|" + "---|" * len(names))
for k in KEYS + ["wall_s"]:
    vals = []
    for n in names:
        v = rows[n].get(k)
        vals.append("–" if v is None else ("%.2f" % v if isinstance(v, float) else str(v)))
    print("| %s | %s |" % (k, " | ".join(vals)))
