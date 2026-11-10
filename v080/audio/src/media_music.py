#!/usr/bin/env python3
"""Spike 2 media: MP3s and MP4s (spectrogram with playhead) of the music sketches."""
import os, shutil, subprocess
import numpy as np
import alib
from alib import *
from PIL import Image, ImageDraw

W = alib.WORK
OUT = W + "/out"
DEL = W + "/deliver/musik"
os.makedirs(DEL, exist_ok=True)
SR = 48000


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


def video(panels, title, name, gap=0.6):
    """panels: [(label, audio)] played one after the other; one spectrogram per panel with a playhead."""
    PW, PH, pad, y = 1200, 300, 30, 40
    ims, ref = [], None
    for _, x in panels:
        im, ref = spectrogram_img(x, SR, w=PW, h=PH, ref_db=ref)
        ims.append(im)
    Wd = ims[0].size[0] + (ims[0].size[0] % 2)
    Hd = y + len(panels) * (ims[0].size[1] + pad)
    Hd += Hd % 2
    canvas = Image.new("RGB", (Wd, Hd), (16, 16, 20))
    dr = ImageDraw.Draw(canvas)
    dr.text((10, 8), title, fill=(255, 255, 255), font=font(17, True))
    ys = []
    for (label, _), im in zip(panels, ims):
        dr.text((10, y + 6), label, fill=(255, 220, 140), font=font(14, True))
        canvas.paste(im, (0, y + pad))
        ys.append(y + pad + 22)
        y += im.size[1] + pad
    png = OUT + "/_vbg.png"
    canvas.save(png)
    parts, starts, t = [], [], 0.0
    for _, x in panels:
        starts.append((t, len(x) / SR))
        parts += [x, np.zeros((int(gap * SR), 2))]
        t += len(x) / SR + gap
    audio = np.concatenate(parts[:-1])
    wav = OUT + "/_v.wav"
    write_wav(wav, audio, SR)
    xe, ye = "56", str(ys[-1])
    for (t0, d), yy in reversed(list(zip(starts, ys))):
        xe = f"if(gte(t\\,{t0:.3f})\\,56+min(t-{t0:.3f}\\,{d:.3f})/{d:.3f}*{PW - 1}\\,{xe})"
        ye = f"if(gte(t\\,{t0:.3f})\\,{yy}\\,{ye})"
    ff("-loop", "1", "-framerate", "25", "-i", png, "-i", wav, "-f", "lavfi", "-i", f"color=c=white:s=2x{PH}:r=25",
       "-filter_complex", f"[0:v][2:v]overlay=x='{xe}':y='{ye}':shortest=1,format=yuv420p[v]",
       "-map", "[v]", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "25", "-tune", "stillimage",
       "-c:a", "aac", "-b:a", "192k", "-t", f"{len(audio) / SR:.2f}", os.path.join(DEL, name))
    os.remove(wav); os.remove(png)


old_full = read_audio(alib.PROJ + "/assets/audio/music/title_theme.ogg", SR)
old = old_full[int(60.0 * SR):int(91.6 * SR)].copy()
f = int(1.5 * SR)
old[-f:] *= np.linspace(1.0, 0.0, f)[:, None] ** 2
new = read_audio(OUT + "/title_remaster_excerpt.wav", SR)
race = read_audio(OUT + "/race_track_sketch.wav", SR)
mix = read_audio(OUT + "/race_mix_demo.wav", SR)
mp3(old, "titel_alt_ausschnitt_1m00.mp3")
mp3(new, "titel_remaster_skizze.mp3")
mp3(np.concatenate([old, np.zeros((int(0.6 * SR), 2)), new]), "titel_ab_erst_alt_dann_remaster.mp3")
mp3(race, "rennmusik_linke_spur_skizze.mp3")
mp3(mix, "rennmix_musik_unter_motor.mp3")
video([("ALT – Titelmelodie v0.7.0, Pre-Chorus 1 + Refrain 1 (1:00–1:30)", old), ("NEU – Remaster-Skizze derselben Takte", new)],
      "Crossing Europe v0.8.0 – Titelmelodie: erst ALT, dann Remaster-Skizze", "titel_alt_remaster_spektrogramm.mp4")
video([("Rennmusik-Skizze „Linke Spur“ (d-Moll, 132 bpm): Einzähler, A, B, Schluss", race),
       ("Rennmix-Skizze: Countdown, Einzähler landet auf „Go“, Musik unter dem Motor (Seitenkette −4 dB)", mix)],
      "Crossing Europe v0.8.0 – Musik im Rennen (Skizze)", "rennmusik_und_rennmix_spektrogramm.mp4")
for fn in ("title_spectrum_old_vs_new.png", "title_spectrogram_old_vs_new.png", "title_compare.json", "race_track_spectrogram.png",
           "race_track_spectrum.png", "race_track_checks.json", "race_mix_loudness.png", "race_mix_ducking.png", "race_mix_info.json"):
    shutil.copy(os.path.join(OUT, fn), os.path.join(DEL, fn))
print(sorted(os.listdir(DEL)))
