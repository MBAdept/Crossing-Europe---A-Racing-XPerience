#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: level difference WITHOUT motion, from the sweeps of probe_switch2.gd.

The sweep passes every distance twice (in: far -> near, out: near -> far). Inside the hysteresis band the car shows
lod1 on the way in and lod0 on the way out at the SAME distance and the same light: the difference of these two frames
is exactly what a switch changes (no movement). Measured on the car's pixels (union of both car masks against the
background crop, max channel > THR):
  share  = share of car pixels whose colour changes by more than THR (max channel) -> "Anteil der Autopixel"
  dE_px  = mean / p95 per-pixel CIELAB dE76 inside the car, share of pixels with dE > 10
  dE_mean_colour = dE76 between the mean colours of the car in both frames
Also: the frame-to-frame change at the switch frame itself (with 0.1 m motion) and, with an Arcade run of the same
states, Modern lod0 / lod1 against Arcade at the same distance.

usage: switch_stats2.py <run> [--arcade=<run>] [--ref=<refused run>] [--json=out.json] [--win=x0,y0,x1,y1]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

THR = 0.06 * 255.0
WIN = [130, 70, 320, 225]


def srgb_to_lab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def load(p):
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
    return a[WIN[1]:WIN[3], WIN[0]:WIN[2]]


def rows_of(run):
    rows = {}
    for line in open(os.path.join(run, "log.jsonl")):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "i" in d:
            rows.setdefault(d["set"], []).append(d)
    return rows


def paint_px(im, m):
    """Pixels of the car that read as white paint (CIELAB L > 62, chroma < 12)."""
    if not m.any():
        return 0
    lab = srgb_to_lab(im[m])
    return int(((lab[:, 0] > 62) & (np.hypot(lab[:, 1], lab[:, 2]) < 12)).sum())


def compare(a, b, bg):
    ma = np.abs(a - bg).max(-1) > THR
    mb = np.abs(b - bg).max(-1) > THR
    u = ma | mb
    n = int(u.sum())
    if n == 0:
        return None
    ch = (np.abs(a - b).max(-1) > THR) & u
    la, lb = srgb_to_lab(a[u]), srgb_to_lab(b[u])
    de = np.linalg.norm(la - lb, axis=-1)
    mean_a = srgb_to_lab(a[ma]).mean(0) if ma.any() else la.mean(0)
    mean_b = srgb_to_lab(b[mb]).mean(0) if mb.any() else lb.mean(0)
    return {"car_px": n, "share": round(float(ch.sum()) / n, 4), "de_px_mean": round(float(de.mean()), 2),
            "de_px_p95": round(float(np.percentile(de, 95)), 1), "share_de10": round(float((de > 10).mean()), 4),
            "de_mean_colour": round(float(np.linalg.norm(mean_a - mean_b)), 2),
            "L_a": round(float(mean_a[0]), 1), "L_b": round(float(mean_b[0]), 1),
            "rgb_a": a[ma].mean(0).round(1).tolist() if ma.any() else None,
            "rgb_b": b[mb].mean(0).round(1).tolist() if mb.any() else None,
            "visible_px_a": int(ma.sum()), "visible_px_b": int(mb.sum()),
            "paint_px_a": paint_px(a, ma), "paint_px_b": paint_px(b, mb)}


