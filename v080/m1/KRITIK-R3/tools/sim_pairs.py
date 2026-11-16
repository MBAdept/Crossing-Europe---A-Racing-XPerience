#!/usr/bin/env python3
"""KRITIK-R3: how often would the new pick_variant check of test_collision_variety (400 draws, n = 4, every successor
share 0.20-0.47) fail for a CORRECT random picker at an arbitrary seed? (The test uses seed 7 – deterministic.)"""
import numpy as np
rng = np.random.default_rng(12345)
trials = 20000
fail = 0
for t in range(trials):
    v = -1
    draws = []
    for i in range(400):
        if v < 0:
            v = int(rng.integers(0, 4))
        else:
            w = int(rng.integers(0, 3))
            v = w + 1 if w >= v else w
        draws.append(v)
    pairs = np.zeros((4, 4))
    for a, b in zip(draws[:-1], draws[1:]):
        pairs[a, b] += 1
    ok = True
    for a in range(4):
        tot = pairs[a].sum()
        for b in range(4):
            if b != a:
                s = pairs[a, b] / max(tot, 1)
                if not (0.2 <= s <= 0.47):
                    ok = False
    fail += 0 if ok else 1
print(f"correct picker, arbitrary seed: {fail} of {trials} fail ({100.0 * fail / trials:.2f} %)")
