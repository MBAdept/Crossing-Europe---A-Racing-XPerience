#!/usr/bin/env python3
"""Transitions of the race pieces at file level (KRITIK-MISCHUNG): loop seam as Godot plays it (file end -> loop
offset), the bar-synced ending (cut 128 frames before the bar line, 1-ms fade, as measured for Godot 4.7.2), the
stingers over the loop ducked by 9 dB, the finish stab. Momentary (400 ms) and short-term (3 s) loudness around each
switch. usage: transitions.py <copy> <out.json>"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402

SR = alib.SR
LEAD = 128          # the ending starts this many frames before the bar line (decoder lead, AU-D1 trap 14.13.2)
STING_DUCK = -9.0
STING_ATT = 0.05


def mom(x, hop=0.05):
    return alib.Loud(x).momentary(hop)


def seam(x: np.ndarray, lp: tuple) -> dict:
    a, b = lp
    w = int(2.0 * SR)
    played = np.concatenate([x[b - w:b], x[a:a + w]])          # file end, then the jump back
    first = x[a - w:a + w]                                       # the same music in the first pass (A1 -> B1)
    d = played - first
    j = w
    jump = float(np.max(np.abs(played[j] - played[j - 1])))
    local = float(np.max(np.abs(np.diff(played[j - 2205:j + 2205], axis=0))))
    m1 = mom(played)
    m2 = mom(first)
    return {"max_diff_vs_first_pass_dbfs": round(alib.db(float(np.max(np.abs(d)))), 1),
            "jump_at_seam": round(jump, 5), "largest_step_within_50ms": round(local, 5),
            "momentary_max_diff_lu": round(float(np.max(np.abs(m1 - m2))), 2)}


def ending_switch(x: np.ndarray, end: np.ndarray, bar: float, lp: tuple, k_bar: int) -> dict:
    """Loop until the bar line k_bar of the loop body, then the ending (Godot: starts LEAD frames early)."""
    a, b = lp
    bl = int(round(a + k_bar * bar))
    cut = bl - LEAD
    fade = int(0.001 * SR)
    pre = x[cut - int(3.0 * SR):cut].copy()
    pre[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    y = np.concatenate([pre, end])
    j = len(pre)
    m = mom(y, 0.01)
    # 5-ms RMS around the switch
    r5 = np.sqrt(np.mean(y[j - 2205:j + 2205].reshape(-1, 220, 2)[:40] ** 2, axis=(1, 2)) + 1e-20) if False else None
    w = 220
    seg = y[j - 20 * w:j + 20 * w, :]
    rms = np.sqrt(np.mean(seg.reshape(40, w, 2) ** 2, axis=(1, 2)))
    around = float(np.median(rms))
    i_last = int((j / SR - 0.4) / 0.01)
    lm_pre = float(np.max(m[max(0, i_last - 200):i_last]))          # loudest 400-ms window of the last 2 s of loop
    lm_post = float(np.max(m[int(j / SR / 0.01):int(j / SR / 0.01) + 200]))   # loudest of the first 2 s of the ending
    st = alib.Loud(y).short_term(0.1)
    return {"bar": k_bar, "min_5ms_rms_rel_db": round(alib.db(float(np.min(rms)) / max(around, 1e-20)), 1),
            "mom_max_last2s_loop": round(lm_pre, 2), "mom_max_first2s_end": round(lm_post, 2),
            "step_lu": round(lm_post - lm_pre, 2), "st_max_after": round(float(np.max(st)), 2)}


def sting_over_loop(x: np.ndarray, st: np.ndarray, at_s: float, hold_s: float, rel_s: float) -> dict:
    a = int(at_s * SR)
    n = len(st) + int(3 * SR)
    loop = x[a - int(3 * SR):a + n].copy()
    t = (np.arange(len(loop)) - int(3 * SR)) / SR
    g = np.zeros(len(loop))
    att = np.clip(t / STING_ATT, 0, 1) * (t >= 0)
    g = STING_DUCK * att
    after = t > hold_s
    g[after] = STING_DUCK * np.clip(1.0 - (t[after] - hold_s) / rel_s, 0, 1)
    y = loop * (10 ** (g / 20.0))[:, None]
    y[int(3 * SR):int(3 * SR) + len(st)] += st
    m = mom(y, 0.05)
    lpre = float(np.median(mom(loop[:int(3 * SR)], 0.05)))
    i0 = int(3.0 / 0.05)
    i1 = i0 + int(hold_s / 0.05)
    ducked = float(np.median(mom(loop[int(3 * SR):int(3 * SR) + len(st)] * 10 ** (STING_DUCK / 20), 0.05)))
    return {"loop_mom_median_before": round(lpre, 2), "mix_mom_max_during": round(float(np.max(m[i0:i1 + 10])), 2),
            "sting_mom_max": round(float(np.max(mom(st, 0.05))), 2), "ducked_loop_mom_median": round(ducked, 2),
            "sting_over_ducked_lu": round(float(np.max(mom(st, 0.05))) - ducked, 2),
            "mix_peak_vs_loop_lu": round(float(np.max(m[i0:i1 + 10])) - lpre, 2)}


def main() -> int:
    root, outp = sys.argv[1], sys.argv[2]
    md = os.path.join(root, "assets/audio/modern/music")
    man = json.load(open(os.path.join(md, "manifest.json")))["sounds"]
    out = {}
    for piece in ("linke_spur", "nachtfahrt", "rueckenwind", "titel_remaster", "zwischenspiel"):
        e = man[piece]
        x = alib.read_audio(os.path.join(md, e["file"]))
        lp = tuple(e["loop"])
        r = {"seam": seam(x, lp)}
        if piece in ("linke_spur", "nachtfahrt", "rueckenwind"):
            bar = 4 * 60.0 / e["bpm"] * SR
            nb = int(round((lp[1] - lp[0]) / bar))
            ends = {"normal": e["ending"], "rekord": e["endings"]["rekord"], "finale": e["endings"]["finale"]}
            r["endings"] = {}
            for v, eid in ends.items():
                en = alib.read_audio(os.path.join(md, man[eid]["file"]))
                rows = [ending_switch(x, en, bar, lp, k) for k in (8, 24, 40, 56, nb - 1)]
                r["endings"][v] = {"min_5ms_rms_rel_db": min(q["min_5ms_rms_rel_db"] for q in rows),
                                   "step_lu_range": [min(q["step_lu"] for q in rows), max(q["step_lu"] for q in rows)],
                                   "rows": rows}
            # stingers on a beat in the hook B1 (bar 9 + 2 beats of the file) and in the breakdown
            beat = bar / 4 / SR
            r["stingers"] = {}
            for ev, sid in list(e["stingers"].items()) + [("ziel", e["ziel"])]:
                sx = alib.read_audio(os.path.join(md, man[sid]["file"]))
                hold = man[sid].get("bars", 1) * bar / SR
                for where, bar_i in (("B1", 11), ("D", 1 + 8 * 6 + 2)):
                    at = bar_i * bar / SR + 2 * beat
                    rel = 1.0 if ev != "ziel" else 0.03
                    r["stingers"][f"{ev}@{where}"] = sting_over_loop(x, sx, at, hold if ev != "ziel" else 1.0, rel)
        out[piece] = r
        print(piece, json.dumps(r["seam"]), flush=True)
        if "endings" in r:
            for v, q in r["endings"].items():
                print("   Schluss", v, "min 5ms", q["min_5ms_rms_rel_db"], "Sprung LU", q["step_lu_range"])
            for k, q in r["stingers"].items():
                print("   ", k, q)
    json.dump(out, open(outp, "w"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
