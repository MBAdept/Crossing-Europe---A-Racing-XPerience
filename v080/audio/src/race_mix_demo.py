#!/usr/bin/env python3
"""Spike 2c: how the in-race music sits under the car - countdown, the track's count-in lands on "Go", the
modern vehicle sound of spike 1 on top, music ducked by the car bus (what an AudioEffectCompressor with
sidechain on the Music bus would do) and a mid dip in the music's EQ while racing."""
import json, math, os
import numpy as np
import alib
from alib import *
import music_synth as ms
import music2lib as m2
from engine3 import Trace, lookahead_limiter, smooth_ar

W = alib.WORK
OUT = W + "/out"
SR = 48000
m2.setup(SR, 132.0)
tr = Trace(OUT + "/drive_old.csv")
car = read_audio(OUT + "/drive_new_full.wav", SR)
mus = read_audio(OUT + "/race_track_sketch.wav", SR)
info = json.load(open(OUT + "/race_track_info.json"))
t_go = tr.phase_time("launch")[0]
t_mus = t_go - info["downbeat_s"]
T = 37.9
n = int(T * SR)
car = car[:n] * 10 ** (-3.0 / 20.0)                     # modern loudness plan: car 3 dB lower than today
# countdown: three beeps and "Go" (the game's SfxSynth.beep: 784 Hz 0.18 s, 1568 Hz 0.7 s)
ui = np.zeros((n, 2))
for k, (f, dur, dec) in enumerate(((784.0, 0.18, 4.0), (784.0, 0.18, 4.0), (784.0, 0.18, 4.0), (1568.0, 0.7, 2.5))):
    t0 = t_go - (3 - k) * 1.0
    m = int(dur * SR)
    t = np.arange(m) / SR
    y = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(6 * np.pi * f * t) + 0.12 * np.sin(10 * np.pi * f * t))
    y *= np.minimum(1.0, t / 0.004) * np.minimum(1.0, (dur - t) / 0.03) * np.exp(-t * dec)
    a = int(t0 * SR)
    ui[a:a + m] += (0.16 * y)[:, None]
# music bus in the race: mid dip (pocket for the engine), level, sidechain ducking from the car bus
music = np.zeros((n, 2))
a = int(t_mus * SR)
m = min(len(mus), n - a)
music[a:a + m] = mus[:m]
music = ms.apply_eq(music, [("peak", 520.0, -3.0, 0.6), ("ls", 90.0, -1.5)])
MUSIC_DB = -4.5                                           # -14 LUFS file -> about -20 LUFS when the car is quiet
music *= 10 ** (MUSIC_DB / 20.0)
ck = k_weight(car, SR)
hop = int(0.01 * SR)
p = np.sum(ck * ck, axis=1)
lvl = np.array([-0.691 + 10 * np.log10(max(np.mean(p[i:i + 4 * hop]), 1e-12)) for i in range(0, n, hop)])
want = -4.0 * np.clip((lvl - (-32.0)) / 12.0, 0.0, 1.0)   # 0 dB below -32 LUFS .. -4 dB above -20 LUFS (car bus)
duck_db = -smooth_ar(-want, 0.05, 0.45, 100.0)
duck = 10 ** (np.interp(np.arange(n) / SR, np.arange(len(duck_db)) * 0.01, duck_db) / 20.0)
music_d = music * duck[:, None]
mix = lookahead_limiter(car + music_d + ui, -1.0)
f = int(1.2 * SR)
mix[-f:] *= np.linspace(1.0, 0.0, f)[:, None]
write_wav(OUT + "/race_mix_demo.wav", mix, SR)
tm = np.arange(len(short_term(mix, SR, 0.4, 0.1))) * 0.1 + 0.2
line_plot([("Auto (Studie, −3 dB)", tm, short_term(car, SR, 0.4, 0.1), (255, 190, 90)),
           ("Musik nach Ducking", tm, short_term(music_d, SR, 0.4, 0.1), (120, 220, 160)),
           ("Summe", tm, short_term(mix, SR, 0.4, 0.1), (255, 90, 90))],
          OUT + "/race_mix_loudness.png", "Rennmix-Skizze: momentane Lautheit (400 ms) – Countdown, Einzähler landet auf „Go“ bei %.1f s" % t_go,
          "Zeit (s)", "LUFS", ylim=(-45, -8), w=1500)
line_plot([("Ducking der Musik (dB)", np.arange(len(duck_db)) * 0.01, duck_db, (120, 220, 160))], OUT + "/race_mix_ducking.png",
          "Seitenkette: Absenkung des Music-Busses durch den Auto-Bus", "Zeit (s)", "dB", ylim=(-5, 0), w=1500, h=260)


def seg(x, a_, b_):
    xk = k_weight(x[int(a_ * SR):int(b_ * SR)], SR)
    return round(float(-0.691 + 10 * np.log10(max(np.mean(np.sum(xk * xk, axis=1)), 1e-12))), 1)


la, lb = tr.phase_time("launch")
fa, fb = tr.phase_time("flat_out")
res = {"t_go": round(t_go, 2), "music_start": round(t_mus, 3), "music_db": MUSIC_DB,
       "vollgas_durch_die_gaenge": {"auto": seg(car, la + 1, lb), "musik": seg(music_d, la + 1, lb), "summe": seg(mix, la + 1, lb)},
       "vollgas_266": {"auto": seg(car, fa, fb), "musik": seg(music_d, fa, fb), "summe": seg(mix, fa, fb)},
       "gas_weg": {"auto": seg(car, *tr.phase_time("lift")), "musik": seg(music_d, *tr.phase_time("lift")), "summe": seg(mix, *tr.phase_time("lift"))},
       "duck_db_min": round(float(duck_db.min()), 2), "true_peak": round(true_peak_db(mix), 2),
       "integrated": round(integrated_lufs(mix, SR), 2)}
json.dump(res, open(OUT + "/race_mix_info.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(res, indent=1, ensure_ascii=False))
