#!/usr/bin/env python3
"""KRITIK-R: analysis of a kr_capture.gd run (one tree, one plan).
usage: ana_cap.py <capdir> <out.json> [segment ...]
Per segment: loudness (at Gesamtlautstärke 1.0 = the recording; 0.8 = -1.94 dB), true peak (4x, qc_lib), sample
peak, limiter gain reduction from the MMaster captures (pre = after the glue compressor, post = end of MMaster),
envelope autocorrelation (KRITIK-FAHRBAHN dsp.env_autocorr: 10-ms RMS of the mono sum, log, mean removed) per band up
to 8 s with every local peak, third-octave levels."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

SR = 44100
BANDS = {"600-1600": (600.0, 1600.0), "2500-8000": (2500.0, 8000.0), "broad": None}


def load_f32(path):
    if not os.path.exists(path):
        return None
    a = np.fromfile(path, dtype="<f4")
    if a.size < 4:
        return None
    return a.reshape(-1, 2).astype(np.float64)


def peaks(lags, ac, lo, hi, minv=0.0):
    out = []
    for i in range(1, len(ac) - 1):
        if lags[i] < lo or lags[i] > hi:
            continue
        if ac[i] >= ac[i - 1] and ac[i] > ac[i + 1] and ac[i] >= minv:
            out.append((round(float(lags[i]), 2), round(float(ac[i]), 3)))
    out.sort(key=lambda t: -t[1])
    return out


def rep(x, band, chan=None):
    y = x if chan is None else x[:, chan]
    lags, ac = dsp.env_autocorr(y, SR, 0.01, min(8.0, len(y) / SR - 1.0), band=band)
    m = (lags >= 0.3) & (lags <= 3.0)
    return {"max_0.3_3": [round(float(lags[m][np.argmax(ac[m])]), 2), round(float(np.max(ac[m])), 3)],
            "peaks_0.3_3": peaks(lags, ac, 0.3, 3.0)[:6], "peaks_3_8": peaks(lags, ac, 3.0, 8.0)[:6],
            "curve": [round(float(v), 4) for v in ac]}


def gain_reduction(pre, post, block_s=0.01):
    """Per block: 20 log10(peak(pre) / peak(post)) where pre is above -60 dBFS (aligned by the best lag first)."""
    n = min(len(pre), len(post))
    pre, post = pre[:n], post[:n]
    # alignment (a limiter may delay): best lag in +-256 frames on the mono sum of the loudest second
    mp, mq = pre.mean(axis=1), post.mean(axis=1)
    k = int(SR)
    i0 = int(np.argmax([np.sum(mp[j:j + k] ** 2) for j in range(0, max(n - k, 1), k)] or [0])) * k
    a, b = mp[i0:i0 + k], mq[i0:i0 + k]
    best, lag = -1.0, 0
    for L in range(-256, 257):
        if L >= 0:
            c = float(np.dot(a[:len(a) - L], b[L:])) if len(a) > L else 0.0
        else:
            c = float(np.dot(a[-L:], b[:len(b) + L])) if len(a) > -L else 0.0
        if c > best:
            best, lag = c, L
    if lag > 0:
        pre, post = pre[:n - lag], post[lag:]
    elif lag < 0:
        pre, post = pre[-lag:], post[:n + lag]
    blk = int(block_s * SR)
    nb = len(pre) // blk
    pp = np.max(np.abs(pre[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
    qq = np.max(np.abs(post[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
    ok = pp > 1e-3
    gr = np.zeros(nb)
    gr[ok] = 20 * np.log10(pp[ok] / np.maximum(qq[ok], 1e-9))
    gr = np.maximum(gr, 0.0)
    active = gr > 0.1
    events = int(np.sum(active[1:] & ~active[:-1]) + (1 if nb and active[0] else 0))
    return {"lag_frames": lag, "gr_max_db": round(float(gr.max()) if nb else 0.0, 2),
            "gr_share_over_0.1": round(float(active.mean()) if nb else 0.0, 4),
            "gr_share_over_0.5": round(float((gr > 0.5).mean()) if nb else 0.0, 4), "events": events,
            "seconds": round(len(pre) / SR, 2), "pre_peak_db": round(float(20 * np.log10(pp.max() + 1e-12)), 2),
            "post_peak_db": round(float(20 * np.log10(qq.max() + 1e-12)), 2),
            "diff_max": float(np.max(np.abs(pre - post))) if len(pre) else 0.0}


def analyse(capdir, name, meta):
    x, sr = dsp.load(os.path.join(capdir, name + ".wav"))
    r = {"seconds": round(len(x) / SR, 2), "lufs_1.0": round(dsp.lufs(x), 2), "lufs_plain_1.0": round(dsp.lufs_plain(x), 2),
         "tp_1.0": round(dsp.tp(x), 2), "sp_1.0": round(dsp.sp(x), 2)}
    r["lufs_0.8"] = round(r["lufs_1.0"] + float(meta["master_db"]), 2)
    pre = load_f32(os.path.join(capdir, name + "_pre.f32"))
    post = load_f32(os.path.join(capdir, name + "_post.f32"))
    if pre is not None and post is not None:
        r["pre_tp"] = round(dsp.tp(pre), 2)
        r["limiter"] = gain_reduction(pre, post)
    c, L = dsp.third_octaves(x)
    r["third_oct"] = [round(float(v), 2) for v in L]
    r["rep"] = {}
    if any(k in name for k in ("asph", "conc", "cobbles", "rumble", "wind", "snow", "wet", "gravel", "grass", "deck")):
        for bn, band in BANDS.items():
            r["rep"][bn] = {"mono": rep(x, band), "L": rep(x, band, 0), "R": rep(x, band, 1)}
    return r


def main():
    capdir, out = sys.argv[1], sys.argv[2]
    only = set(sys.argv[3:])
    meta = json.load(open(os.path.join(capdir, "segments.json")))
    res = {"master_db": meta["master_db"], "mmaster_fx": meta.get("mmaster_fx"), "centres": [float(v) for v in dsp.TOB_CENTRES],
           "segments": {}}
    for s in meta["segments"]:
        name = s["name"]
        if only and name not in only:
            continue
        r = analyse(capdir, name, meta)
        r["feed"] = {k: s["feed"].get(k) for k in ("surface_l", "surface_r", "paving", "zone", "tunnel", "bridge", "deck")}
        r["feed_end"] = {k: s["feed_end"].get(k) for k in ("surface_l", "surface_r", "paving", "zone", "bridge", "deck")}
        r["wall_s"] = s["wall_s"]
        res["segments"][name] = r
        lim = r.get("limiter", {})
        line = (f"{name:20s} {r['seconds']:5.1f}s {r['lufs_1.0']:7.2f} LUFS@1.0 ({r['lufs_0.8']:7.2f}@0.8) TP@1.0 {r['tp_1.0']:6.2f}"
                f" | pre TP {r.get('pre_tp', float('nan')):6.2f} GRmax {lim.get('gr_max_db', float('nan')):5.2f} ev {lim.get('events', '-')}"
                f" share>0.1 {lim.get('gr_share_over_0.1', float('nan'))} lag {lim.get('lag_frames', '-')} | {r['feed']['paving']} "
                f"{r['feed']['surface_l']}/{r['feed']['surface_r']}->{r['feed_end']['paving']}")
        print(line)
        for bn, d in r["rep"].items():
            print(f"    {bn:9s} mono max0.3-3 {d['mono']['max_0.3_3']} peaks {d['mono']['peaks_0.3_3'][:3]} | 3-8 s {d['mono']['peaks_3_8'][:3]}"
                  f" | L {d['L']['max_0.3_3']} R {d['R']['max_0.3_3']}")
    json.dump(res, open(out, "w"), indent=0)
    print("->", out)


if __name__ == "__main__":
    main()
