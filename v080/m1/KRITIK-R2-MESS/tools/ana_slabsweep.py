#!/usr/bin/env python3
"""KRITIK-R2-MESS: slab layer alone in the game (plan S: slabs only, no drift/gusts/pass-bys, engine and wind muted)
at 110-200 km/h on several heads: loudness (ungated, at Gesamtlautstärke 1.0), true peak, the third-octave spectrum,
and the differences between heads per speed; plus the target of the slab law (road_audio.slab_lufs) per head.
usage: ana_slabsweep.py <out.json> <head>=<capdir> ..."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

SPEEDS = (110, 120, 130, 140, 150, 160, 170, 200)


def law(v, head):
    # tyre_top = engine_top(limousine) -17.7 - 4 = -21.7; db 3; slope 20 per decade from vmax 245;
    # above 150: high slope 4 (obj only; c1 and r: 20 throughout)
    t = -17.7 - 4.0 + 3.0 + 20.0 * math.log10(v / 245.0)
    if head == "obj" and v > 150:
        t -= (20.0 - 4.0) * math.log10(v / 150.0)
    return t


def main():
    out = sys.argv[1]
    heads = dict(a.split("=", 1) for a in sys.argv[2:])
    res = {"speeds": SPEEDS, "heads": {}}
    for h, d in heads.items():
        rows = {}
        for v in SPEEDS:
            p = os.path.join(d, f"s_slab{v}.wav")
            if not os.path.exists(p):
                continue
            x, _ = dsp.load(p)
            c, L = dsp.third_octaves(x)
            rows[v] = {"lufs": round(dsp.lufs_plain(x), 2), "tp": round(dsp.tp(x), 2), "third": [round(float(a), 2) for a in L],
                       "law_rel": round(law(v, h), 2)}
        res["heads"][h] = rows
    cen = np.array(dsp.TOB_CENTRES)
    names = list(heads)
    print("Plattenschicht allein, Lautheit @1.0 (LUFS, ungegatet) / True Peak:")
    print("km/h  " + "  ".join(f"{h:>16s}" for h in names) + "   Differenzen")
    res["diff"] = {}
    for v in SPEEDS:
        cells = []
        for h in names:
            r = res["heads"][h].get(v)
            cells.append(f"{r['lufs']:7.2f} / {r['tp']:6.2f}" if r else " " * 16)
        diffs = {}
        for a, b in (("r", "obj"), ("c1", "obj"), ("c1", "r")):
            if a in res["heads"] and b in res["heads"] and v in res["heads"][a] and v in res["heads"][b]:
                A, B = res["heads"][a][v], res["heads"][b][v]
                dl = B["lufs"] - A["lufs"]
                ta, tb = np.array(A["third"]), np.array(B["third"])
                m = (cen >= 25) & (cen <= 12500)
                m &= (ta > ta[m].max() - 30) | (tb > tb[m].max() - 30)
                dd = tb - ta
                i = int(np.argmax(np.where(m, np.abs(dd), -1)))
                # third-octave difference with the loudness difference removed (shape only)
                sh = dd - dl
                j = int(np.argmax(np.where(m, np.abs(sh), -1)))
                diffs[f"{a}->{b}"] = {"dlu": round(dl, 2), "law_dlu": round(law(v, b) - law(v, a), 2),
                                      "max_third": round(float(dd[i]), 2), "at": round(float(cen[i])),
                                      "max_shape": round(float(sh[j]), 2), "shape_at": round(float(cen[j]))}
        res["diff"][v] = diffs
        print(f"{v:4d}  " + "  ".join(cells) + "   " + "; ".join(
            f"{k}: {d['dlu']:+.2f} LU (Gesetz {d['law_dlu']:+.2f}), Terz {d['max_third']:+.2f} @ {d['at']} Hz, Form {d['max_shape']:+.2f} @ {d['shape_at']}"
            for k, d in diffs.items()))
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
