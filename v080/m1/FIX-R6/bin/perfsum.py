import json, sys
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6/perf/"
keys = ["render_ms_avg", "render_ms_max", "chunk_commit_ms_max", "chunk_build_ms_avg", "chunk_build_ms_max", "draw_calls",
        "primitives", "primitives_shadow", "instances", "frame_ms_median", "frame_ms_p95", "frames", "flares", "lights_omni", "lights_spot"]
for name in sys.argv[1:]:
    perf = None
    res = None
    for l in open(S + name + ".log"):
        if l.startswith("PERF "):
            perf = json.loads(l[5:])
        if l.startswith("ERGEBNIS "):
            res = json.loads(l[9:])
    if perf is None:
        print(name, "no PERF")
        continue
    out = {k: (round(perf[k], 2) if isinstance(perf.get(k), float) else perf.get(k)) for k in keys}
    hooks = perf.get("hooks_ms_avg", {})
    hmax = perf.get("hooks_ms_max", {})
    out["hooks_avg"] = {k: round(v, 3) for k, v in hooks.items() if k in ("gantry", "radar", "streamer", "flares", "lights", "props")}
    out["hooks_max"] = {k: round(v, 1) for k, v in hmax.items() if k in ("gantry", "radar", "streamer", "flares", "lights")}
    out["load"] = perf.get("load", {})
    out["time_s"] = res.get("time_s") if res else None
    out["collisions"] = res.get("collisions") if res else None
    print(name, json.dumps(out, ensure_ascii=False))
