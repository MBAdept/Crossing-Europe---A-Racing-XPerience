#!/usr/bin/env python3
"""AU-D1 deliverables (scratch tool, not part of the repo): MP3s and pictures for the user."""
import json
import os
import shutil
import subprocess
import sys

import numpy as np

SCR = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1"
sys.path.insert(0, SCR + "/audio/src")
import alib  # noqa: E402  (study helpers: spectrogram_img, stack_images, line_plot, short_term)

OUT = SCR + "/deliver/AU-D1"
TMP = SCR + "/m1/AU-D1/media_tmp"
CAP = SCR + "/m1/AU-D1/cap"
MUSIC = WT + "/assets/audio/modern/music"
SR = 44100
BPM = 132.0
BAR = 240.0 / BPM
F_BODY = 721636
LOOP = 7056000
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)


def read(path):
    return alib.read_audio(path, SR, 2)


def mp3(x, name, fade_s=0.0):
    x = np.array(x, np.float64)
    if fade_s > 0:
        f = int(fade_s * SR)
        x[-f:] *= (np.linspace(1.0, 0.0, f) ** 2)[:, None]
    tmp = TMP + "/_tmp.wav"
    alib.write_wav(tmp, x, SR)
    r = subprocess.run([shutil.which("ffmpeg"), "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k",
                        os.path.join(OUT, name)], capture_output=True, text=True)
    os.remove(tmp)
    if r.returncode:
        print("ffmpeg:", r.stderr[-400:])
    print("  %s  %.1f s" % (name, len(x) / SR))


def lufs(x):
    return alib.integrated_lufs(x, SR)


main = read(MUSIC + "/linke_spur.ogg")
ending = read(MUSIC + "/linke_spur_schluss.ogg")
title_new = read(MUSIC + "/titel_remaster.ogg")
title_old = read(WT + "/assets/audio/music/title_theme.ogg")

# 1. race track alone, 45 s from the start (count-in, A1, B1, A2 start)
mp3(main[: int(45.0 * SR)], "rennmusik_linke_spur_skizze_45s.mp3", 1.5)

# 2. the race mix from the game (capture_mix.gd, scenario race_music, Gran Turismo)
mix = read(CAP + "/race_mix.wav")
mp3(mix, "rennmix_linke_spur_unter_motor.mp3", 1.0)

# 3. the complete piece as a race plays it: count-in and A1, the loop once, then the ending at the next bar line
#    (the loop stops within 1 ms at the bar line – FADE_DISABLED – and the ending sets in at full level, as in the game)
L = len(main)
cont = main[F_BODY:F_BODY + 44].copy()
cont *= np.linspace(1.0, 0.0, len(cont))[:, None]
full = np.zeros((L + len(ending), 2))
full[:L] = main
full[L:L + len(ending)] += ending
full[L:L + len(cont)] += cont
mp3(full, "rennmusik_linke_spur_komplett_mit_schluss.mp3")

# 4. title A/B: the old theme 1:00–1:31.6 (pre-chorus 1, chorus 1), then the same bars of the remaster
a, b = int(60.0 * SR), int(91.6 * SR)
old_x = title_old[a:b].copy()
new_x = title_new[a:b].copy()
f = int(1.5 * SR)
for x in (old_x, new_x):
    x[-f:] *= (np.linspace(1.0, 0.0, f) ** 2)[:, None]
mp3(np.concatenate([old_x, np.zeros((int(0.8 * SR), 2)), new_x]), "titel_ab_erst_alt_dann_remaster.mp3")
mp3(title_new, "titel_remaster_komplett.mp3", 2.0)

# --- pictures ---------------------------------------------------------------------------------------------------
im_o, ref = alib.spectrogram_img(old_x, SR, w=1500, h=330, win=4096)
im_n, _ = alib.spectrogram_img(new_x, SR, w=1500, h=330, ref_db=ref, win=4096)
alib.stack_images([("ALT – Titelmelodie v0.5.0/v0.7.0, Takt 33–49 (Pre-Chorus 1, Refrain 1), Vorbis 44,1 kHz", im_o),
                   ("NEU – Titel-Remaster derselben Takte: gleiche Noten, geschichtete Drums, Sub-Bass, vier Gitarren-Takes, breiter Lead, Mehrband-Master", im_n)],
                  OUT + "/titel_spektrogramm_alt_gegen_remaster.png", "Titelmelodie – alt gegen Remaster (gleiche Lautheit, −14 LUFS)")
