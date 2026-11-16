#!/usr/bin/env python3
"""Spectrogram sheet of qa_race_sound.gd captures: one row per WAV (log frequency 30 Hz .. 16 kHz), the feed intervals
(paving) as a coloured strip under each row, joint / collision / impact marks as white ticks.
Usage: spec_sheet.py <out.png> <wav> [<wav> …]"""
import json
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw

COL = {"asphalt": (90, 90, 96), "concrete": (200, 200, 190), "cobbles": (190, 120, 60), "deck": (70, 140, 220)}


def read(p):
    with wave.open(p, "rb") as w:
        n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
    return x.reshape(-1, ch), sr


def spec(x, sr, width=1100, height=200, fmin=30.0, fmax=16000.0):
    mono = x.mean(axis=1)
    win = 4096
    hop = max(128, (len(mono) - win) // width)
    frames = max(1, (len(mono) - win) // hop)
    w = np.hanning(win)
    norm = w.sum() / 2.0
    freqs = np.fft.rfftfreq(win, 1.0 / sr)
    rows = np.geomspace(fmin, fmax, height)
    cols = np.empty((frames, height), dtype=np.float32)
    for i in range(frames):
        seg = mono[i * hop:i * hop + win] * w
        cols[i] = np.interp(rows, freqs, np.abs(np.fft.rfft(seg)) / norm)
    s = np.clip((20 * np.log10(cols + 1e-9) + 96.0) / 84.0, 0.0, 1.0)
    a = np.asarray(Image.fromarray((s.T[::-1] * 255).astype(np.uint8)).resize((width, height), Image.BILINEAR)).astype(np.float32) / 255.0
    r = np.clip(a * 2.0 - 0.6, 0, 1)
    g = np.clip(a * 2.2 - 1.2, 0, 1)
    b = np.clip(np.where(a < 0.5, a * 1.8, 1.8 - a * 1.8), 0, 1)
    return Image.fromarray((np.stack([r, g, b], axis=2) * 255).astype(np.uint8))


out = sys.argv[1]
tiles = []
for p in sys.argv[2:]:
    x, sr = read(p)
    dur = len(x) / sr
    info = json.load(open(p[:-4] + ".json"))
    log = info.get("log", [])
    sp = spec(x, sr)
    W, H = sp.size
    tile = Image.new("RGB", (W, H + 34), (10, 12, 20))
    tile.paste(sp, (0, 0))
    d = ImageDraw.Draw(tile)
    feeds = [e for e in log if e["kind"] == "feed"]
    for i, fe in enumerate(feeds):
        t0 = fe["t"]
        t1 = feeds[i + 1]["t"] if i + 1 < len(feeds) else dur
        c = COL.get(fe["state"]["paving"], (60, 60, 60))
        d.rectangle([int(t0 / dur * W), H + 2, int(t1 / dur * W), H + 12], fill=c)
        d.text((int(t0 / dur * W) + 2, H + 14), fe["state"]["paving"], fill=(230, 230, 230))
    for e in log:
        if e["kind"] in ("play", "event") and any(k in e["name"] for k in ("joint", "collision", "impact", "rail")):
            xx = int(e["t"] / dur * W)
            d.line([(xx, 0), (xx, 12)], fill=(255, 255, 255), width=2)
    d.text((6, 4), "%s  (%.1f s, %s)" % (os.path.basename(p), dur, info.get("profile")), fill=(255, 255, 255))
    for fq, lab in ((100.0, "100 Hz"), (1000.0, "1 kHz"), (10000.0, "10 kHz")):
        yy = int(H - 1 - np.log(fq / 30.0) / np.log(16000.0 / 30.0) * (H - 1))
        d.line([(W - 40, yy), (W - 30, yy)], fill=(220, 220, 220))
        d.text((W - 28, yy - 6), lab, fill=(220, 220, 220))
    tiles.append(tile)
sheet = Image.new("RGB", (tiles[0].width, sum(t.height + 4 for t in tiles)), (0, 0, 0))
y = 0
for t in tiles:
    sheet.paste(t, (0, y))
    y += t.height + 4
sheet.save(out)
print(out, sheet.size)