def pairs(run, set_id, rows):
    """(d, frame in, frame out) where in/out show different levels at the same distance."""
    sd = os.path.join(run, set_id.replace("/", "_"))
    ins = {round(r["d"], 2): r for r in rows if r["phase"] == "in"}
    outs = {round(r["d"], 2): r for r in rows if r["phase"] == "out"}
    res = []
    for d, ri in sorted(ins.items()):
        ro = outs.get(d)
        if ro is not None and ri["lod"] != ro["lod"]:
            res.append((d, ri, ro))
    return sd, res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if "win" in opts:
        WIN[:] = [int(v) for v in opts["win"].split(",")]
    run = args[0]
    rows = rows_of(run)
    arows = rows_of(opts["arcade"]) if "arcade" in opts else {}
    report = {}
    for set_id, rs in rows.items():
        sd, ps = pairs(run, set_id, rs)
        bg = load(os.path.join(sd, "bg.png"))
        e = {"band": [ps[0][0], ps[-1][0]] if ps else None, "pairs": len(ps)}
        # switch frames (frame-to-frame, with motion) and the refusal count around them
        sw = []
        for k in range(1, len(rs)):
            if rs[k - 1]["lod"] and rs[k]["lod"] and rs[k - 1]["lod"] != rs[k]["lod"]:
                a = load(os.path.join(sd, "f%04d.png" % rs[k - 1]["i"]))
                b = load(os.path.join(sd, "f%04d.png" % rs[k]["i"]))
                c = compare(a, b, bg)
                # motion alone: the median of the neighbouring frame pairs
                mot = []
                for j in list(range(max(1, k - 6), k - 1)) + list(range(k + 2, min(len(rs), k + 7))):
                    if rs[j]["lod"] == rs[j - 1]["lod"]:
                        cc = compare(load(os.path.join(sd, "f%04d.png" % rs[j - 1]["i"])), load(os.path.join(sd, "f%04d.png" % rs[j]["i"])), bg)
                        if cc:
                            mot.append(cc["share"])
                sw.append({"from": rs[k - 1]["lod"], "to": rs[k]["lod"], "d": rs[k]["d"], "cd": rs[k].get("cd"), "i": rs[k]["i"],
                           "refusals_before": rs[k - 1].get("refusals"), "refusals_at": rs[k].get("refusals"),
                           "frame_change": c, "motion_share_median": round(float(np.median(mot)), 4) if mot else None})
        e["switches"] = sw
        # same distance, other level (no motion): the middle of the band and its spread
        if ps:
            cs = []
            for d, ri, ro in ps:
                a = load(os.path.join(sd, "f%04d.png" % ri["i"]))
                b = load(os.path.join(sd, "f%04d.png" % ro["i"]))
                c = compare(a, b, bg)
                if c:
                    c.update({"d": d, "lod_in": ri["lod"], "lod_out": ro["lod"], "i_in": ri["i"], "i_out": ro["i"]})
                    cs.append(c)
            if cs:
                mid = cs[len(cs) // 2]
                e["same_d_mid"] = mid
                e["same_d_share_range"] = [min(c["share"] for c in cs), max(c["share"] for c in cs)]
                e["same_d_de_mean_colour_range"] = [min(c["de_mean_colour"] for c in cs), max(c["de_mean_colour"] for c in cs)]
                # against Arcade at the same distance (same d on the way in)
                if set_id in arows:
                    asd = os.path.join(opts["arcade"], set_id.replace("/", "_"))
                    abg = load(os.path.join(asd, "bg.png"))
                    amap = {(round(r["d"], 2), r["phase"]): r for r in arows[set_id]}
                    ar = amap.get((mid["d"], "in"))
                    if ar:
                        aim = load(os.path.join(asd, "f%04d.png" % ar["i"]))
                        mi = load(os.path.join(sd, "f%04d.png" % mid["i_in"]))
                        mo = load(os.path.join(sd, "f%04d.png" % mid["i_out"]))
                        am = np.abs(aim - abg).max(-1) > THR
                        mim = np.abs(mi - bg).max(-1) > THR
                        mom = np.abs(mo - bg).max(-1) > THR
                        alab = srgb_to_lab(aim[am]).mean(0) if am.any() else None
                        ilab = srgb_to_lab(mi[mim]).mean(0)
                        olab = srgb_to_lab(mo[mom]).mean(0)
                        e["arcade_mid"] = {"d": mid["d"], "visible_px": int(am.sum()), "paint_px": paint_px(aim, am),
                                           "L": round(float(alab[0]), 1) if alab is not None else None,
                                           "de_mean_colour_vs_modern_in": round(float(np.linalg.norm(ilab - alab)), 2) if alab is not None else None,
                                           "de_mean_colour_vs_modern_out": round(float(np.linalg.norm(olab - alab)), 2) if alab is not None else None}
        report[set_id] = e
    txt = json.dumps(report, indent=1)
    if "json" in opts:
        open(opts["json"], "w").write(txt)
    for set_id, e in report.items():
        print("==", set_id, "band", e["band"], "pairs", e["pairs"])
        for s in e["switches"]:
            fc = s["frame_change"] or {}
            print("  switch %s->%s d=%.2f cd=%s  frame change %.1f%% (motion %.1f%%) dE mean colour %.2f  refusals %s->%s" % (
                s["from"], s["to"], s["d"], s["cd"], 100 * fc.get("share", 0), 100 * (s["motion_share_median"] or 0),
                fc.get("de_mean_colour", 0), s["refusals_before"], s["refusals_at"]))
        if "same_d_mid" in e:
            m = e["same_d_mid"]
            print("  same d=%.2f %s vs %s: share %.1f%%  dEpx mean %.2f p95 %.1f  share dE>10 %.1f%%  dE mean colour %.2f  L %.1f/%.1f  white-paint px %d/%d (car px %d/%d)  (range share %s)" % (
                m["d"], m["lod_in"], m["lod_out"], 100 * m["share"], m["de_px_mean"], m["de_px_p95"], 100 * m["share_de10"],
                m["de_mean_colour"], m["L_a"], m["L_b"], m["paint_px_a"], m["paint_px_b"], m["visible_px_a"], m["visible_px_b"], e["same_d_share_range"]))
        if "arcade_mid" in e:
            am = e["arcade_mid"]
            print("  arcade d=%.2f car px %d white-paint px %d L %s; dE mean colour Arcade vs Modern in %s / out %s" % (
                am["d"], am["visible_px"], am["paint_px"], am["L"], am["de_mean_colour_vs_modern_in"], am["de_mean_colour_vs_modern_out"]))


if __name__ == "__main__":
    main()
