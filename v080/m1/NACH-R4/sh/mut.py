#!/usr/bin/env python3
"""mut.py – unit-test mutations of QA-R4 B4 (U5, U8, R3) on a scratch copy of the HEAD tree (m1/NACH-R4/mut).
Each mutation: one-line change, run tests/run_tests.gd --filter=<file> headless (nice 10), record whether it fails,
restore the file. Also the unmutated run first (must pass). Output: mut/mutations.tsv and stdout."""
import os
import subprocess
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4"
T = S + "/mut"
MUTS = [
    ("none", None, None, None, "test_environment_rig"),
    ("none", None, None, None, "test_weather"),
    ("U5", "scripts/race3d/environment_rig.gd", "return EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M, d))",
     "return EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M * 40.0, d))", "test_environment_rig"),
    ("U5t", "scripts/race3d/environment_rig.gd", "if d < 0.0 or d >= EXIT_AFTER_M or dt >= EXIT_AFTER_S:",
     "if d < 0.0 or d >= EXIT_AFTER_M:", "test_environment_rig"),
    ("U8", "scripts/race3d/builders/terrain.gd", "const BANK_MAX_M := 0.45", "const BANK_MAX_M := 0.95", "test_weather"),
    ("R3", "scripts/race3d/builders/terrain.gd", "Vector2(0.75, 1.0)", "Vector2(0.75, 2.6)", "test_weather"),
    ("B1prof", "scripts/race3d/layers/flares.gd", "\tbuf[o + 2] = 1.0\n", "\tbuf[o + 2] = 0.0\n", "test_weather"),
    ("B5", "scripts/race3d/layers/weather.gd", "\t_particles.multimesh.visible_instance_count = mini(_count, _particles.multimesh.instance_count)\n",
     "\tpass\n", "test_weather"),
]
only = sys.argv[1:]
rows = []
for name, f, old, new, flt in MUTS:
    if only and name not in only:
        continue
    path = os.path.join(T, f) if f else None
    orig = None
    if path:
        orig = open(path, encoding="utf-8").read()
        if orig.count(old) != 1:
            print("%s: pattern found %d times – skipped" % (name, orig.count(old)))
            rows.append((name, flt, "skipped"))
            continue
        open(path, "w", encoding="utf-8").write(orig.replace(old, new))
    try:
        env = dict(os.environ, XDG_DATA_HOME=S + "/xdg/mut")
        os.makedirs(S + "/xdg/mut", exist_ok=True)
        p = subprocess.run(["nice", "-n", "19", "timeout", "600", "godot", "--headless", "--path", T, "-s",
                            "res://tests/run_tests.gd", "--", "--filter=" + flt], capture_output=True, text=True, env=env)
        out = p.stdout + p.stderr
        open(S + "/mut_%s_%s.log" % (name, flt), "w").write(out)
        fails = [l for l in out.splitlines() if "FAIL" in l or "FEHL" in l or "SCRIPT ERROR" in l]
        verdict = "FAILS (caught)" if p.returncode != 0 or fails else "passes"
        rows.append((name, flt, "%s exit=%d %s" % (verdict, p.returncode, " | ".join(fails[:2])[:300])))
    finally:
        if path:
            open(path, "w", encoding="utf-8").write(orig)
    print("\t".join(rows[-1]), flush=True)
with open(T + "/../mutations.tsv", "a") as fh:
    for r in rows:
        fh.write("\t".join(r) + "\n")