fc, vo = alib.third_octave(old_x, SR, 25, 20000)
_, vn = alib.third_octave(new_x, SR, 25, 20000)
alib.line_plot([("alt", fc, vo, (140, 170, 255)), ("Remaster", fc, vn, (255, 90, 90))], OUT + "/titel_terzspektrum_alt_gegen_remaster.png",
               "Titelmelodie Pre-Chorus + Refrain: Terzspektrum alt / Remaster (beide −14 LUFS)", "Hz", "dB", logx=True, xlim=(25, 20000), w=1100)

# the whole race piece: spectrogram with the phrases
im_r, _ = alib.spectrogram_img(full, SR, w=1800, h=380, win=4096)
from PIL import ImageDraw  # noqa: E402
dr = ImageDraw.Draw(im_r)
labels = ["Ein", "A1", "B1", "A2", "P1", "B2", "D", "S", "P2", "B3", "A3", "T", "A1", "Schluss"]
starts = [0, 1, 9, 17, 25, 33, 41, 49, 57, 65, 73, 81, 89, 97]
dur = len(full) / SR
for lab, bi in zip(labels, starts):
    t = bi * BAR
    x0 = 56 + int(round(t / dur * 1799))
    dr.line([(x0, 22), (x0, 22 + 380)], fill=(255, 255, 255), width=1)
    dr.text((x0 + 3, 24), lab, fill=(255, 255, 255), font=alib.font(13, True))
alib.stack_images([("Rennmusik 1 „Linke Spur“ (d-Moll, 132 bpm): Einzähler, A1, dann die Schleife B1 … T, A1 (88 Takte = 160 s) und der Schluss am Taktstrich", im_r)],
                  OUT + "/rennmusik_linke_spur_spektrogramm.png", "")

# race mix: momentary loudness of car + music, the music alone (same drive), the plan's ducking
alone = read(CAP + "/race_music_alone.wav")
meta = json.load(open(CAP + "/race_mix.json"))
n = min(len(mix), len(alone))
lm = alib.short_term(mix[:n], SR, 0.4, 0.1)
la = alib.short_term(alone[:n], SR, 0.4, 0.1)
tm = np.arange(len(lm)) * 0.1 + 0.2
alib.line_plot([("Auto + Musik (Spiel, Gran Turismo)", tm, lm, (255, 90, 90)), ("Musik allein (gleiche Fahrt, MEnv stumm)", tm, la, (120, 220, 160))],
               OUT + "/rennmix_lautheit.png", "Rennmix aus dem Spiel: momentane Lautheit (400 ms) – Leerlauf, Vollgas durch die Gänge, Höchsttempo, Gas weg, 130 km/h",
               "Zeit (s)", "LUFS", ylim=(-40, -8), w=1500)
ph = meta["phases"]
xs, ys = [], []
for p in ph:
    xs += [p["t0"], p["t1"]]
    ys += [p.get("duck_db", 0.0), p.get("duck_db", 0.0)]
alib.line_plot([("Absenkung der Musik je Abschnitt (Mittel, dB)", xs, ys, (120, 220, 160))], OUT + "/rennmix_ducking.png",
               "Ducking der Musik unter dem Auto (geskriptet, Fader auf MMusic)", "Zeit (s)", "dB", ylim=(-6, 1), w=1500, h=260)

info = {"lufs": {"skizze_45s": round(lufs(main[: int(45 * SR)]), 2), "komplett": round(lufs(full), 2),
                 "titel_alt_ausschnitt": round(lufs(old_x), 2), "titel_remaster_ausschnitt": round(lufs(new_x), 2),
                 "rennmix": round(lufs(mix), 2)},
        "true_peak": {"rennmix": round(alib.true_peak_db(mix), 2), "komplett": round(alib.true_peak_db(full), 2)},
        "seconds": {"komplett": round(len(full) / SR, 2), "rennmix": round(len(mix) / SR, 2)}}
json.dump(info, open(TMP + "/media_info.json", "w"), indent=1)
print(json.dumps(info, indent=1))
