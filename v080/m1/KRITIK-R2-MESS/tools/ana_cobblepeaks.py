#!/usr/bin/env python3
"""KRITIK-R2-MESS: single stones of the cobble layer (50 km/h, road only, no drift) over several runs per head:
per channel the loudest peak (dBFS and dB over the channel RMS = crest), the 99.9 % quantile over RMS, the true peak of
the recording; the loudest stone of each run (sample peak per channel) against the loudest of all AU-C1 runs.
usage: ana_cobblepeaks.py <out.json> <head>=<wav>[,<wav>...] ..."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402


def stats(path):
    x, _ = dsp.load(path)
    out = {"tp": round(dsp.tp(x), 2), "lufs": round(dsp.lufs_plain(x), 2)}
    for ch, nm in ((0, "L"), (1, "R")):
        c = x[:, ch]
        r = float(np.sqrt(np.mean(c * c)))
        a = np.abs(c)
        out[nm] = {"rms_db": round(20 * math.log10(r), 2), "peak_dbfs": round(20 * math.log10(a.max()), 2),
                   "crest": round(20 * math.log10(a.max() / r), 2), "q999": round(20 * math.log10(np.quantile(a, 0.999) / r), 2)}
    return out


def main():
    out = sys.argv[1]
    res = {}
    for item in sys.argv[2:]:
        head, paths = item.split("=", 1)
        res[head] = [stats(p) for p in paths.split(",")]
    ref = res.get("c1")
    print("| Kopf / Lauf | True Peak (dBTP) | Scheitel L / R (dB) | 99,9 % L / R (dB über RMS) | RMS L / R (dBFS) | lautester Stein gegen den lautesten aller AU-C1-Läufe L / R (dB) |")
    print("|---|---|---|---|---|---|")
    for head, runs in res.items():
        for i, s in enumerate(runs):
            rel = ""
            if ref:
                # the loudest stone (absolute sample peak per channel) against the loudest of all AU-C1 runs
                cl = max(r["L"]["peak_dbfs"] for r in ref)
                cr = max(r["R"]["peak_dbfs"] for r in ref)
                rel = f"{s['L']['peak_dbfs'] - cl:+.2f} / {s['R']['peak_dbfs'] - cr:+.2f}"
            print(f"| {head} {i + 1} | {s['tp']:.2f} | {s['L']['crest']:.2f} / {s['R']['crest']:.2f} | {s['L']['q999']:.2f} / "
                  f"{s['R']['q999']:.2f} | {s['L']['rms_db']:.2f} / {s['R']['rms_db']:.2f} | {rel} |")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
