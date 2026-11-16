#!/usr/bin/env python3
"""AU-R2 (M5): where do the standout peaks of the cobble loops come from? Crest of the raw generator output, after
match_loop, after normalisation; the events (wheel, strength, rattle) within 4 ms of the loudest peaks.
usage: cobble_diag.py <repo_root>"""
import math
import os
import sys

import numpy as np

S = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
SR = 44100


def crest(y):
    return 20 * math.log10(np.max(np.abs(y)) / np.sqrt(np.mean(y * y)))


def top_peaks(y, k=5, gap=0.02):
    a = np.abs(y)
    r = np.sqrt(np.mean(y * y))
    out = []
    for i in np.argsort(a)[::-1]:
        if len(out) >= k:
            break
        if any(abs(int(i) - j) < gap * SR for j, _ in out):
            continue
        out.append((int(i), round(20 * math.log10(a[i] / r), 2)))
    return out


def main():
    repo = sys.argv[1]
    sys.path.insert(0, os.path.join(repo, "tools", "audio", "modern"))
    import vehicle_loops as vl  # noqa: E402
    ref_heard = vl.heard(vl.tyre_cobbles(int(round(2.5 * SR)), 50.0, 0), vl.OLD_PAN["MRoad"])
    old = vl.tyre_cobbles(int(round(2.5 * SR)), 50.0, 0)
    print(f"AU-C1 raw crest {crest(old):.2f}  heard {crest(ref_heard):.2f}  top {top_peaks(old, 3)}")
    for sec, s in ((5.7, 0), (7.1, vl.SIDE_B)):
        n = int(round(sec * SR))
        raw = vl.tyre_cobbles(n, 50.0, s)
        m = vl.match_loop(raw, ref_heard)
        print(f"side s={s}: raw crest {crest(raw):.2f} top {top_peaks(raw, 4)} | matched crest {crest(m):.2f} top {top_peaks(m, 4)}")
        # components: hits (thud+click), rattle, body – rebuild with the generator's draws
        rng = np.random.default_rng(1401 + s)
        v = 50.0 / 3.6
        rate = v / 0.115
        out = np.zeros(n)
        rat = np.zeros(n)
        hits = np.zeros(n)
        ev = []
        for wheel in range(4):
            gain = (1.0, 0.95, 0.8, 0.75)[wheel]
            count = int(round(rate * n / SR))
            base = rng.uniform(0.0, n / count)
            for k in range(count):
                t = base + k * n / count + rng.uniform(-0.2, 0.2) * n / count
                at = int(t) % n
                d = float(rng.normal(0.0, 0.38))
                a = gain * float(np.exp(d))
                f0 = rng.uniform(180.0, 260.0)
                clip = vl.mixc((1.0, vl.decay_sine(f0, 0.0035, 0.02, rng.uniform(0, 6.28))),
                               (0.3, vl.noise_burst(rng, 0.006, 900.0, 3200.0, 0.0008)))
                vl.place(out, clip, at, a)
                hits[at] += a
                r = False
                if rng.random() < 0.06:
                    vl.place(rat, vl.noise_burst(rng, 0.03, 2800.0, 6000.0, 0.006), at, 0.25 * a)
                    r = True
                ev.append((at, wheel, round(d, 2), r))
        body = vl.cfilter(hits, lambda f: vl.bp(f, 25.0, 90.0, 2) * vl.peak(f, 48.0, 3.0, 6.0))
        tot = out + rat
        sc = vl.rms(tot)
        body = body / vl.rms(body)
        y = tot / sc + 0.55 * body
        print(f"   check rebuild = raw: {float(np.max(np.abs(y - raw))):.2e}; crest hits {crest(out):.2f} rattle-only peak "
              f"{20 * math.log10(np.max(np.abs(rat)) / sc + 1e-12):.2f} dB re total RMS, body crest {crest(body):.2f}")
        for i, db in top_peaks(m, 4):
            near = [e for e in ev if 0 <= (i - e[0]) % n < int(0.004 * SR) or 0 <= (e[0] - i) % n < int(0.001 * SR)]
            print(f"   peak at {i / SR:.3f} s ({db:+.2f} dB re RMS): events {near} | hits {out[i] / sc:+.2f} rattle {rat[i] / sc:+.2f} "
                  f"body {0.55 * body[i]:+.2f} (re total RMS)")


if __name__ == "__main__":
    main()
