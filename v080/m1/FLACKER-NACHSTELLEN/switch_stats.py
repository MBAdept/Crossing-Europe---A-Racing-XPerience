#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: statistics of the level-switch sweeps of probe_switch.gd.

For every set directory of a run: car mask = pixels that differ from the background crop (max channel > THR);
per frame the share of the car's pixels that changed against the frame before (union of both masks, max channel
difference > THR) and the mean CIELAB colour of the car's pixels. At every level switch (Modern log) the change at the
switch frame against the median change of the frames around it (motion alone) and dE76 of the mean colour before /
after; for Arcade runs the same frames (same d) give the reference.

usage: switch_stats.py <modern run dir> [<arcade run dir>] [--json out.json] [--sheet out.png]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

THR = 0.06 * 255.0
WIN = [150, 80, 300, 215]   # x0, y0, x1, y1 of the car window inside the crop (drifting clouds and rails stay outside)


def srgb_to_lab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], -1)


def load(p):
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
    return a[WIN[1]:WIN[3], WIN[0]:WIN[2]]


def read_log(run):
    rows = {}
    with open(os.path.join(run, "log.jsonl")) as f:
        for line in f:
            d = json.loads(line)
            if "i" in d:
                rows.setdefault(d["set"], []).append(d)
    return rows


def set_stats(run, set_id, rows):
    sd = os.path.join(run, set_id.replace("/", "_"))
    bg = load(os.path.join(sd, "bg.png"))
    frames = []
    for r in rows:
        p = os.path.join(sd, "f%04d.png" % r["i"])
        if os.path.exists(p):
            frames.append((r, load(p)))
    out = []
    prev = None
    for r, im in frames:
        mask = np.abs(im - bg).max(-1) > THR
        rec = {"i": r["i"], "d": r["d"], "lod": r.get("lod", ""), "xf": r.get("xf", 0.0), "phase": r["phase"], "car_px": int(mask.sum())}
        if mask.sum() > 0:
            rec["lab"] = srgb_to_lab(im[mask]).mean(0).round(2).tolist()
            rec["rgb"] = im[mask].mean(0).round(1).tolist()
        if prev is not None:
            pim, pmask = prev
            u = mask | pmask
            n = int(u.sum())
            ch = (np.abs(im - pim).max(-1) > THR) & u
            rec["changed"] = float(ch.sum()) / max(n, 1)
            # colour difference per pixel inside the union (CIELAB dE76), mean over the car
            if n > 0:
                de = np.linalg.norm(srgb_to_lab(im[u]) - srgb_to_lab(pim[u]), axis=-1)
                rec["de_mean"] = float(de.mean())
                rec["de_p95"] = float(np.percentile(de, 95))
                rec["share_de10"] = float((de > 10).mean())
        prev = (im, mask)
        out.append(rec)
    return out


def switches(stats):
    res = []
    for k in range(1, len(stats)):
        a, b = stats[k - 1], stats[k]
        if a["lod"] != b["lod"] and a["lod"] and b["lod"]:
            win = [s.get("changed", 0.0) for s in stats[max(0, k - 12):k - 1] + stats[k + 2:k + 14]]
            med = float(np.median(win)) if win else 0.0
            de_lab = None
            if "lab" in a and "lab" in b:
                de_lab = float(np.linalg.norm(np.array(a["lab"]) - np.array(b["lab"])))
            res.append({"k": k, "from": a["lod"], "to": b["lod"], "d": b["d"], "phase": b["phase"],
                        "changed": b.get("changed"), "median_motion": med, "de_mean_px": b.get("de_mean"),
                        "de_p95_px": b.get("de_p95"), "share_de10": b.get("share_de10"),
                        "de_of_mean_colour": de_lab, "car_px": b["car_px"], "lab_before": a.get("lab"), "lab_after": b.get("lab")})
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if "win" in opts:
        WIN[:] = [int(v) for v in opts["win"].split(",")]
    modern = args[0]
    arcade = args[1] if len(args) > 1 else None
    mrows = read_log(modern)
    arows = read_log(arcade) if arcade else {}
    report = {}
    for set_id, rows in mrows.items():
        st = set_stats(modern, set_id, rows)
        sw = switches(st)
        ch = [s.get("changed", 0.0) for s in st[1:]]
        med_all = float(np.median(ch)) if ch else 0.0
        sw_k = {s["k"] for s in sw}
        spikes = [{"i": s["i"], "d": s["d"], "lod": s["lod"], "phase": s["phase"], "changed": round(100 * s.get("changed", 0), 2),
                   "de_mean": round(s.get("de_mean", 0), 2)}
                  for k, s in enumerate(st) if k > 0 and k not in sw_k and s.get("changed", 0) > max(3 * med_all, 0.02)]
        entry = {"switches": sw, "frames": len(st), "median_changed": med_all,
                 "max_changed": max((s.get("changed", 0) for s in st), default=0), "spikes_outside_switch": spikes,
                 "curve": [[s["d"], s["lod"], round(100 * s.get("changed", 0), 2), s.get("rgb")] for s in st]}
        if set_id in arows:
            ast = set_stats(arcade, set_id, arows[set_id])
            # Arcade at the same distances as the Modern switch frames: its colour and its own frame change
            for s in sw:
                k = s["k"]
                if k < len(ast):
                    s["arcade_lab"] = ast[k].get("lab")
                    s["arcade_changed"] = ast[k].get("changed")
                    if s.get("lab_after") and ast[k].get("lab"):
                        s["de_modern_after_vs_arcade"] = float(np.linalg.norm(np.array(s["lab_after"]) - np.array(ast[k]["lab"])))
                    if s.get("lab_before") and ast[k - 1].get("lab"):
                        s["de_modern_before_vs_arcade"] = float(np.linalg.norm(np.array(s["lab_before"]) - np.array(ast[k - 1]["lab"])))
        report[set_id] = entry
    txt = json.dumps(report, indent=1)
    if "json" in opts:
        with open(opts["json"], "w") as f:
            f.write(txt)
    for set_id, e in report.items():
        print("%-22s frames %d median change %.2f%% spikes outside switches: %s" % (
            set_id, e["frames"], 100 * e["median_changed"], [(x["d"], x["changed"]) for x in e["spikes_outside_switch"][:8]]))
        for s in e["switches"]:
            print("%-22s %s->%s d=%.2f changed=%.1f%% (motion %.1f%%) dE(mean colour)=%s dEpx mean=%s p95=%s share dE>10=%s arcade dE after=%s" % (
                set_id, s["from"], s["to"], s["d"], 100 * (s["changed"] or 0), 100 * s["median_motion"],
                None if s["de_of_mean_colour"] is None else round(s["de_of_mean_colour"], 2),
                None if s["de_mean_px"] is None else round(s["de_mean_px"], 2),
                None if s["de_p95_px"] is None else round(s["de_p95_px"], 1),
                None if s["share_de10"] is None else round(100 * s["share_de10"], 1),
                None if s.get("de_modern_after_vs_arcade") is None else round(s["de_modern_after_vs_arcade"], 1)))


if __name__ == "__main__":
    main()
