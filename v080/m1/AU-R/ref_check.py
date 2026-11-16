#!/usr/bin/env python3
"""AU-R: the reference of match_loop must be AU-C1's loop – new generator f(n_old, 0) against the old generator's
f(n_old), sample by sample, for every layer in OLD_SECONDS and both slab loops."""
import importlib.util
import sys

import numpy as np

NEW = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1/tools/audio/modern/vehicle_loops.py"
OLD = sys.argv[1]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    sys.path.insert(0, path.rsplit("/", 1)[0])
    spec.loader.exec_module(m)
    sys.path.pop(0)
    return m


new = load(NEW, "vl_new")
old = load(OLD, "vl_old")
SR = new.SR
new_fn = {}
for row in new.loops():
    new_fn[row[0]] = row
old_fn = {}
for row in old.loops():
    old_fn[row[0]] = row
calls_new = {
    "tyre_asphalt": lambda n: new.tyre_asphalt(n, 0), "tyre_concrete": lambda n: new.tyre_concrete(n, 0),
    "tyre_deck": lambda n: new.tyre_deck(n, 0), "tyre_cobbles": lambda n: new.tyre_cobbles(n, 50.0, 0),
    "tyre_gravel": lambda n: new.tyre_gravel(n, 0), "tyre_grass": lambda n: new.tyre_grass(n, 0),
    "tyre_wet": lambda n: new.tyre_wet(n, 0), "tyre_rumble": lambda n: new.tyre_rumble(n, 100.0, 0),
    "wind_low": lambda n: new.wind_low(n, 0), "wind_mid": lambda n: new.wind_mid(n, 0),
    "wind_high": lambda n: new.wind_high(n, 0), "wind_buffet": lambda n: new.wind_buffet(n, 0),
}
for sid, sec in new.OLD_SECONDS.items():
    n = int(round(sec * SR))
    try:
        a = calls_new[sid](n)
    except TypeError as e:
        print(sid, "Aufruf:", e)
        continue
    b = old_fn[sid][2](n)
    k = min(len(a), len(b))
    d = float(np.max(np.abs(a[:k] - b[:k]))) if k else -1
    print(f"{sid:14s} n {len(a)}/{len(b)} max|neu-alt| {d:.3g}")
for kmh, seed in ((90.0, 2601), (180.0, 2701)):
    a = new.slab_loop(kmh, seed)
    b = old.slab_loop(kmh, seed)
    k = min(len(a), len(b))
    print(f"slab {kmh:.0f} n {len(a)}/{len(b)} max|neu-alt| {float(np.max(np.abs(a[:k] - b[:k]))):.3g}")
