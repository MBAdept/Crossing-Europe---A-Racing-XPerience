#!/usr/bin/env python3
"""KRITIK-R: crashes (kr_crash.gd) and the worst case (kr_worst.gd): true peak of Master at Gesamtlautstärke 1.0 per
event, peak in front of the Modern limiter, gain reduction of the limiter per 10-ms block (pre vs post on MMaster,
aligned), variants / levels / delays of the layers, squeal pitch per pulse, pass-by variants.
usage: ana_crash.py crash <base.wav> <out.json> | ana_crash.py worst <base.wav> <out.json>"""
import json
import os
import sys
from collections import Counter

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402
from ana_cap import gain_reduction, load_f32  # noqa: E402

SR = 44100


def window(x, a, b):
    a = max(0, a)
    return x[a:min(len(x), b)]


def gr_series(pre, post, block_s=0.01):
    """Block-wise gain reduction (dB) after alignment (the limiter delays by its look-ahead)."""
    info = gain_reduction(pre, post, block_s)
    lag = info["lag_frames"]
    n = min(len(pre), len(post))
    pre, post = pre[:n], post[:n]
    if lag > 0:
        pre, post = pre[:n - lag], post[lag:]
    elif lag < 0:
        pre, post = pre[-lag:], post[:n + lag]
    blk = int(block_s * SR)
    nb = len(pre) // blk
    pp = np.max(np.abs(pre[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
    qq = np.max(np.abs(post[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
    gr = np.where(pp > 1e-3, 20 * np.log10(pp / np.maximum(qq, 1e-9)), 0.0)
    return np.maximum(gr, 0.0), info


def crash(base, out):
    meta = json.load(open(os.path.splitext(base)[0] + ".json"))
    x, _ = dsp.load(base)
    pre = load_f32(os.path.splitext(base)[0] + "_pre.f32")
    post = load_f32(os.path.splitext(base)[0] + "_post.f32")
    gr, info = gr_series(pre, post)
    rows = []
    for m in meta["marks"]:
        f0 = int(m["frame"])
        a, b = f0 - int(0.05 * SR), f0 + int(1.5 * SR)
        xm = window(x, a, b)
        pm = window(pre, a, b)
        g = gr[max(0, a // 441):b // 441]
        lay = m["layers"]
        rows.append({"side": m["side"], "tp_master_1.0": round(dsp.tp(xm), 2), "sp_master_1.0": round(dsp.sp(xm), 2),
                     "pre_tp": round(dsp.tp(pm), 2), "pre_sp": round(dsp.sp(pm), 2), "gr_max": round(float(g.max()) if len(g) else 0.0, 2),
                     "glass": any(l[0] == "glass" for l in lay), "layers": lay})
    tps = [r["tp_master_1.0"] for r in rows]
    grs = [r["gr_max"] for r in rows]
    pres = [r["pre_tp"] for r in rows]
    # variety
    var = {}
    for r in rows:
        for l in r["layers"]:
            d = var.setdefault(l[0], {"variants": Counter(), "jitter": [], "delay": [], "seq": []})
            d["variants"][int(l[1])] += 1
            d["seq"].append(int(l[1]))
            if len(l) > 4:
                d["jitter"].append(float(l[4]))
                d["delay"].append(float(l[5]))
    variety = {}
    for k, d in var.items():
        seq = d["seq"]
        rep = sum(1 for i in range(1, len(seq)) if seq[i] == seq[i - 1])
        alt = sum(1 for i in range(2, len(seq)) if seq[i] == seq[i - 2] and seq[i] != seq[i - 1])
        variety[k] = {"n": len(seq), "variants": dict(sorted(d["variants"].items())), "direct_repeats": rep,
                      "abab_steps": alt, "jitter_min_max": [min(d["jitter"]), max(d["jitter"])] if d["jitter"] else None,
                      "delay_min_max_ms": [min(d["delay"]), max(d["delay"])] if d["delay"] else None,
                      "seq": "".join("abcdefgh"[v] for v in seq[:24])}
    res = {"n": len(rows), "tp_max": max(tps), "tp_median": float(np.median(tps)), "pre_tp_max": max(pres),
           "gr_max": max(grs), "gr_median": float(np.median(grs)), "gr_over_3db": sum(1 for g in grs if g > 3.0),
           "glass_share": sum(1 for r in rows if r["glass"]) / max(len(rows), 1), "limiter": info, "variety": variety,
           "rows": rows, "heavy_layers": meta.get("heavy_layers"), "truck_db": meta.get("truck_db")}
    # squeal pitch per pulse: spectral peak 650-1150 Hz of the Master in the pulse (0.15-0.65 s after its start)
    sq = []
    for s in meta.get("squeals", []):
        f0 = int(s["frame"])
        seg = dsp.mono(window(x, f0 + int(0.15 * SR), f0 + int(0.65 * SR)))
        if len(seg) < 4096:
            continue
        n = 1 << 15
        spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), n))
        fr = np.fft.rfftfreq(n, 1.0 / SR)
        m = (fr >= 650) & (fr <= 1150)
        sq.append({"factor": s["factor"], "peak_hz": round(float(fr[m][np.argmax(spec[m])]), 1)})
    if sq:
        hz = np.array([q["peak_hz"] for q in sq])
        res["squeal"] = {"n": len(sq), "hz_min": float(hz.min()), "hz_max": float(hz.max()), "hz_mean": round(float(hz.mean()), 1),
                         "spread_pct": round(float((hz.max() - hz.min()) / hz.mean() * 50.0), 2),
                         "std_pct": round(float(hz.std() / hz.mean() * 100.0), 2), "pulses": sq}
    ps = meta.get("passes", [])
    if ps:
        seq = [(p["id"], int(p["variant"])) for p in ps]
        byid = {}
        for i, v in seq:
            byid.setdefault(i, []).append(v)
        res["passes"] = {"n": len(ps), "per_id": {k: "".join("abcdefgh"[v] for v in vs) for k, vs in byid.items()},
                         "jitter": [round(float(p.get("jitter_db", 0.0)), 2) for p in ps]}
    json.dump(res, open(out, "w"), indent=1)
    print(f"{base}: n {len(rows)}, TP@1.0 max {max(tps):.2f} median {np.median(tps):.2f} dBTP | vor dem Begrenzer TP max "
          f"{max(pres):.2f} | GR max {max(grs):.2f} median {np.median(grs):.2f}, >3 dB: {res['gr_over_3db']} | Glas {res['glass_share']:.2f}"
          f" | lag {info['lag_frames']}")
    for k, v in variety.items():
        print(f"   {k:11s} {v['variants']} Wiederholungen {v['direct_repeats']} abab {v['abab_steps']} jitter {v['jitter_min_max']} "
              f"delay {v['delay_min_max_ms']} {v['seq']}")
    if "squeal" in res:
        print("   Quietschen:", {k: v for k, v in res["squeal"].items() if k != "pulses"})
    if "passes" in res:
        print("   Vorbeifahrten:", res["passes"]["n"], res["passes"]["per_id"], "jitter", min(res["passes"]["jitter"]), max(res["passes"]["jitter"]))


def worst(base, out):
    meta = json.load(open(os.path.splitext(base)[0] + ".json"))
    x, _ = dsp.load(base)
    pre = load_f32(os.path.splitext(base)[0] + "_pre.f32")
    post = load_f32(os.path.splitext(base)[0] + "_post.f32")
    gr, info = gr_series(pre, post)
    res = {"tp_master_1.0": round(dsp.tp(x), 2), "sp_master_1.0": round(dsp.sp(x), 2), "lufs_1.0": round(dsp.lufs(x), 2),
           "pre_tp": round(dsp.tp(pre), 2), "pre_sp": round(dsp.sp(pre), 2), "post_tp": round(dsp.tp(post), 2),
           "gr_max": round(float(gr.max()), 2), "gr_share_over_1": round(float((gr > 1).mean()), 3),
           "gr_share_over_3": round(float((gr > 3).mean()), 3), "gr_median": round(float(np.median(gr)), 2),
           "pre_lufs": round(dsp.lufs(pre), 2), "post_lufs": round(dsp.lufs(post), 2), "limiter": info, "marks": meta.get("marks")}
    # per 0.5 s: GR max
    per = []
    for i in range(0, len(gr), 50):
        per.append(round(float(gr[i:i + 50].max()), 1))
    res["gr_per_half_second"] = per
    json.dump(res, open(out, "w"), indent=1)
    print(f"{base}: {json.dumps({k: v for k, v in res.items() if k not in ('limiter', 'gr_per_half_second', 'marks')})}")
    print("   GR je 0,5 s:", per)


if __name__ == "__main__":
    {"crash": crash, "worst": worst}[sys.argv[1]](sys.argv[2], sys.argv[3])
