#!/usr/bin/env python3
"""R7D final perf: medians of three rounds per tree and preset (gates/perf3/), and the head without the new sky.
perf3_cmp.py <perf3 dir>"""
import json, sys, os, statistics as st
G = sys.argv[1]
def load(tag):
    p = os.path.join(G, tag + ".log")
    if not os.path.exists(p):
        return None
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            return json.loads(line[5:])
    return None
keys = [("render() ms Mittel", lambda p: p["render_ms_avg"], "%.2f"),
        ("render() ms max", lambda p: p["render_ms_max"], "%.1f"),
        ("Bild ms Median (llvmpipe)", lambda p: p["frame_ms_median"], "%.0f"),
        ("Bild ms p95 (llvmpipe)", lambda p: p["frame_ms_p95"], "%.0f"),
        ("Haken Hintergrund ms Mittel", lambda p: p["hooks_ms_avg"]["backdrop"], "%.2f"),
        ("Haken Gelände ms Mittel", lambda p: p["hooks_ms_avg"]["terrain"], "%.2f"),
        ("Zeichenaufrufe", lambda p: p["draw_calls"], "%d"),
        ("Primitive", lambda p: p["primitives"], "%d"),
        ("Primitive Schatten", lambda p: p["primitives_shadow"], "%d"),
        ("Texturspeicher MB", lambda p: p["tex_mem_mb"], "%.1f"),
        ("Einhängen ms max", lambda p: p["streamer"]["commit_ms_max"], "%.2f"),
        ("wall s", lambda p: p["wall_s"], "%.0f")]
def med(tags, f):
    vals = []
    for t in tags:
        p = load(t)
        if p is not None:
            try:
                vals.append(float(f(p)))
            except Exception:
                pass
    return (st.median(vals), len(vals)) if vals else (None, 0)
for pre in ["deck", "medium", "high"]:
    cols = [("Basis 720eaf4", [f"base_{pre}_r{r}" for r in (1, 2, 3)]), ("R7d 6092197", [f"head_{pre}_r{r}" for r in (1, 2, 3)])]
    if pre != "high":
        cols.append(("R7d ohne neuen Himmel", [f"skyoff_{pre}_r{r}" for r in (1, 2, 3)]))
    print(f"\n### {pre} (Median aus drei Läufen)\n")
    print("| Wert | " + " | ".join(c[0] for c in cols) + " |")
    print("|---|" + "---|" * len(cols))
    for name, f, fmt in keys:
        row = []
        for _, tags in cols:
            v, n = med(tags, f)
            row.append("–" if v is None else (fmt % v) + ("" if n == 3 else f" ({n})"))
        print(f"| {name} | " + " | ".join(row) + " |")
