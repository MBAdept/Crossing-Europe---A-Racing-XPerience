#!/usr/bin/env python3
"""Spike 1 media: MP3s (old, new, A/B per phase) and an MP4 with the spectrograms and a playhead."""
import os, subprocess, shutil
import numpy as np
import alib
from alib import *
from engine3 import Trace
from PIL import Image, ImageDraw

W = alib.WORK
OUT = W + "/out"
DEL = W + "/deliver/motor"
os.makedirs(DEL, exist_ok=True)
SR = 48000
tr = Trace(OUT + "/drive_old.csv")
old = read_audio(OUT + "/drive_old.wav", SR)
new = read_audio(OUT + "/drive_new_full.wav", SR)
eng = read_audio(OUT + "/drive_new_engine_only.wav", SR)
n = min(len(old), len(new))
old, new, eng = old[:n], new[:n], eng[:n]


def ff(*args):
    r = subprocess.run([shutil.which("ffmpeg"), "-y", "-loglevel", "error", *args], capture_output=True, text=True)
    if r.returncode != 0:
        print("ffmpeg:", r.stderr[-500:])
    return r.returncode == 0


def mp3(x, name):
    tmp = OUT + "/_tmp.wav"
    write_wav(tmp, x, SR)
    ff("-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k", os.path.join(DEL, name))
    os.remove(tmp)


mp3(old, "motor_alt_spiel_v070.mp3")
mp3(new, "motor_neu_komplett.mp3")
mp3(eng, "motor_neu_nur_antrieb.mp3")

# A/B per phase: old, short pause, new
segs = [("Vollgas durch die Gänge", tr.phase_time("launch")[0] - 0.3, tr.phase_time("launch")[1]),
        ("Vollgas 266 km/h, Gas weg, Bremsen", tr.phase_time("flat_out")[0], tr.phase_time("brake")[1] + 0.3),
        ("130 km/h, Kick-down, Stopp", tr.phase_time("cruise130")[0], tr.phase_time("idle_end")[0] + 0.8)]
gap = np.zeros((int(0.5 * SR), 2))
parts, marks, t = [], [], 0.0
for name, a, b in segs:
    for label, x in (("ALT", old), ("NEU", new)):
        s = x[int(a * SR):int(b * SR)].copy()
        f = int(0.03 * SR)
        s[:f] *= np.linspace(0, 1, f)[:, None]
        s[-f:] *= np.linspace(1, 0, f)[:, None]
        parts += [s, gap]
        marks.append((t, t + len(s) / SR, "%s – %s" % (label, name)))
        t += (len(s) + len(gap)) / SR
ab = np.concatenate(parts)
mp3(ab, "motor_ab_alt_neu_im_wechsel.mp3")
with open(os.path.join(DEL, "motor_ab_alt_neu_im_wechsel.txt"), "w") as fh:
    for a, b, lab in marks:
        fh.write("%5.1f – %5.1f s  %s\n" % (a, b, lab))

# video: two panels (old / new complete), playhead runs over the old panel first, then over the new one
PW, PH = 1200, 300
im_o, ref = spectrogram_img(old, SR, w=PW, h=PH)
im_n, _ = spectrogram_img(new, SR, w=PW, h=PH, ref_db=ref)
pad = 30
Wd = im_o.size[0]
canvas = Image.new("RGB", (Wd + (Wd % 2), 2 * (im_o.size[1] + pad) + 40 + ((2 * (im_o.size[1] + pad) + 40) % 2)), (16, 16, 20))
dr = ImageDraw.Draw(canvas)
dr.text((10, 8), "Crossing Europe v0.8.0 – Motorklang-Studie (Gran Turismo): erst ALT, dann NEU, gleiche Fahrt", fill=(255, 255, 255), font=font(17, True))
y0 = 40
dr.text((10, y0 + 6), "ALT – Spiel v0.7.0", fill=(255, 220, 140), font=font(14, True))
canvas.paste(im_o, (0, y0 + pad))
y1 = y0 + pad + im_o.size[1]
dr.text((10, y1 + 6), "NEU – Studie „Modern“ (Stereo-Bank 48 kHz, Turbo, Reifen, Wind, Fugen, Reflexionen)", fill=(255, 220, 140), font=font(14, True))
canvas.paste(im_n, (0, y1 + pad))
png = OUT + "/_video_bg.png"
canvas.save(png)
dur = n / SR
both = np.concatenate([old, np.zeros((int(0.6 * SR), 2)), new])
wav = OUT + "/_video.wav"
write_wav(wav, both, SR)
ml, mt = 56, 22
t2 = dur + 0.6
xexpr = f"if(lt(t\\,{dur:.3f})\\,{ml}+t/{dur:.3f}*{PW - 1}\\,{ml}+max(t-{t2:.3f}\\,0)/{dur:.3f}*{PW - 1})"
yexpr = f"if(lt(t\\,{dur + 0.3:.3f})\\,{y0 + pad + mt}\\,{y1 + pad + mt})"
ff("-loop", "1", "-framerate", "25", "-i", png, "-i", wav, "-f", "lavfi", "-i", f"color=c=white:s=2x{PH}:r=25",
   "-filter_complex", f"[0:v][2:v]overlay=x='{xexpr}':y='{yexpr}':shortest=1,format=yuv420p[v]",
   "-map", "[v]", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "25", "-tune", "stillimage",
   "-c:a", "aac", "-b:a", "192k", "-t", f"{len(both) / SR:.2f}", os.path.join(DEL, "motor_alt_neu_spektrogramm.mp4"))
os.remove(wav); os.remove(png)
for f in ("drive_spectrogram_old_vs_new.png", "drive_loudness_old_vs_new.png", "drive_spectrum_flat.png", "drive_spectrum_cruise.png",
          "drive_stereo_corr.png", "drive_compare.json", "inplay_gt_spectrogram.png"):
    shutil.copy(os.path.join(OUT, f), os.path.join(DEL, f))
print(os.listdir(DEL))
