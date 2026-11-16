#!/usr/bin/env python3
"""AU-R2 (M5, as KRITIK-R section 3): single peaks of a layer recording per channel – crest (sample peak / RMS),
the loudest peaks (dB re the channel RMS, at least 20 ms apart) with their times, the 99.9 % and 99 % quantiles of
|x| over RMS, the true peak of the recording (4x) – before against after.
usage: ana_peaks.py <before.wav> <after.wav> [out.json]"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

SR = 44100


def per_channel(x):
    out = {"tp": round(dsp.tp(x), 2)}
    for ch, nm in ((0, "L"), (1, "R")):
        c = np.asarray(x[:, ch], np.float64)
        r = float(np.sqrt(np.mean(c * c)))
        a = np.abs(c)
        top = []
        taken = []
        for i in np.argsort(a)[::-1]:
            if len(top) >= 6:
                break
            if any(abs(int(i) - j) < int(0.02 * SR) for j in taken):
                continue
            taken.append(int(i))
            top.append([round(i / SR, 2), round(20 * math.log10(a[i] / r), 2)])
        out[nm] = {"rms_db": round(20 * math.log10(r), 2), "peak_dbfs": round(20 * math.log10(a.max()), 2),
                   "crest": round(20 * math.log10(a.max() / r), 2), "q999": round(20 * math.log10(np.quantile(a, 0.999) / r), 2),
                   "q99": round(20 * math.log10(np.quantile(a, 0.99) / r), 2), "top": top}
    return out


def main():
    b, a = sys.argv[1], sys.argv[2]
    xb, _ = dsp.load(b)
    xa, _ = dsp.load(a)
    rb, ra = per_channel(xb), per_channel(xa)
    res = {"before": rb, "after": ra}
    print(f"True Peak der Aufnahme {rb['tp']} -> {ra['tp']} dBTP")
    for nm in ("L", "R"):
        p, q = rb[nm], ra[nm]
        # loudest peak relative to the loudest of before, at the same channel RMS
        d_top = (q["top"][0][1]) - (p["top"][0][1])
        res[nm + "_loudest_vs_before_db"] = round(d_top + (q["rms_db"] - p["rms_db"]), 2)
        print(f"  {nm}: crest {p['crest']} -> {q['crest']} dB ({q['crest'] - p['crest']:+.2f}); q99.9 {p['q999']} -> {q['q999']}; "
              f"q99 {p['q99']} -> {q['q99']}; RMS {p['rms_db']} -> {q['rms_db']} dBFS; lautester Stein gegen vorher "
              f"{res[nm + '_loudest_vs_before_db']:+.2f} dB")
        print(f"      vorher: {p['top']}")
        print(f"      nachher: {q['top']}")
    if len(sys.argv) > 3:
        json.dump(res, open(sys.argv[3], "w"), indent=1)


if __name__ == "__main__":
    main()
