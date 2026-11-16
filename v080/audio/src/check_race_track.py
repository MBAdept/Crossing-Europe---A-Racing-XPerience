#!/usr/bin/env python3
"""Spike 2b checks: chords per bar (chroma), key, onsets on the grid, loudness per section, spectrum, pictures."""
import json, os, sys
import numpy as np
import alib
from alib import *
import music_synth as ms
import music2lib as m2
import race_track as rt
from compare_music import measure

W = alib.WORK
OUT = W + "/out"
m2.setup(48000, rt.BPM)
import music_preview as mp
mp.SR = 48000
SR = 48000
x = read_audio(OUT + "/race_track_sketch.wav", SR)


class B:
    pass


bars = []
for i in range(rt.BARS):
    b = B(); b.t = i * ms.BAR; bars.append(b)
X_ = np.fft.rfft(x, axis=0)
f_ = np.fft.rfftfreq(len(x), 1.0 / SR)
X_[f_ < 130.0] = 0.0                      # the four-on-the-floor kick layers put a comb of lines below 120 Hz
ch = mp.chroma_bars(np.fft.irfft(X_, len(x), axis=0), bars)
tpl = mp.triad_templates()
want = {"Dm": "Dm", "Bb": "A#", "C": "C", "F": "F", "A": "A"}
ok = 0
rows = []
for i in range(2, 18):
    best = max(tpl.items(), key=lambda kv: float(np.dot(kv[1], ch[i])))[0]
    rootpc = int(np.argmax(ch[i]))
    exp = want[rt.CHORDS[i]]
    hit = best == exp
    ok += hit
    rows.append((i + 1, rt.CHORDS[i], best, mp.NOTE_NAMES[rootpc]))
print("Akkorde je Takt (Soll / erkannt / stärkste Tonklasse):", rows)
print("erkannt %d von 16" % ok, "| Tonart:", mp.key_of(ch[2:18].sum(axis=0)))
# onsets: energy flux in the kick band, compare with the 4-on-the-floor grid in bars 3-18
env = band_env(x, SR, 35.0, 110.0, 0.002)
t_env = (np.arange(len(env)) + 0.5) * 0.002
d = np.diff(env, prepend=env[0])
errs = []
for bi in range(2, 18):
    for beat in range(4):
        t = bi * ms.BAR + beat * ms.BEAT
        k = (t_env > t - 0.03) & (t_env < t + 0.04)
        if np.any(k):
            tt = t_env[k][np.argmax(d[k])]
            errs.append(tt - t)
errs = np.array(errs) * 1000.0
print("Kick-Einsätze gegen das Raster: Mittel %.1f ms, Streuung %.1f ms, max |%.1f| ms (n=%d)" % (errs.mean(), errs.std(), np.max(np.abs(errs)), len(errs)))
res = {"chords_ok": int(ok), "key": mp.key_of(ch[2:18].sum(axis=0)), "kick_grid_ms": [round(float(errs.mean()), 2), round(float(errs.std()), 2)]}
sec = {"Einzähler (Takt 1–2)": (0, 2), "A (Takt 3–10)": (2, 10), "B (Takt 11–18)": (10, 18)}
xk = k_weight(x, SR)
for nm, (a, b) in sec.items():
    s = slice(int(a * ms.BAR * SR), int(b * ms.BAR * SR))
    l = -0.691 + 10 * np.log10(np.mean(np.sum(xk[s] ** 2, axis=1)))
    print("%-24s %.1f LUFS" % (nm, l))
    res[nm] = round(float(l), 1)
r, fc, v = measure(x[int(2 * ms.BAR * SR):int(18 * ms.BAR * SR)])
print(json.dumps(r))
res["measure"] = r
old_full = read_audio(alib.PROJ + "/assets/audio/music/title_theme.ogg", SR)
ro, fco, vo = measure(old_full[int(75 * SR):int(105 * SR)])
line_plot([("Titelmelodie v0.7.0 (Refrain/Strophe 1:15–1:45)", fco, vo, (140, 170, 255)), ("Rennmusik-Skizze „Linke Spur“ (Takt 3–18)", fc, v, (255, 90, 90))],
          OUT + "/race_track_spectrum.png", "Terzspektrum: Rennmusik-Skizze gegen die heutige Titelmelodie", "Hz", "dB", logx=True, xlim=(25, 20000), w=1100)
im, _ = spectrogram_img(x, SR, w=1500, h=380)
stack_images([("Rennmusik-Skizze „Linke Spur“: d-Moll, 132 bpm – 2 Takte Einzähler | A: Groove + Motiv | B: Hook mit Harmoniestimme | Schluss", im)],
             OUT + "/race_track_spectrogram.png", "")
json.dump(res, open(OUT + "/race_track_checks.json", "w"), indent=1, ensure_ascii=False)
