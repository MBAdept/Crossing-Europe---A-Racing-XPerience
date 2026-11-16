#!/usr/bin/env python3
"""KRITIK-R (R3): phase of the two slab loops while both are audible.
 A) playback positions (per frame, from the engine): offset = (share_fast - share_slow) of the 32-slab loop, in ms
 B) the audio itself: slow design on MRoad, fast design on MWind, recorded apart in the same mix blocks; per 0.4-s
    window where both are within 20 dB of each other, the lag of the largest cross-correlation of the onset envelopes
    (1-ms RMS of the 1-kHz high-passed signal, +-60 ms) = how far the hits of the two loops lie apart.
usage: ana_slab.py <base> <out.json>   (base = .../slab/after -> after_slow.f32, after_fast.f32, after.json)"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402
from ana_cap import load_f32  # noqa: E402

SR = 44100


def onset_env(x):
    m = dsp.mono(x)
    y = dsp.zero_phase(m, SR, dsp.hp_mag(1000.0, 2))
    k = 44
    n = len(y) // k
    return np.sqrt(np.mean(y[:n * k].reshape(n, k) ** 2, axis=1))   # ~1-ms frames


def main():
    base, out = sys.argv[1], sys.argv[2]
    meta = json.load(open(base + ".json"))
    s = load_f32(base + "_slow.f32")
    f = load_f32(base + "_fast.f32")
    n = min(len(s), len(f))
    s, f = s[:n], f[:n]
    rows = meta["rows"]
    len_slow = float(meta["len_slow"])
    # A) positions
    offs = []
    for r in rows:
        t, v, sf, ff, sh_s, sh_f, lv_s, lv_f, p_s, p_f = r
        if sh_s < 0 or sh_f < 0:
            continue
        d = ((sh_f - sh_s + 0.5) % 1.0) - 0.5
        period = len_slow / max(p_s, 0.01)
        offs.append((t, v, d * period * 1000.0, lv_s, lv_f))
    A = {"rows_both_playing": len(offs)}
    if offs:
        o = np.array([abs(x[2]) for x in offs])
        A.update({"max_ms": round(float(o.max()), 2), "p95_ms": round(float(np.percentile(o, 95)), 2),
                  "median_ms": round(float(np.median(o)), 2), "share_over_6ms": round(float((o > 6.0).mean()), 4),
                  "share_over_10ms": round(float((o > 10.0).mean()), 4)})
    # B) audio
    es, ef = onset_env(s), onset_env(f)
    win = 400
    hop = 200
    lagmax = 60
    res = []
    for i in range(0, min(len(es), len(ef)) - win - 2 * lagmax, hop):
        a = es[i + lagmax:i + lagmax + win]
        b_full = ef[i:i + win + 2 * lagmax]
        ra, rb = np.sqrt(np.mean(a ** 2)), np.sqrt(np.mean(b_full ** 2))
        if ra < 1e-4 or rb < 1e-4:
            continue
        rel_db = 20 * np.log10(rb / ra)
        if abs(rel_db) > 20:
            continue
        a0 = a - a.mean()
        best, bl = -2.0, 0
        for L in range(-lagmax, lagmax + 1):
            b = b_full[lagmax + L:lagmax + L + win]
            b0 = b - b.mean()
            c = float(np.dot(a0, b0) / (np.linalg.norm(a0) * np.linalg.norm(b0) + 1e-12))
            if c > best:
                best, bl = c, L
        t_s = (i + lagmax) * 44 / SR
        res.append((round(t_s, 2), bl, round(best, 3), round(rel_db, 1)))
    B = {"windows": len(res)}
    if res:
        lags = np.array([abs(r[1]) for r in res])
        cc = np.array([r[2] for r in res])
        B.update({"max_ms": int(lags.max()), "median_ms": float(np.median(lags)), "share_over_3ms": round(float((lags > 3).mean()), 3),
                  "share_over_10ms": round(float((lags > 10).mean()), 3), "corr_median": round(float(np.median(cc)), 3),
                  "worst": sorted(res, key=lambda r: -abs(r[1]))[:6]})
    resj = {"positions": A, "audio": B, "realigned": meta.get("realigned"), "samples": n, "seconds": round(n / SR, 1),
            "audio_windows": res, "offsets": [(round(t, 2), round(v, 1), round(d, 2)) for t, v, d, _a, _b in offs]}
    json.dump(resj, open(out, "w"), indent=0)
    print(f"{base}: Spielpositionen {A} | Ton {({k: v for k, v in B.items() if k != 'worst'})} | nachgestellt {meta.get('realigned')}")
    print("   größte Versätze im Ton (t s, ms, Korrelation, fast-slow dB):", B.get("worst"))


if __name__ == "__main__":
    main()
