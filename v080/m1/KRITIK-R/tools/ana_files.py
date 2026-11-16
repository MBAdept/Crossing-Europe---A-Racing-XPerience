#!/usr/bin/env python3
"""KRITIK-R: file-level checks of the AU-R sounds against AU-C1 (4209268).
 1. impact variants (glass, debris, truck_boom a-d) against the AU-C1 file: third-octave shape (energy-normalised,
    bands within 30 dB of the loudest) and level at equal sample peak; variant a against the old file after the lead
 2. one-shots with the 20-ms lead (hit_heavy, hit_light, crunch): bit-identical after the lead?
 3. loops: old WAV against the new pair (a, b): shape, tonal peaks (>= 12 dB over the third-octave neighbourhood) new?
 4. snow loop against gravel: pings in 2-6 kHz (impulsive events per second)
 5. file seams of the new Ogg loops (decoded with ffmpeg): wrap step and kink against the largest in +-100 ms
usage: ana_files.py <out.json>"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"
OLD = K + "/before/assets/audio/modern"
NEW = K + "/after/assets/audio/modern"
SR = 44100


def load(path):
    if path.endswith(".ogg"):
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                             capture_output=True, check=True).stdout
        return np.frombuffer(raw, dtype="<f4").astype(np.float64)
    x, sr = dsp.load(path)
    x = np.asarray(x, np.float64)
    return x if x.ndim == 1 else x.mean(axis=1)


def toct(x):
    c, L = dsp.third_octaves(x)
    return np.array(c), np.array(L)


def shape_diff(xa, xb, floor_db=30.0):
    """max |dL| over third-octave bands within floor_db of the loudest band, both normalised to equal energy."""
    c, La = toct(xa)
    _, Lb = toct(xb)
    Ea = 10 * np.log10(np.sum(10 ** (La / 10)))
    Eb = 10 * np.log10(np.sum(10 ** (Lb / 10)))
    La, Lb = La - Ea, Lb - Eb
    m = (La > La.max() - floor_db) | (Lb > Lb.max() - floor_db)
    m &= (c >= 25) & (c <= 12500)
    d = Lb - La
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    return round(float(np.abs(d[i])), 2), round(float(c[i]), 0)


def level_at_equal_peak(xa, xb):
    """dB of b against a when both are scaled to the same sample peak (as the game does: layers by peak)."""
    pa, pb = np.max(np.abs(xa)), np.max(np.abs(xb))
    ea = np.sqrt(np.mean((xa / pa) ** 2))
    eb = np.sqrt(np.mean((xb / pb) ** 2))
    return round(float(20 * np.log10(eb / ea)), 2)


def pings(x, lo=2000.0, hi=6000.0, frame_s=0.002, over_db=12.0):
    """Impulsive events in a band: 2-ms RMS frames standing over_db over the running median (50 ms), per second."""
    y = dsp.zero_phase(x, SR, lambda f: dsp.hp_mag(lo, 4)(f) * dsp.lp_mag(hi, 4)(f))
    k = int(frame_s * SR)
    n = len(y) // k
    e = 20 * np.log10(np.sqrt(np.mean(y[:n * k].reshape(n, k) ** 2, axis=1)) + 1e-12)
    w = int(0.05 / frame_s)
    med = np.array([np.median(e[max(0, i - w):i + w]) for i in range(n)])
    hit = e > med + over_db
    ev = int(np.sum(hit[1:] & ~hit[:-1]))
    return round(ev / (len(x) / SR), 2)


def seam(x):
    """Wrap step and kink at the loop seam against the largest step / kink within 100 ms on either side."""
    w = int(0.1 * SR)
    ext = np.concatenate([x[-w:], x[:w]])
    d1 = np.diff(ext)
    d2 = np.diff(ext, 2)
    j = w - 1        # step from x[-1] to x[0] is d1[w-1]
    step = abs(d1[j])
    ref = np.max(np.abs(np.delete(d1, [j]))) + 1e-12
    kink = max(abs(d2[j - 1]), abs(d2[j]))
    refk = np.max(np.abs(np.delete(d2, [j - 1, j]))) + 1e-12
    return round(float(step / ref), 3), round(float(kink / refk), 3)


def main():
    out = {}
    # 1. variants
    var = {}
    for sid in ("glass", "debris", "truck_boom"):
        old = load(f"{OLD}/sfx/{sid}.wav")
        rows = {}
        for v in "abcd":
            p = f"{NEW}/sfx/{sid}_{v}.wav"
            if not os.path.exists(p):
                rows[v] = "fehlt"
                continue
            x = load(p)
            lead = x[:882]
            body = x[882:]
            same = len(body) == len(old) and bool(np.array_equal(np.round(body * 32768), np.round(old * 32768)))
            rows[v] = {"shape_max_db": shape_diff(old, x), "level_equal_peak_db": level_at_equal_peak(old, x),
                       "lead_silent": bool(np.max(np.abs(lead)) < 1e-6), "a_equals_old_after_lead": same,
                       "seconds": round(len(x) / SR, 3), "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(x)))), 2)}
        var[sid] = rows
        print(sid, json.dumps(rows))
    out["variants"] = var
    # 2. one-shots with the lead
    lead = {}
    for sid in ("hit_heavy_a", "hit_heavy_b", "hit_light_a", "hit_light_b", "crunch_a", "crunch_b"):
        a = load(f"{OLD}/sfx/{sid}.wav")
        b = load(f"{NEW}/sfx/{sid}.wav")
        same = len(b) - 882 == len(a) and bool(np.array_equal(np.round(b[882:] * 32768), np.round(a * 32768)))
        lead[sid] = {"identical_after_20ms": same, "lead_silent": bool(np.max(np.abs(b[:882])) < 1e-6)}
    print("lead", json.dumps(lead))
    out["lead"] = lead
    # 3. loops
    loops = {}
    for sid in ("tyre_asphalt", "tyre_concrete", "tyre_cobbles", "tyre_deck", "tyre_rumble", "tyre_gravel", "tyre_grass",
                "tyre_wet", "wind_low", "wind_mid", "wind_high", "wind_buffet"):
        old = load(f"{OLD}/vehicle/{sid}.wav")
        a = load(f"{NEW}/vehicle/{sid}.ogg")
        b = load(f"{NEW}/vehicle/{sid}_b.ogg")
        tp_old = dsp.tonal_peaks(old)
        row = {"len_old_s": round(len(old) / SR, 3), "len_a_s": round(len(a) / SR, 3), "len_b_s": round(len(b) / SR, 3),
               "shape_a_db": shape_diff(old, a), "shape_b_db": shape_diff(old, b),
               "tonal_old": [(round(f), round(p, 1)) for f, p in tp_old],
               "tonal_a": [(round(f), round(p, 1)) for f, p in dsp.tonal_peaks(a)],
               "tonal_b": [(round(f), round(p, 1)) for f, p in dsp.tonal_peaks(b)],
               "seam_a": seam(a), "seam_b": seam(b), "seam_old": seam(old),
               "crest_old": round(dsp.crest_db(old), 1), "crest_a": round(dsp.crest_db(a), 1), "crest_b": round(dsp.crest_db(b), 1)}
        g = np.gcd(len(a), len(b))
        row["gcd_frames"] = int(g)
        row["common_period_s"] = round(len(a) * len(b) / g / SR, 1)
        loops[sid] = row
        print(sid, json.dumps({k: v for k, v in row.items()}))
    out["loops"] = loops
    # slabs (WAV both)
    for sid in ("slab_slow", "slab_fast"):
        old = load(f"{OLD}/vehicle/{sid}.wav")
        new = load(f"{NEW}/vehicle/{sid}.wav")
        out.setdefault("slabs", {})[sid] = {"len_old_s": round(len(old) / SR, 3), "len_new_s": round(len(new) / SR, 3),
                                           "shape_db": shape_diff(old, new), "seam_new": seam(new),
                                           "crest_old": round(dsp.crest_db(old), 1), "crest_new": round(dsp.crest_db(new), 1)}
        print(sid, json.dumps(out["slabs"][sid]))
    # 4. snow
    snow = {}
    for label, path in (("gravel_old", f"{OLD}/vehicle/tyre_gravel.wav"), ("gravel_new_a", f"{NEW}/vehicle/tyre_gravel.ogg"),
                        ("snow_a", f"{NEW}/vehicle/tyre_snow.ogg"), ("snow_b", f"{NEW}/vehicle/tyre_snow_b.ogg")):
        x = load(path)
        snow[label] = {"pings_per_s_2_6k": pings(x), "tonal": [(round(f), round(p, 1)) for f, p in dsp.tonal_peaks(x)],
                       "centroid_hz": round(dsp.centroid(x)), "share_below_180": round(dsp.share_below(x, 180.0), 3),
                       "seam": seam(x)}
        print(label, json.dumps(snow[label]))
    out["snow"] = snow
    json.dump(out, open(sys.argv[1], "w"), indent=1)
    print("->", sys.argv[1])


if __name__ == "__main__":
    main()
