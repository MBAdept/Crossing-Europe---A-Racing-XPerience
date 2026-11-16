#!/usr/bin/env python3
"""Spike 2: measurements of music excerpts (old title excerpt vs remaster, new race track)."""
import json, os, sys
import numpy as np
import alib
from alib import *

W = alib.WORK
OUT = W + "/out"
SR = 48000


def measure(x):
    xk = k_weight(x, SR)
    fc, v = third_octave(x, SR, 25, 20000)
    p = 10 ** (v / 10)

    def share(lo, hi):
        return float(10 * np.log10(np.sum(p[(fc >= lo) & (fc < hi)]) / np.sum(p)))

    lufs = integrated_lufs(x, SR, xk)
    tp = true_peak_db(x)
    m = 0.5 * (x[:, 0] + x[:, 1]); s = 0.5 * (x[:, 0] - x[:, 1])
    X = np.fft.rfft(np.stack([m, s], axis=1), axis=0)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)

    def sm(lo, hi):
        k = (f >= lo) & (f < hi)
        return float(10 * np.log10(np.sum(np.abs(X[k, 1]) ** 2) / max(np.sum(np.abs(X[k, 0]) ** 2), 1e-20)))

    # punch: crest of the 40-120 Hz band envelope (kick against sustained bass), and overall PLR
    lowenv = band_env(x, SR, 40.0, 120.0, 0.01)
    return {"lufs": round(lufs, 2), "lra": round(loudness_range(x, SR, xk), 1), "tp": round(tp, 2), "plr": round(tp - lufs, 1),
            "crest": round(crest_db(x), 1), "corr": round(stereo_corr(x), 2), "side_mid": round(side_mid_db(x), 1),
            "side_mid_<120": round(sm(20, 120), 1), "side_mid_2k-8k": round(sm(2000, 8000), 1), "side_mid_>8k": round(sm(8000, 20000), 1),
            "sub_30-60": round(share(28, 56), 1), "bass_60-250": round(share(56, 280), 1), "mid_250-2k": round(share(280, 2240), 1),
            "pres_2k-8k": round(share(2240, 8900), 1), "air_>8k": round(share(8900, 21000), 1),
            "low_band_dyn_p95-p10": round(float(np.percentile(lowenv, 95) - np.percentile(lowenv, 10)), 1)}, fc, v


if __name__ == "__main__":
    old_full = read_audio(alib.PROJ + "/assets/audio/music/title_theme.ogg", SR)
    a = int(60.0 * SR); b = int(91.6 * SR)
    old = old_full[a:b].copy()
    new = read_audio(OUT + "/title_remaster_excerpt.wav", SR)
    res = {}
    series = []
    for name, x, col in (("alt (title_theme.ogg 1:00–1:30)", old, (140, 170, 255)), ("neu (Remaster-Skizze)", new, (255, 90, 90))):
        r, fc, v = measure(x[:int(30.0 * SR)])
        res[name] = r
        series.append((name, fc, v, col))
        print(name, json.dumps(r))
    line_plot(series, OUT + "/title_spectrum_old_vs_new.png", "Titelmelodie Pre-Chorus + Refrain: Terzspektrum alt / Remaster-Skizze (beide −14 LUFS)", "Hz", "dB", logx=True, xlim=(25, 20000), w=1100)
    im_o, ref = spectrogram_img(old, SR, w=1500, h=330, win=4096)
    im_n, _ = spectrogram_img(new, SR, w=1500, h=330, ref_db=ref, win=4096)
    stack_images([("ALT – Titelmelodie v0.7.0, Takt 33–48 (Pre-Chorus 1, Refrain 1), 44,1 kHz Vorbis", im_o),
                  ("NEU – Remaster-Skizze derselben Takte: 48 kHz, geschichtete Drums, Sub-Bass, vier Gitarren-Takes, breiter Lead, Multiband-Master", im_n)],
                 OUT + "/title_spectrogram_old_vs_new.png", "Titelmelodie – alt gegen Remaster-Skizze")
    json.dump(res, open(OUT + "/title_compare.json", "w"), indent=1, ensure_ascii=False)
