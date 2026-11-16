#!/usr/bin/env python3
"""KRITIK-R: file checks, second pass (shift-invariant spectra for one-shots, ping detector calibrated on gravel,
the 3.15-kHz whistle of wind_high, crest factors of the cobble loops as the game plays them).
 1. impact variants vs the AU-C1 file: third-octave levels from ONE full-length FFT (energy per band – a time shift
    such as the 20-ms lead changes nothing), shape after equal-energy normalisation, bands within 30 dB of the loudest,
    25 Hz – 12.5 kHz; level at equal sample peak.
 2. pings: 1-ms RMS envelope of the 2–6 kHz band; an event = a frame >= thr dB over the 100-ms running median;
    thresholds 6 / 9 / 12 dB; per second.
 3. wind_high: prominence of the strongest line 3.0–3.3 kHz over the median of 2.5–4 kHz (narrowband, 1.35 Hz bins).
usage: ana_files2.py <out.json>"""
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
CEN = np.array([1000.0 * 10.0 ** (k / 10.0) for k in range(-17, 13)])


def load(path):
    if path.endswith(".ogg"):
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                             capture_output=True, check=True).stdout
        return np.frombuffer(raw, dtype="<f4").astype(np.float64)
    x, _ = dsp.load(path)
    x = np.asarray(x, np.float64)
    return x if x.ndim == 1 else x.mean(axis=1)


def toct_full(x):
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    out = []
    for c in CEN:
        m = (f >= c * 10 ** -0.05) & (f < c * 10 ** 0.05)
        out.append(10 * np.log10(X[m].sum() + 1e-30))
    return np.array(out)


def shape_diff(a, b, floor_db=30.0):
    La, Lb = toct_full(a), toct_full(b)
    Ea, Eb = 10 * np.log10(np.sum(10 ** (La / 10))), 10 * np.log10(np.sum(10 ** (Lb / 10)))
    La, Lb = La - Ea, Lb - Eb
    m = ((La > La.max() - floor_db) | (Lb > Lb.max() - floor_db)) & (CEN >= 25) & (CEN <= 12500)
    d = Lb - La
    i = int(np.argmax(np.where(m, np.abs(d), -1)))
    return round(float(d[i]), 2), int(round(CEN[i])), [round(float(v), 1) for v in np.where(m, d, np.nan)]


def level_at_equal_peak(a, b):
    pa, pb = np.max(np.abs(a)), np.max(np.abs(b))
    return round(float(20 * np.log10(np.sqrt(np.mean((b / pb) ** 2)) / np.sqrt(np.mean((a / pa) ** 2)))), 2)


def pings(x, thr):
    y = dsp.zero_phase(x, SR, lambda f: dsp.hp_mag(2000.0, 4)(f) * dsp.lp_mag(6000.0, 4)(f))
    k = 44
    n = len(y) // k
    e = 20 * np.log10(np.sqrt(np.mean(y[:n * k].reshape(n, k) ** 2, axis=1)) + 1e-12)
    w = 50
    med = np.array([np.median(e[max(0, i - w):i + w]) for i in range(n)])
    hit = e > med + thr
    return round(int(np.sum(hit[1:] & ~hit[:-1])) / (len(x) / SR), 2)


def whistle(x):
    n = 1 << 15
    f, p = dsp.psd(x, SR, n)
    L = 10 * np.log10(p + 1e-30)
    m = (f >= 3000) & (f <= 3300)
    ref = (f >= 2500) & (f <= 4000)
    i = int(np.argmax(np.where(m, L, -999)))
    return round(float(f[i]), 1), round(float(L[i] - np.median(L[ref])), 1)


def main():
    out = {"variants": {}, "pings": {}, "whistle": {}}
    for sid in ("glass", "debris", "truck_boom"):
        old = load(f"{OLD}/sfx/{sid}.wav")
        for v in "abcd":
            x = load(f"{NEW}/sfx/{sid}_{v}.wav")
            d, fc, vec = shape_diff(old, x)
            out["variants"][f"{sid}_{v}"] = {"max_db": d, "at_hz": fc, "level_equal_peak_db": level_at_equal_peak(old, x), "diff": vec}
            print(f"{sid}_{v}: größte Terz {d:+.2f} dB bei {fc} Hz, Pegel bei gleicher Spitze {level_at_equal_peak(old, x):+.2f} dB")
    for label, path in (("gravel_old", f"{OLD}/vehicle/tyre_gravel.wav"), ("gravel_new", f"{NEW}/vehicle/tyre_gravel.ogg"),
                        ("snow_a", f"{NEW}/vehicle/tyre_snow.ogg"), ("snow_b", f"{NEW}/vehicle/tyre_snow_b.ogg"),
                        ("cobbles_old", f"{OLD}/vehicle/tyre_cobbles.wav"), ("cobbles_a", f"{NEW}/vehicle/tyre_cobbles.ogg")):
        x = load(path)
        out["pings"][label] = {f"thr{t}": pings(x, t) for t in (6, 9, 12)}
        print(label, out["pings"][label])
    for label, path in (("wind_high_old", f"{OLD}/vehicle/wind_high.wav"), ("wind_high_a", f"{NEW}/vehicle/wind_high.ogg"),
                        ("wind_high_b", f"{NEW}/vehicle/wind_high_b.ogg")):
        out["whistle"][label] = whistle(load(path))
        print(label, "Pfeifton", out["whistle"][label])
    json.dump(out, open(sys.argv[1], "w"), indent=1)


if __name__ == "__main__":
    main()
