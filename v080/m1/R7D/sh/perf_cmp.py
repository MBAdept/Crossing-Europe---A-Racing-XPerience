#!/usr/bin/env python3
"""R7D: perf runs of Kiel – Hamburg (autopilot, run_stage.gd), head against base per preset: perf_cmp.py <gates dir>"""
import json, sys, os
G = sys.argv[1]
def load(tree, pre):
    p = os.path.join(G, f"perf_{tree}_kiel_hamburg_{pre}.log")
    if not os.path.exists(p):
        return None
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("PERF "):
            return json.loads(line[5:])
    return None
keys = [("render() ms Mittel", lambda p: p["render_ms_avg"], "%.2f"), ("render() ms max", lambda p: p["render_ms_max"], "%.1f"),
        ("Bild ms Median", lambda p: p["frame_ms_median"], "%.0f"), ("Bild ms p95", lambda p: p["frame_ms_p95"], "%.0f"),
        ("Hintergrund-Haken ms Mittel/max", lambda p: "%.2f / %.2f" % (p["hooks_ms_avg"]["backdrop"], p["hooks_ms_max"]["backdrop"]), "%s"),
        ("Gelände-Haken ms Mittel/max", lambda p: "%.2f / %.2f" % (p["hooks_ms_avg"]["terrain"], p["hooks_ms_max"]["terrain"]), "%s"),
        ("Zeichenaufrufe", lambda p: p["draw_calls"], "%d"), ("Primitive", lambda p: p["primitives"], "%d"),
        ("Primitive Schatten", lambda p: p["primitives_shadow"], "%d"), ("Texturspeicher MB", lambda p: p["tex_mem_mb"], "%.1f"),
        ("Einhängen ms max", lambda p: p["streamer"]["commit_ms_max"], "%.2f"), ("Bauen ms max", lambda p: p["streamer"]["build_ms_max"], "%.1f"),
        ("Bilder", lambda p: p["frames"], "%d"), ("wall s", lambda p: p["wall_s"], "%.0f")]
for pre in ["deck", "medium", "high"]:
    h, b = load("head", pre), load("base", pre)
    print(f"\n### {pre}\n\n| Wert | Basis 720eaf4 | R7d |\n|---|---|---|")
    for name, f, fmt in keys:
        def v(p):
            if p is None:
                return "–"
            try:
                x = f(p)
                return fmt % x
            except Exception as e:
                return "?"
        print(f"| {name} | {v(b)} | {v(h)} |")
