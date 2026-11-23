#!/usr/bin/env python3
"""FIX-R7c: markdown table of the run_stage PERF/ERGEBNIS lines in m1/FIX-R7c/perf (or argv[1])."""
import glob, json, os, sys

d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/perf"
print("| Lauf | Bildzeit Median / p95 ms | render() Mittel / Max ms | Stück einhängen Max ms | collect() Mittel / Max ms | collect props Max ms | Haken props Mittel / Max ms | Zeichenaufrufe | Primitive / Schatten | Fehler | ERGEBNIS time_s |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for f in sorted(glob.glob(d + "/*.log")):
    tag = os.path.basename(f)[:-4]
    perf = erg = None
    errs = 0
    for line in open(f, errors="replace"):
        if line.startswith("PERF "):
            perf = json.loads(line[5:])
        elif line.startswith("ERGEBNIS "):
            erg = json.loads(line[9:])
        elif "SCRIPT ERROR" in line or "SHADER ERROR" in line:
            errs += 1
    if perf is None:
        print("| %s | – (kein PERF) |" % tag)
        continue
    st = perf.get("streamer", {})
    cb = st.get("collect_by", {}).get("props", {})
    ha = perf.get("hooks_ms_avg", {})
    hm = perf.get("hooks_ms_max", {})
    print("| %s | %.0f / %.0f | %.2f / %.2f | %.2f | %.2f / %.2f | %.3f | %.3f / %.2f | %d | %d / %d | %d | %.1f |" % (
        tag, perf.get("frame_ms_median", 0), perf.get("frame_ms_p95", 0), perf.get("render_ms_avg", 0), perf.get("render_ms_max", 0),
        perf.get("chunk_commit_ms_max", 0), st.get("collect_ms_avg", 0), st.get("collect_ms_max", 0), cb.get("max_ms", 0),
        float(ha.get("props", 0)), float(hm.get("props", 0)), perf.get("draw_calls", 0), perf.get("primitives", 0),
        perf.get("primitives_shadow", 0), errs, float(erg.get("time_s", 0)) if erg else -1))
