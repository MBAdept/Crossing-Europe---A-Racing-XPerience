#!/usr/bin/env python3
"""Titelmelodie - checks, pictures and previews of the title theme (nobody listens during development).

Reads the encoded file as the game plays it (assets/audio/music/title_theme.ogg, decoded with ffmpeg) and, when
given, the full master of the render (music_synth.py --wav DIR -> DIR/master_full.wav: intro + body + the loop's
continuation), and checks:

  loudness   integrated loudness and loudness range (ITU-R BS.1770-4, EBU Tech 3342), true peak, sample peak
             of the decoded Vorbis file; short-term loudness per section
  balance    1/3-octave long-term spectrum against a rock/pop tonal-balance target; stereo correlation and side
             level per section; low end (< 120 Hz) mono
  harmony    chroma per bar (STFT 55 Hz .. 2 kHz) against the arrangement's chord (music_synth.SECTIONS): share of
             bars whose best-matching triad is the intended one; key of every section (E minor / F# minor)
  loop seam  the decoded file played across the loop point (end -> loop_offset) like Godot does: sample step at the
             seam against the file's own step statistics, high-pass click detector (2 ms energy at the seam vs. the
             surrounding 200 ms); with the master: difference between what the loop plays after the seam and the
             music's true continuation (rendered after the body)

Writes into --out: checks.json, spectrogram.png (log frequency, sections), loudness.png (momentary and short-term
loudness, sections), seam.png (waveform around the seam: played vs. true continuation), overview.png (section map
with chords and instruments), sections.md, title_theme_preview.mp3 (the file once plus 20 s of the loop's second
pass, fading out), seam_demo.mp3 (12 s before and after the seam), title_theme.ogg (copy) and
title_theme_preview.mp4 (spectrogram with a moving playhead, H.264 + AAC).

Usage:
  python3 tools/audio/music_preview.py --out DIR [--ogg assets/audio/music/title_theme.ogg]
                                       [--master DIR/master_full.wav] [--no-media]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_synth as ms  # noqa: E402  (timeline, loudness, decoding)

SR = ms.SR
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SECTION_COLORS = {
    "intro": (90, 70, 160), "theme": (230, 60, 140), "verse1": (40, 140, 200), "pre1": (240, 160, 40),
    "chorus1": (230, 50, 90), "verse2": (40, 140, 200), "pre2": (240, 160, 40), "chorus2": (230, 50, 90),
    "bridge": (60, 180, 150), "solo": (250, 110, 30), "final": (255, 40, 70), "outro": (120, 90, 200),
}
INSTRUMENTS = {   # overview text per section (German)
    "intro": "FM-Glocken mit dem Motiv, Pad, Arpeggio öffnet den Filter, Riser; Turnaround D–B mit Stabs und Tom-Fill",
    "theme": "Hook auf der Leadgitarre (Synth im Unisono), Rhythmusgitarren im 3-3-2-Akzent, Oktavbass, treibendes Schlagzeug",
    "verse1": "gedämpfte Gitarren-Achtel (Palm Mutes), Rockbeat, Arpeggio; ab Takt 25 Strophenmelodie (weicher Synth)",
    "pre1": "Steigerung: offene Akkorde, Synth-Brass, Melodie steigt, Snare-Wirbel, Riser",
    "chorus1": "Hook auf dem Synth-Lead, Gitarrenwand (offene Achtel), Four-on-the-floor mit Clap",
    "verse2": "Strophe mit Melodie, Ghost-Hi-Hats",
    "pre2": "wie Pre-Chorus 1",
    "chorus2": "Hook mit Terz-Harmoniestimme",
    "bridge": "Breakdown: Glocken, Pad, Arpeggio, Puls-Bass; Halftime, Snare-Wirbel",
    "solo": "Gitarrensolo (Bends, Vibrato, schnelle Läufe), Akkordwechsel E-Dur führt in den Tonartwechsel",
    "final": "Hook einen Ganzton höher (Fis-Moll), Harmoniestimme, Leadgitarre eine Oktave tiefer",
    "outro": "Schlussakkord mit Tom-Wirbel, dann derselbe Turnaround wie im Intro – zurück zum Thema (Schleife)",
}
TONAL_TARGET = [  # 1/3-octave band energy relative to the 63-125 Hz average (rock/pop balance, +-3 dB tolerance)
    (31.5, -6.0), (40, -3.0), (50, -1.0), (63, 0.0), (80, 0.0), (100, 0.0), (125, -0.5), (160, -1.3), (200, -2.0),
    (250, -2.8), (315, -3.5), (400, -4.2), (500, -5.0), (630, -5.8), (800, -6.5), (1000, -7.3), (1250, -8.0),
    (1600, -8.8), (2000, -9.5), (2500, -10.3), (3150, -11.0), (4000, -12.0), (5000, -13.3), (6300, -14.6),
    (8000, -16.0), (10000, -18.0), (12500, -20.5), (16000, -24.0)]


# ------------------------------------------------------------------------------------------------
# Measurements
# ------------------------------------------------------------------------------------------------

def loudness_range(xk: np.ndarray) -> float:
    """EBU Tech 3342: short-term (3 s) values, absolute gate -70 LUFS, relative gate -20 LU, 10..95 % range."""
    _, z = ms.block_power(xk, 3.0, 0.1)
    st = -0.691 + 10.0 * np.log10(np.maximum(z, 1e-20))
    st = st[st > -70.0]
    rel = -0.691 + 10.0 * math.log10(float(np.mean(10.0 ** ((st + 0.691) / 10.0)))) - 20.0
    st = st[st > rel]
    return float(np.percentile(st, 95) - np.percentile(st, 10))


def third_octave(x: np.ndarray) -> tuple:
    centres = np.array([c for c, _ in TONAL_TARGET])
    mono = x.mean(axis=1) if x.ndim == 2 else x
    n = 16384
    win = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    for s in range(0, len(mono) - n, n // 2):
        acc += np.abs(np.fft.rfft(mono[s:s + n] * win)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / SR)
    lv = np.array([10.0 * np.log10(acc[(f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))].sum() + 1e-20) for c in centres])
    ref = 10.0 * np.log10(np.mean(10.0 ** (lv[(centres >= 63) & (centres <= 125)] / 10.0)))
    return centres, lv - ref


def chroma_bars(x: np.ndarray, bars: list) -> np.ndarray:
    """12-bin chroma per bar from tonal peaks only: STFT (8192) of the mono sum, 70 Hz .. 1.8 kHz, spectral maxima
    at least 6 dB above their neighbourhood (drum noise and the dense intermodulation of the distortion stay out)."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    n, hop = 8192, 2048
    f = np.fft.rfftfreq(n, 1.0 / SR)
    sel = (f >= 70.0) & (f <= 1800.0)
    pcs = (np.round(12.0 * np.log2(np.maximum(f, 1.0) / 440.0)) + 9).astype(int) % 12
    win = np.hanning(n)
    kern = np.ones(15) / 15.0
    out = np.zeros((len(bars), 12))
    for i, b in enumerate(bars):
        a = int(b.t * SR)
        e = min(len(mono), int((b.t + ms.BAR) * SR))
        starts = np.arange(a, e - n, hop)
        if len(starts) == 0:
            continue
        seg = np.stack([mono[s0:s0 + n] * win for s0 in starts])
        mag = np.abs(np.fft.rfft(seg, axis=1))
        lm = 20.0 * np.log10(mag + 1e-12)
        sm = np.apply_along_axis(lambda r: np.convolve(r, kern, mode="same"), 1, lm)
        peak = (mag > np.roll(mag, 1, axis=1)) & (mag >= np.roll(mag, -1, axis=1)) & (lm > sm + 6.0) & sel[None, :]
        w = np.where(peak, mag * mag, 0.0).sum(axis=0)
        acc = np.bincount(pcs, weights=w, minlength=12)
        out[i] = acc / (acc.sum() + 1e-20)
    return out


NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def triad_templates() -> dict:
    out = {}
    for pc in range(12):
        for third, suffix in ((4, ""), (3, "m")):
            t = np.zeros(12)
            t[[pc, (pc + third) % 12, (pc + 7) % 12]] = [1.0, 1.0, 0.8]
            out[NOTE_NAMES[pc] + suffix] = t / np.linalg.norm(t)
    return out


KK_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
KK_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])


def key_of(ch: np.ndarray) -> str:
    """Best of the 24 keys (Krumhansl-Kessler profiles); a relative major is reported with its minor."""
    best, name = -2.0, ""
    for k in range(12):
        for prof, label in ((KK_MINOR, "-Moll"), (KK_MAJOR, "-Dur")):
            r = float(np.corrcoef(np.roll(prof, k), ch)[0, 1])
            if r > best:
                best, name = r, NOTE_NAMES[k] + label
                if label == "-Dur":
                    name += f" (= {NOTE_NAMES[(k + 9) % 12]}-Moll)"
    return name


def seam_check(dec: np.ndarray, master: np.ndarray | None) -> dict:
    """The decoded file played across the loop point (end of file -> loop_offset)."""
    a, n = ms.N_LOOP_START, len(dec)
    k = int(0.5 * SR)
    played = np.concatenate([dec[n - k:], dec[a:a + k]])
    steps = np.abs(np.diff(dec[a:], axis=0)).max(axis=1)
    seam_step = float(np.max(np.abs(played[k] - played[k - 1])))
    p999 = float(np.percentile(steps, 99.9))
    # click detector: energy above 6 kHz in 2 ms around the seam vs. 2 ms windows in the surrounding 200 ms
    hp = ms.apply_eq(played, [("hp", 6000.0, 0.7071), ("hp", 6000.0, 0.7071)], 1024)
    e = np.sum(hp * hp, axis=1)
    w = int(0.002 * SR)
    wins = [float(np.sum(e[i:i + w])) for i in range(k - int(0.1 * SR), k + int(0.1 * SR), w)]
    at = float(np.sum(e[k - w // 2:k + w // 2]))
    out = {"seam_step": round(seam_step, 5), "step_p99_9": round(p999, 5),
           "step_ratio": round(seam_step / max(p999, 1e-9), 3),
           "hf_energy_at_seam_vs_median_db": round(10.0 * math.log10(at / max(float(np.median(wins)), 1e-20)), 2),
           "hf_energy_at_seam_vs_max_db": round(10.0 * math.log10(at / max(max(wins), 1e-20)), 2)}
    if master is not None and len(master) >= ms.N_FILE + k:
        # what the loop plays after the seam vs. the music's true continuation (rendered after the body)
        cont = master[ms.N_FILE:ms.N_FILE + 2 * k]
        loop = master[a:a + 2 * k]
        d = loop - cont
        out["continuation_diff_rms_db"] = round(ms.db(np.sqrt(np.mean(d * d))) - ms.db(np.sqrt(np.mean(cont * cont))), 1)
        out["continuation_diff_peak_dbfs"] = round(ms.db(np.max(np.abs(d))), 1)
        out["file_vs_master_seam_step"] = round(float(np.max(np.abs(master[a] - master[ms.N_FILE - 1]))), 5)
    return out


# ------------------------------------------------------------------------------------------------
# Pictures (PIL)
# ------------------------------------------------------------------------------------------------

MAGMA = [(0.0, (0, 0, 4)), (0.13, (28, 16, 68)), (0.25, (79, 18, 123)), (0.38, (129, 37, 129)),
         (0.5, (181, 54, 122)), (0.63, (229, 80, 100)), (0.75, (251, 135, 97)), (0.88, (254, 194, 135)),
         (1.0, (252, 253, 191))]


def colormap(v: np.ndarray) -> np.ndarray:
    xs = [p for p, _ in MAGMA]
    out = np.zeros(v.shape + (3,), np.uint8)
    for c in range(3):
        out[..., c] = np.interp(v, xs, [col[c] for _, col in MAGMA]).astype(np.uint8)
    return out


def font(size: int, bold: bool = False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def fmt_time(s: float) -> str:
    return f"{int(s // 60)}:{int(s % 60):02d}"


def de(s: str) -> str:
    """German number format for texts: decimal comma, typographic minus."""
    s = re.sub(r"(?<=\d)\.(?=\d)", ",", s)
    return re.sub(r"(?<![\w-])-(?=\d)", "−", s)


def spectrogram_png(x: np.ndarray, path: str, title: str, w: int = 1800, h: int = 560, t0: float = 0.0,
                    n: int = 8192, hop: int = 2048) -> None:
    """Log-frequency spectrogram of x (which starts at t0 seconds of the song) with the section map."""
    mono = x.mean(axis=1)
    frames = (len(mono) - n) // hop
    fl, fh = 30.0, 16000.0
    rows = np.exp(np.linspace(np.log(fh), np.log(fl), h))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    win = np.hanning(n)
    spec = np.zeros((h, frames))
    for s in range(0, frames, 400):
        idx = np.arange(s, min(frames, s + 400))
        seg = np.stack([mono[i * hop:i * hop + n] * win for i in idx])
        p = np.abs(np.fft.rfft(seg, axis=1)) ** 2
        for j, col in enumerate(idx):
            spec[:, col] = np.interp(rows, f, p[j])
    dbv = 10.0 * np.log10(spec + 1e-14)
    dbv -= dbv.max()
    v = np.clip((dbv + 90.0) / 90.0, 0.0, 1.0)
    img = Image.fromarray(colormap(v)).resize((w, h), Image.BILINEAR)
    pad_l, pad_t, pad_b = 70, 90, 40
    canvas = Image.new("RGB", (w + pad_l + 20, h + pad_t + pad_b), (16, 14, 26))
    canvas.paste(img, (pad_l, pad_t))
    d = ImageDraw.Draw(canvas)
    d.text((pad_l, 10), title, fill=(240, 240, 250), font=font(20, True))
    dur = len(mono) / SR
    X = lambda t: pad_l + (t - t0) / dur * w  # noqa: E731
    for s in ms.section_map():
        if s["end_s"] <= t0 or s["start_s"] >= t0 + dur:
            continue
        x0, x1 = X(max(s["start_s"], t0)), X(min(s["end_s"], t0 + dur))
        col = SECTION_COLORS[s["id"]]
        d.rectangle([x0, 44, x1 - 2, 80], fill=col)
        d.text((x0 + 4, 48), s["label"], fill=(255, 255, 255), font=font(13, True))
        d.text((x0 + 4, 64), f"{fmt_time(s['start_s'])}", fill=(255, 255, 255), font=font(11))
        d.line([x0, pad_t, x0, pad_t + h], fill=(255, 255, 255), width=1)
    if t0 <= ms.LOOP_OFFSET_S <= t0 + dur:
        d.line([X(ms.LOOP_OFFSET_S), pad_t - 6, X(ms.LOOP_OFFSET_S), pad_t + h], fill=(80, 255, 120), width=2)
    for fq, lab in ((50, "50"), (100, "100"), (200, "200"), (500, "500"), (1000, "1k"), (2000, "2k"), (5000, "5k"),
                    (10000, "10k")):
        y = pad_t + h * (math.log(fh / fq) / math.log(fh / fl))
        d.line([pad_l - 6, y, pad_l, y], fill=(200, 200, 200))
        d.text((8, y - 7), f"{lab} Hz", fill=(200, 200, 200), font=font(12))
    step = 15 if dur > 60 else (5 if dur > 20 else 1)
    for t in range(int(math.ceil(t0 / step)) * step, int(t0 + dur) + 1, step):
        d.line([X(t), pad_t + h, X(t), pad_t + h + 5], fill=(200, 200, 200))
        d.text((X(t) - 12, pad_t + h + 8), fmt_time(t) if step >= 5 else f"{t}", fill=(200, 200, 200), font=font(12))
    canvas.save(path)


def loudness_png(x: np.ndarray, xk: np.ndarray, path: str, integ: float, lra: float, tp: float) -> None:
    tm, mom = ms.loudness_curve(x, 0.4, 0.1, xk)
    ts, st = ms.loudness_curve(x, 3.0, 0.1, xk)
    w, h, pl, pt = 1800, 460, 70, 70
    canvas = Image.new("RGB", (w + pl + 20, h + pt + 50), (250, 250, 252))
    d = ImageDraw.Draw(canvas)
    dur = len(x) / SR
    lo, hi = -40.0, -6.0
    X = lambda t: pl + t / dur * w  # noqa: E731
    Y = lambda v: pt + (hi - np.clip(v, lo, hi)) / (hi - lo) * h  # noqa: E731
    for s in ms.section_map():
        col = SECTION_COLORS[s["id"]]
        d.rectangle([X(s["start_s"]), pt, X(min(s["end_s"], dur)), pt + h], fill=tuple(int(240 + (c - 240) * 0.18) for c in col))
        d.text((X(s["start_s"]) + 4, pt + 4), s["label"], fill=col, font=font(12, True))
    for v in range(-40, -5, 5):
        d.line([pl, Y(v), pl + w, Y(v)], fill=(215, 215, 220))
        d.text((10, Y(v) - 7), de(f"{v} LUFS"), fill=(90, 90, 90), font=font(11))
    d.line([pl, Y(integ), pl + w, Y(integ)], fill=(30, 160, 60), width=2)
    d.line(list(zip(X(tm).tolist(), Y(mom).tolist())), fill=(160, 170, 210), width=1)
    d.line(list(zip(X(ts).tolist(), Y(st).tolist())), fill=(40, 60, 170), width=3)
    d.line([X(ms.LOOP_OFFSET_S), pt, X(ms.LOOP_OFFSET_S), pt + h], fill=(30, 160, 60), width=2)
    for t in range(0, int(dur) + 1, 15):
        d.text((X(t) - 12, pt + h + 8), fmt_time(t), fill=(60, 60, 60), font=font(12))
    d.text((pl, 12), de(f"Lautheit über die Zeit: kurzzeitig (3 s, dunkelblau), momentan (0,4 s, hellblau), integriert "
                        f"{integ:.1f} LUFS (grün), Lautheitsumfang {lra:.1f} LU, True Peak {tp:.1f} dBTP"),
           fill=(20, 20, 20), font=font(17, True))
    d.text((pl, 38), "grüne senkrechte Linie: Schleifenbeginn (15,0 s) – das Intro läuft nur einmal",
           fill=(60, 60, 60), font=font(13))
    canvas.save(path)


def seam_png(dec: np.ndarray, master: np.ndarray | None, path: str) -> None:
    a, n = ms.N_LOOP_START, len(dec)
    k = int(0.02 * SR)
    played = np.concatenate([dec[n - k:], dec[a:a + k]])
    cont = master[ms.N_FILE - k:ms.N_FILE + k] if master is not None else None
    w, h, pl = 1600, 260, 70
    canvas = Image.new("RGB", (w + pl + 20, 2 * h + 140), (250, 250, 252))
    d = ImageDraw.Draw(canvas)
    d.text((pl, 10), "Schleifennaht: Ende der Datei → Schleifenbeginn (15,0 s), ±20 ms, wie Godot es abspielt",
           fill=(20, 20, 20), font=font(17, True))
    d.text((pl, 36), "schwarz: abgespielt (dekodierte OGG-Datei), orange gestrichelt: musikalische Fortsetzung aus "
                     "der Berechnung; rote Linie = Naht", fill=(60, 60, 60), font=font(13))
    for ch in range(2):
        y0 = 70 + ch * (h + 30)
        sig = played[:, ch]
        m = max(np.max(np.abs(sig)), 1e-6) * 1.1
        X = lambda i: pl + i / (2 * k) * w  # noqa: E731
        Y = lambda v: y0 + h / 2 - v / m * h / 2  # noqa: E731
        d.rectangle([pl, y0, pl + w, y0 + h], outline=(200, 200, 200))
        d.text((10, y0 + h / 2 - 8), "L" if ch == 0 else "R", fill=(20, 20, 20), font=font(16, True))
        if cont is not None:
            pts = list(zip(X(np.arange(2 * k)).tolist(), Y(cont[:, ch]).tolist()))
            for i in range(0, len(pts) - 1, 4):
                d.line([pts[i], pts[i + 1]], fill=(255, 140, 0), width=3)
        d.line(list(zip(X(np.arange(2 * k)).tolist(), Y(sig).tolist())), fill=(10, 10, 10), width=1)
        d.line([X(k), y0, X(k), y0 + h], fill=(220, 30, 30), width=2)
    canvas.save(path)


def overview_png(path: str, checks: dict) -> None:
    secs = ms.section_map()
    w = 1800
    row = 62
    canvas = Image.new("RGB", (w, 190 + row * len(secs)), (18, 16, 30))
    d = ImageDraw.Draw(canvas)
    d.text((30, 18), "Crossing Europe – Titelmelodie: Abschnitte", fill=(255, 255, 255), font=font(28, True))
    d.text((30, 58), de(f"Synthwave-Rock, {ms.BPM:g} bpm, E-Moll → Fis-Moll, "
                        f"{ms.N_FILE / SR // 60:.0f}:{ms.N_FILE / SR % 60:04.1f} min; Intro läuft einmal, danach "
                        f"Schleife ab 0:15,0 ({ms.BODY_BARS} Takte = "
                        f"{ms.BODY_BARS * ms.BAR // 60:.0f}:{ms.BODY_BARS * ms.BAR % 60:04.1f} min). "
                        f"{checks.get('lufs', 0):.1f} LUFS, True Peak {checks.get('true_peak_dbtp', 0):.1f} dBTP"),
           fill=(200, 200, 220), font=font(16))
    total = ms.N_FILE / SR
    x0, x1, yb = 30, w - 30, 100
    for s in secs:
        a = x0 + s["start_s"] / total * (x1 - x0)
        b = x0 + s["end_s"] / total * (x1 - x0)
        d.rectangle([a, yb, b - 2, yb + 50], fill=SECTION_COLORS[s["id"]])
        d.text((a + 4, yb + 6), s["label"].split(" (")[0], fill=(255, 255, 255), font=font(12, True))
        d.text((a + 4, yb + 26), fmt_time(s["start_s"]), fill=(255, 255, 255), font=font(12))
    lx = x0 + ms.LOOP_OFFSET_S / total * (x1 - x0)
    d.line([lx, yb - 8, lx, yb + 58], fill=(80, 255, 120), width=3)
    d.text((lx + 4, yb - 22), "Schleife ab hier ↺", fill=(80, 255, 120), font=font(13, True))
    y = 175
    for s in secs:
        col = SECTION_COLORS[s["id"]]
        d.rectangle([30, y + 4, 44, y + row - 12], fill=col)
        d.text((56, y), f"{fmt_time(s['start_s'])}–{fmt_time(s['end_s'])}  {s['label']}", fill=(255, 255, 255),
               font=font(17, True))
        d.text((460, y + 2), f"Takt {s['bar']}–{s['bar'] + s['bars'] - 1} ({s['bars']}), {s['key']}: {s['chords']}",
               fill=(210, 210, 230), font=font(14))
        d.text((56, y + 26), INSTRUMENTS[s["id"]], fill=(170, 170, 200), font=font(14))
        y += row
    canvas.save(path)


# ------------------------------------------------------------------------------------------------
# Media
# ------------------------------------------------------------------------------------------------

def ffmpeg(*args) -> bool:
    exe = shutil.which("ffmpeg")
    if not exe:
        return False
    r = subprocess.run([exe, "-y", "-loglevel", "error", *args], capture_output=True, text=True)
    if r.returncode != 0:
        print("ffmpeg:", r.stderr.strip()[-400:])
    return r.returncode == 0


def media(dec: np.ndarray, ogg: str, out: str, spec_png: str) -> None:
    a = ms.N_LOOP_START
    loop2 = dec[a:a + int(20.0 * SR)].copy()
    fade = np.linspace(1.0, 0.0, int(4.0 * SR))
    loop2[-len(fade):] *= fade[:, None]
    full = np.concatenate([dec, loop2])
    wav = os.path.join(out, "_preview.wav")
    ms.write_wav(wav, full, 16)
    ffmpeg("-i", wav, "-c:a", "libmp3lame", "-b:a", "192k", os.path.join(out, "title_theme_preview.mp3"))
    seam = np.concatenate([dec[-int(12.0 * SR):], dec[a:a + int(12.0 * SR)]])
    ms.write_wav(os.path.join(out, "_seam.wav"), seam, 16)
    ffmpeg("-i", os.path.join(out, "_seam.wav"), "-c:a", "libmp3lame", "-b:a", "192k", os.path.join(out, "seam_demo.mp3"))
    shutil.copy(ogg, os.path.join(out, "title_theme.ogg"))
    # video: the spectrogram picture with a moving playhead (full file + 20 s loop continuation)
    dur = len(full) / SR
    img = Image.open(spec_png)
    w, h = img.size
    pad_l, pad_t = 70, 90                     # layout of spectrogram_png: plot width = picture width - 90
    span = w - pad_l - 20
    # the picture covers the file only: the playhead runs over the file, then restarts at the loop offset
    file_dur = len(dec) / SR
    expr = (f"if(lt(t\\,{file_dur:.3f})\\,{pad_l}+t/{file_dur:.3f}*{span:.1f}\\,"
            f"{pad_l}+({ms.LOOP_OFFSET_S:.3f}+t-{file_dur:.3f})/{file_dur:.3f}*{span:.1f})")
    vw, vh = (w // 2) * 2, (h // 2) * 2
    ffmpeg("-loop", "1", "-framerate", "25", "-i", spec_png, "-i", wav, "-f", "lavfi", "-i",
           f"color=c=white:s=3x{h - pad_t - 40}:r=25", "-filter_complex",
           f"[0:v]crop={vw}:{vh}:0:0[bg];[bg][2:v]overlay=x='{expr}':y={pad_t}:shortest=1,format=yuv420p[v]",
           "-map", "[v]", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "24", "-tune", "stillimage",
           "-c:a", "aac", "-b:a", "192k", "-t", f"{dur:.2f}", os.path.join(out, "title_theme_preview.mp4"))
    for tmp in ("_preview.wav", "_seam.wav"):
        os.remove(os.path.join(out, tmp))


def sections_md(path: str, checks: dict) -> None:
    lines = ["# Titelmelodie – Abschnitte", "",
             f"{ms.BPM:g} bpm, 1 Takt = {ms.BAR:g} s. Intro (Takt 1–8, 0:00–0:15) läuft einmal, danach Schleife "
             f"Takt 9–108 ({ms.BODY_BARS * ms.BAR:g} s). Datei {ms.N_FILE / SR:g} s, {checks['lufs']:.1f} LUFS, "
             f"True Peak {checks['true_peak_dbtp']:.1f} dBTP, Lautheitsumfang {checks['lra']:.1f} LU.", "",
             "| Zeit | Takte | Abschnitt | Tonart, Akkorde | Instrumente | Lautheit (3 s, Mittel) |",
             "|---|---|---|---|---|---|"]
    for s in ms.section_map():
        st = checks["sections"][s["id"]]["short_term_mean_lufs"]
        lines.append(f"| {fmt_time(s['start_s'])}–{fmt_time(s['end_s'])} | {s['bar']}–{s['bar'] + s['bars'] - 1} | "
                     f"{s['label']} | {s['key']}: {s['chords']} | {INSTRUMENTS[s['id']]} | {st:.1f} LUFS |")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(de(line) for line in lines) + "\n")


# ------------------------------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Titelmelodie prüfen: Lautheit, Balance, Harmonik, Schleifennaht, Vorschau")
    ap.add_argument("--ogg", default=os.path.join(ms.OUT_DIR, ms.OUT_NAME))
    ap.add_argument("--master", help="master_full.wav aus music_synth.py --wav (für die Fortsetzung an der Naht)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--no-media", action="store_true", help="keine MP3/MP4")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    dec = ms.decode_ogg(args.ogg)
    master = ms.read_wav(args.master) if args.master else None
    checks = {"samples": len(dec), "expected_samples": ms.N_FILE, "duration_s": round(len(dec) / SR, 3)}
    xk = ms.k_weight(dec)
    checks["lufs"] = round(ms.integrated_lufs(dec, xk), 2)
    checks["lra"] = round(loudness_range(xk), 1)
    checks["true_peak_dbtp"] = round(ms.true_peak_db(dec), 2)
    checks["sample_peak_dbfs"] = round(ms.db(np.max(np.abs(dec))), 2)
    checks["clipped_samples"] = int(np.sum(np.abs(dec) >= 0.9999))
    # per section
    bars = [b for b in ms.timeline(extra=False)]
    tmpl = triad_templates()
    chroma = chroma_bars(dec, bars)
    hits, misses = 0, []
    for b, c in zip(bars, chroma):
        best = max(tmpl, key=lambda k: float(np.dot(tmpl[k], c)))
        if best == b.chord or (best == "D#m" and b.chord == "Ebm"):
            hits += 1
        else:
            misses.append(f"Takt {b.i + 1} ({b.sec}): {b.chord} erkannt als {best}")
    checks["chords_matched"] = f"{hits}/{len(bars)}"
    checks["chord_misses"] = misses
    secs = {}
    _, stc = ms.loudness_curve(dec, 3.0, 0.1, xk)
    for s in ms.section_map():
        a, e = int(s["start_s"] * SR), int(s["end_s"] * SR)
        seg = dec[a:e]
        ia, ie = int(s["start_s"] / 0.1), max(int(s["end_s"] / 0.1) - 29, int(s["start_s"] / 0.1) + 1)
        mid = 0.5 * (seg[:, 0] + seg[:, 1])
        side = 0.5 * (seg[:, 0] - seg[:, 1])
        low = ms.apply_eq(seg, [("lp", 120.0, 0.7071), ("lp", 120.0, 0.7071)], 4096)
        secs[s["id"]] = {
            "short_term_mean_lufs": round(float(10 * np.log10(np.mean(10 ** (stc[ia:ie] / 10)))), 1),
            "short_term_max_lufs": round(float(np.max(stc[ia:ie])), 1),
            "true_peak_dbtp": round(ms.true_peak_db(seg), 2),
            "correlation": round(float(np.corrcoef(seg[:, 0], seg[:, 1])[0, 1]), 2),
            "side_vs_mid_db": round(ms.db(np.sqrt(np.mean(side ** 2))) - ms.db(np.sqrt(np.mean(mid ** 2))), 1),
            "low_end_correlation": round(float(np.corrcoef(low[:, 0], low[:, 1])[0, 1]), 3),
            "key": key_of(chroma[[b.i for b in bars if b.sec == s["id"]]].mean(axis=0)),
        }
    checks["sections"] = secs
    centres, lv = third_octave(dec[ms.N_LOOP_START:])
    checks["tonal_balance"] = {f"{c:g}": [round(float(v), 1), t, round(float(v - t), 1)]
                               for c, v, (_, t) in zip(centres, lv, TONAL_TARGET)}
    checks["tonal_balance_max_dev_db"] = round(float(np.max(np.abs(lv - np.array([t for _, t in TONAL_TARGET]))[2:-1])), 1)
    checks["seam"] = seam_check(dec, master)
    with open(os.path.join(args.out, "checks.json"), "w", encoding="utf-8") as fh:
        json.dump(checks, fh, ensure_ascii=False, indent=1)
    spec = os.path.join(args.out, "spectrogram.png")
    spectrogram_png(dec, spec, "Crossing Europe – Titelmelodie: Spektrogramm (logarithmische Frequenzachse), "
                               "grüne Linie = Schleifenbeginn")
    loudness_png(dec, xk, os.path.join(args.out, "loudness.png"), checks["lufs"], checks["lra"], checks["true_peak_dbtp"])
    seam_png(dec, master, os.path.join(args.out, "seam.png"))
    overview_png(os.path.join(args.out, "overview.png"), checks)
    sections_md(os.path.join(args.out, "sections.md"), checks)
    if not args.no_media:
        media(dec, args.ogg, args.out, spec)
    short = {k: v for k, v in checks.items() if k not in ("tonal_balance", "sections", "chord_misses")}
    print(json.dumps(short, ensure_ascii=False, indent=1))
    for sid, v in secs.items():
        print(f"  {sid:8s} {v}")
    print("  Fehlgriffe Akkorde:", misses[:12])
    print("  Balance (Abweichung vom Ziel, dB):", {k: v[2] for k, v in checks["tonal_balance"].items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
