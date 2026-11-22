"""R7b: Markdown table of the perf runs (gates/perf_<tree>_<stage>_<preset>.log), head next to base."""
import json
import re
import sys
from pathlib import Path

G = Path(sys.argv[1])
rows = []
for stage in ("kiel_hamburg", "dresden_leipzig"):
    for tree in ("base", "head"):
        f = G / f"perf_{tree}_{stage}_medium.log"
        if not f.exists():
            continue
        text = f.read_text(errors="replace")
        perf = {}
        run = {}
        for line in text.splitlines():
            if line.startswith("PERF {"):
                perf = json.loads(line[5:])
            elif line.startswith("RUN {"):
                run = json.loads(line[4:])
        errors = len(re.findall(r"SCRIPT ERROR|Parse Error|SHADER ERROR", text))
        st = perf.get("streamer", {})
        ha = perf.get("hooks_ms_avg", {})
        hm = perf.get("hooks_ms_max", {})
        rows.append((stage, tree, perf, run, errors, st, ha, hm))


def f(v, d=2):
    return "–" if v is None else (f"{v:.{d}f}" if isinstance(v, float) else str(v))


print("| Etappe | Stand | ok | Skriptfehler | render() Ø / max ms | Bild Median ms | Stück-Commit max ms | collect Ø / max ms "
      "| Draw Calls | Primitive | Textur MB | landmarks Ø / max ms | backdrop Ø / max ms | props Ø / max ms | Wand s |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for stage, tree, p, run, err, st, ha, hm in rows:
    print("| %s | %s | %s | %d | %s / %s | %s | %s | %s / %s | %s | %s | %s | %s / %s | %s / %s | %s / %s | %s |" % (
        stage, tree, run.get("ok"), err, f(p.get("render_ms_avg")), f(p.get("render_ms_max"), 1),
        f(p.get("frame_ms_median"), 1), f(p.get("chunk_commit_ms_max"), 1),
        f(st.get("collect_ms_avg")), f(st.get("collect_ms_max"), 1), p.get("draw_calls"), p.get("primitives"),
        f(p.get("tex_mem_mb"), 1), f(ha.get("landmarks"), 3), f(hm.get("landmarks"), 1), f(ha.get("backdrop"), 3),
        f(hm.get("backdrop"), 1), f(ha.get("props"), 3), f(hm.get("props"), 1), f(run.get("wall_s"), 0)))
