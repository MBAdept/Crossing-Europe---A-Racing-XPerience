#!/usr/bin/env python3
"""Verkehrsgeräusche - pass-by simulations, spectrograms and checks of the traffic loops.

Plays the loops of assets/audio/traffic/ the way docs/verkehrsgeraeusche.md (sections 1 and 2) describes the
runtime and spatialises them with a simple, physically exact reference model - to check the loops without
listening, and as a reference for the runtime:

  * pitch  = clamp((v / ref_kmh)^pitch_exp, 0.6, 1.6) x spread per vehicle (+-6 %, fixed per id) x Doppler
    level  = gain_db + level_db_per_decade * log10(v / ref_kmh) + distance           (contract section 1)
  * geometry: straight road, listener (player / chase camera, 1.2 m high) and vehicles (0.6 m) move along y,
    lanes 3.75 m apart
  * propagation: each layer is read at the retarded time tau (t - tau = |L(t) - S(tau)| / c, c = 343 m/s in still
    air) - the Doppler shift of moving source and moving listener follows from it exactly
  * distance: inverse distance re REF_M (engine, tyres), inverse square for the air layer (near-field whoosh);
    extended source: r_eff = sqrt(r^2 + (SIZE_M * size)^2) with the class "size"; fade-out 120..150 m
  * stereo: equal-power panning from the direction of arrival (PAN_WIDTH x sine of the angle off the road axis)
  * air absorption: ISO 9613-1 (20 °C, 70 % rel. humidity), frequency-dependent attenuation per STFT frame

Scenarios (stereo, 32 kHz; WAV + OGG + spectrogram PNG + level/pitch plot PNG + MP4 with a scrolling spectrogram):
  pkw_links         the player (170 km/h) passes a petrol car (120 km/h) in the left lane
  lkw_rechts        the player (130 km/h) passes a truck (85 km/h) in the right lane
  sport_von_hinten  a sports car (190 km/h) overtakes the player (130 km/h) in the left lane
  kolonne_rechts    the player (160 km/h) passes car, van, truck and bus in the right lane (class comparison)
plus loops.wav (every loop twice in a row - the loop point is in the middle of each pair) and its spectrogram.

Checks (printed and in checks.json): left/right balance on the approach, pitch through the pass (measured by
log-spectral correlation against the dry loop, compared with the exact Doppler factor), truck vs. car loudness
and spectral centroid, peaks.

Usage:
  python3 tools/audio/traffic_preview.py [--sounds assets/audio/traffic] [--out DIR] [--scenario NAME ...]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_synth as es  # noqa: E402  (K/A weighting)

SR = 32000
ROOT = es.ROOT
C_AIR = 343.0
LANE_M = 3.75
H_LISTENER = 1.2
H_SOURCE = 0.6
REF_M = 7.5            # distance with gain 1 (engine, tyres; ISO pass-by distance)
AIR_REF_M = 5.0        # air layer: gain 1 at 5 m, inverse square (near-field whoosh), x size (body/wake size)
SIZE_M = 1.5           # source extent per unit "size"
FADE_M = (120.0, 150.0)
PAN_WIDTH = 0.85
MASTER_DB = -6.0       # output gain of the demos (no clipping at the closest passes)
SCRATCH = "/tmp/ce_traffic_demo"

SCENARIOS = {
    "pkw_links": {
        "title": "Spieler 170 km/h überholt Pkw (Benziner, 120 km/h) auf der linken Spur", "dur": 10.0,
        "listener_kmh": 170.0,
        "vehicles": [{"id": 12, "model": "sedan", "kmh": 120.0, "x": -LANE_M, "t_pass": 5.0}]},
    "lkw_rechts": {
        "title": "Spieler 130 km/h überholt Lkw (85 km/h) auf der rechten Spur", "dur": 10.0,
        "listener_kmh": 130.0,
        "vehicles": [{"id": 23, "model": "truck", "kmh": 85.0, "x": LANE_M, "t_pass": 5.0}]},
    "sport_von_hinten": {
        "title": "Sportwagen (190 km/h) überholt den Spieler (130 km/h) links", "dur": 10.0,
        "listener_kmh": 130.0,
        "vehicles": [{"id": 37, "model": "sports", "kmh": 190.0, "x": -LANE_M, "t_pass": 5.0}]},
    "kolonne_rechts": {
        "title": "Spieler 160 km/h überholt rechts Pkw, Transporter, Lkw, Bus", "dur": 21.0,
        "listener_kmh": 160.0,
        "vehicles": [{"id": 44, "model": "hatch", "kmh": 120.0, "x": LANE_M, "t_pass": 3.5},
                     {"id": 45, "model": "van", "kmh": 110.0, "x": LANE_M, "t_pass": 8.0},
                     {"id": 46, "model": "truck", "kmh": 85.0, "x": LANE_M, "t_pass": 12.5},
                     {"id": 47, "model": "bus", "kmh": 90.0, "x": LANE_M, "t_pass": 17.0}]},
}


# ------------------------------------------------------------------------------------------------
# Loops and the contract's playback rules
# ------------------------------------------------------------------------------------------------

def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == SR, path
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0


class TrafficSet:
    def __init__(self, folder: str):
        with open(os.path.join(folder, "traffic_sounds.json"), encoding="utf-8") as fh:
            self.meta = json.load(fh)
        assert self.meta["format"] == "ce-traffic-sounds-1" and int(self.meta["sample_rate"]) == SR
        self.sounds = self.meta["sounds"]
        self.classes = self.meta["classes"]
        self.models = self.meta["models"]
        self.loops = {k: read_wav(os.path.join(folder, s["file"])) for k, s in self.sounds.items()}

    def voice(self, veh: dict) -> dict:
        """Layers of a vehicle: class from the model, engine chosen by id, spread +-6 % and loop offsets fixed
        per id."""
        cls_name = self.models.get(veh["model"], "car")
        cls = self.classes[cls_name]
        rng = np.random.default_rng(1000 + int(veh["id"]))
        spread = 1.0 + 0.06 * (2.0 * rng.random() - 1.0)
        engines = cls["engine"]
        names = {"engine": engines[int(veh["id"]) % len(engines)], "tires": cls["tires"], "air": cls["air"]}
        layers = {}
        for layer, name in names.items():
            s = self.sounds[name]
            q = veh["kmh"] / float(s["ref_kmh"])
            rate = min(max(q ** float(s["pitch_exp"]), 0.6), 1.6) * spread
            db = float(s["gain_db"]) + float(s.get("level_db_per_decade", 0.0)) * math.log10(q)
            layers[layer] = {"name": name, "rate": rate, "gain": 10.0 ** (db / 20.0),
                             "offset": rng.random() * len(self.loops[name])}
        return {"class": cls_name, "size": float(cls["size"]), "spread": spread, "layers": layers}


# ------------------------------------------------------------------------------------------------
# Spatialiser
# ------------------------------------------------------------------------------------------------

def iso9613_db_per_m(f, temp_c: float = 20.0, rh: float = 70.0, p_kpa: float = 101.325):
    """Atmospheric absorption (dB/m), ISO 9613-1."""
    f = np.asarray(f, float)
    T, T0, T01, pr = temp_c + 273.15, 293.15, 273.16, 101.325
    psat = pr * 10.0 ** (-6.8346 * (T01 / T) ** 1.261 + 4.6151)
    h = rh * psat / p_kpa
    fro = (p_kpa / pr) * (24.0 + 4.04e4 * h * (0.02 + h) / (0.391 + h))
    frn = (p_kpa / pr) * (T / T0) ** -0.5 * (9.0 + 280.0 * h * math.exp(-4.170 * ((T / T0) ** (-1.0 / 3.0) - 1.0)))
    return 8.686 * f * f * (1.84e-11 * (pr / p_kpa) * (T / T0) ** 0.5 + (T / T0) ** -2.5 * (
        0.01275 * math.exp(-2239.1 / T) / (fro + f * f / fro) + 0.1068 * math.exp(-3352.0 / T) / (frn + f * f / frn)))


def air_absorb(x: np.ndarray, r: np.ndarray, frame: int = 1024, hop: int = 256) -> np.ndarray:
    """Time-varying air absorption: STFT with sqrt-Hann windows (weighted overlap-add), attenuation
    10^(-alpha(f) r / 20) with the distance r at the frame centre."""
    win = np.sqrt(np.hanning(frame + 1)[:-1])
    alpha = iso9613_db_per_m(np.fft.rfftfreq(frame, 1.0 / SR))
    n = len(x)
    xp = np.concatenate([np.zeros(frame), x, np.zeros(frame)])
    out = np.zeros(len(xp))
    norm = np.zeros(len(xp))
    for s in range(0, n + frame, hop):
        seg = xp[s:s + frame]
        if len(seg) < frame:
            break
        rc = r[min(max(s + frame // 2 - frame, 0), n - 1)]
        y = np.fft.irfft(np.fft.rfft(seg * win) * 10.0 ** (-alpha * rc / 20.0), frame) * win
        out[s:s + frame] += y
        norm[s:s + frame] += win * win
    return (out / np.maximum(norm, 1e-6))[frame:frame + n]


def read_loop(loop: np.ndarray, pos: np.ndarray) -> np.ndarray:
    """Cubic (Catmull-Rom) interpolation of a loop at fractional positions (wrapping)."""
    n = len(loop)
    i = np.floor(pos).astype(np.int64)
    t = pos - i
    p0, p1, p2, p3 = (loop[(i + k) % n] for k in (-1, 0, 1, 2))
    return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + t * (3.0 * (p1 - p2) + p3 - p0)))


def render(ts: TrafficSet, sc: dict) -> dict:
    n = int(sc["dur"] * SR)
    t = np.arange(n) / SR
    vl = sc["listener_kmh"] / 3.6
    ly = vl * t
    out = np.zeros((n, 2))
    per_vehicle = []
    for veh in sc["vehicles"]:
        vs = veh["kmh"] / 3.6
        y0 = (vl - vs) * veh["t_pass"]                    # source position at tau = 0 (abeam at t_pass)
        dx, dz = veh["x"], H_SOURCE - H_LISTENER
        tau = t.copy()
        for _ in range(12):                               # retarded time (contraction factor |vs| / c)
            dy = y0 + vs * tau - ly
            tau = t - np.sqrt(dx * dx + dy * dy + dz * dz) / C_AIR
        dy = y0 + vs * tau - ly
        r = np.sqrt(dx * dx + dy * dy + dz * dz)
        doppler = np.gradient(tau) * SR                   # d tau / d t
        voice = ts.voice(veh)
        r_eff = np.sqrt(r * r + (SIZE_M * voice["size"]) ** 2)
        fade = np.clip((FADE_M[1] - r) / (FADE_M[1] - FADE_M[0]), 0.0, 1.0)
        pan = PAN_WIDTH * dx / np.sqrt(dx * dx + dy * dy)
        g_l = np.cos((pan + 1.0) * np.pi / 4.0)
        g_r = np.sin((pan + 1.0) * np.pi / 4.0)
        dry = {}
        for layer, ly_info in voice["layers"].items():
            loop = ts.loops[ly_info["name"]]
            x = read_loop(loop, ly_info["offset"] + ly_info["rate"] * SR * tau)
            dry[layer] = x
            if layer == "air":
                g = ly_info["gain"] * voice["size"] * (AIR_REF_M / r_eff) ** 2 * fade
            else:
                g = ly_info["gain"] * REF_M / r_eff * fade
            y = air_absorb(x * g, r)
            out[:, 0] += y * g_l
            out[:, 1] += y * g_r
        per_vehicle.append({"veh": veh, "voice": voice, "r": r, "dy": dy, "doppler": doppler, "dry": dry})
    out *= 10.0 ** (MASTER_DB / 20.0)
    return {"out": out, "t": t, "vehicles": per_vehicle, "sc": sc}


# ------------------------------------------------------------------------------------------------
# Analysis
# ------------------------------------------------------------------------------------------------

def frame_levels(x: np.ndarray, win_s: float = 0.05) -> tuple:
    w = int(win_s * SR)
    m = len(x) // w
    e = np.mean(x[:m * w].reshape(m, w) ** 2, axis=1)
    return (np.arange(m) + 0.5) * win_s, 10.0 * np.log10(e + 1e-12)


def log_spectrum(x: np.ndarray, grid: np.ndarray, nfft: int) -> np.ndarray:
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)), nfft))
    f = np.fft.rfftfreq(nfft, 1.0 / SR)
    s = np.interp(grid, f, spec)
    s = np.log(s + 1e-9)
    return s - s.mean()


def pitch_track(x: np.ndarray, loop: np.ndarray, rate: float, times: np.ndarray, win: int = 8192) -> np.ndarray:
    """Pitch ratio of x (the Doppler-resampled engine layer) against the dry loop at each time: log-frequency
    spectra (40 Hz - 2.5 kHz, 0.05 % steps) cross-correlated over +-15 % around the nominal rate."""
    step = 0.0005
    grid = 40.0 * np.exp(np.arange(int(math.log(2500.0 / 40.0) / step)) * step)
    nfft = 4 * win
    refs = [log_spectrum(loop[i:i + win], grid, nfft) for i in range(0, len(loop) - win, win // 2)]
    ref = np.mean(refs, axis=0)
    lags = np.arange(-int(0.15 / step), int(0.15 / step) + 1) + int(round(math.log(rate) / step))
    out = []
    for tc in times:
        a = int(tc * SR) - win // 2
        if a < 0 or a + win > len(x):
            out.append(np.nan)
            continue
        s = log_spectrum(x[a:a + win], grid, nfft)
        best, best_c = 0, -1e9
        for lag in lags:
            if lag >= 0:
                c = float(np.dot(s[lag:], ref[:len(ref) - lag]))
            else:
                c = float(np.dot(s[:lag], ref[-lag:]))
            if c > best_c:
                best, best_c = lag, c
        out.append(math.exp(best * step))
    return np.array(out)


def short_term_loudness(x: np.ndarray, t0: float, t1: float, win_s: float = 0.4) -> float:
    """Highest K-weighted level of 400 ms windows (hop 100 ms) between t0 and t1 (mono)."""
    best = -200.0
    w = int(win_s * SR)
    for a in range(int(t0 * SR), int(t1 * SR) - w, int(0.1 * SR)):
        if a >= 0:
            best = max(best, es.loudness_db(x[a:a + w]))
    return best


def centroid(x: np.ndarray) -> tuple:
    """Spectral centroid (Hz) and the share of the energy below 250 Hz (dB)."""
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return float(np.sum(f * spec) / np.sum(spec)), 10.0 * math.log10(float(np.sum(spec[f < 250.0]) / np.sum(spec)))


def analyse(res: dict) -> dict:
    out, t, sc = res["out"], res["t"], res["sc"]
    tl, lev_l = frame_levels(out[:, 0])
    _, lev_r = frame_levels(out[:, 1])
    mono = out.sum(axis=1)
    res["levels"] = (tl, lev_l, lev_r)
    checks = {"title": sc["title"], "peak_dbfs": round(20.0 * math.log10(np.max(np.abs(out)) + 1e-12), 2),
              "vehicles": []}
    for pv in res["vehicles"]:
        veh, voice = pv["veh"], pv["voice"]
        tp = veh["t_pass"]
        dy = pv["dy"]
        # approach: vehicle 8..40 m away on the side it comes from
        app = (np.abs(dy) > 8.0) & (np.abs(dy) < 40.0) & (t < tp)
        idx = np.clip((t[app] / 0.05).astype(int), 0, len(lev_l) - 1)
        lr = float(np.mean(lev_l[idx] - lev_r[idx])) if np.any(app) else float("nan")
        near = np.abs(t - tp) < 0.3
        idx = np.clip((t[near] / 0.05).astype(int), 0, len(lev_l) - 1)
        lr_pass = float(np.mean(lev_l[idx] - lev_r[idx]))
        # pitch through the pass: measured (log-spectral correlation) vs. exact (rate x d tau / dt)
        eng = voice["layers"]["engine"]
        times = np.arange(max(tp - 3.0, 0.3), min(tp + 3.0, t[-1] - 0.3), 0.1)
        meas = pitch_track(pv["dry"]["engine"], res["loops"][eng["name"]], eng["rate"], times)
        exact = eng["rate"] * np.interp(times, t, pv["doppler"])
        pv["pitch"] = (times, meas, exact)
        before = (times > tp - 2.0) & (times < tp - 0.7)
        after = (times > tp + 0.7) & (times < tp + 2.0)
        drop_meas = float(np.nanmean(meas[after]) / np.nanmean(meas[before]))
        drop_exact = float(np.mean(exact[after]) / np.mean(exact[before]))
        cen, lf = centroid(mono[int((tp - 0.5) * SR):int((tp + 0.5) * SR)])
        checks["vehicles"].append({
            "model": veh["model"], "class": voice["class"], "engine": eng["name"], "kmh": veh["kmh"],
            "lane": "links" if veh["x"] < 0 else "rechts", "spread": round(voice["spread"], 3),
            "approach_l_minus_r_db": round(lr, 1), "passing_l_minus_r_db": round(lr_pass, 1),
            "pitch_after_over_before_measured": round(drop_meas, 4),
            "pitch_after_over_before_exact": round(drop_exact, 4),
            "pitch_track_err_max": round(float(np.nanmax(np.abs(meas / exact - 1.0))), 4),
            "peak_loudness_lufs": round(short_term_loudness(mono, tp - 1.5, tp + 1.5), 1),
            "centroid_hz": round(cen, 0), "below_250hz_db": round(lf, 1)})
    return checks


# ------------------------------------------------------------------------------------------------
# Output: WAV, OGG, spectrogram, plot, MP4
# ------------------------------------------------------------------------------------------------

def write_wav(path: str, x: np.ndarray) -> None:
    x = np.atleast_2d(x.T).T if x.ndim == 1 else x
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def tool(name: str, *args) -> bool:
    exe = shutil.which(name)
    if not exe:
        return False
    r = subprocess.run([exe, *args], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"{name}:", r.stderr.strip()[-400:])
    return r.returncode == 0


FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


SPEC_RANGE = (30.0, 12000.0)     # spectrogram frequency range (log scale)


def media(wav: str, title: str, dur: float, mp4: bool = True) -> None:
    """OGG, spectrogram PNG (with legend) and an MP4 to watch and listen: the whole spectrogram of the clip
    (mono sum) with frequency labels, the title and a playhead moving with the sound (H.264 + AAC)."""
    base = wav[:-4]
    lo, hi = SPEC_RANGE
    tool("ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", base + ".ogg")
    tool("ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-lavfi",
         f"showspectrumpic=s=1600x800:legend=1:scale=log:fscale=log:drange=80:color=intensity:start={lo:g}:stop={hi:g}",
         base + "_spec.png")
    if not mp4:
        return
    w, h, top = 1280, 640, 80
    pic = base + "_video_bg.png"
    tool("ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-lavfi",
         f"aformat=channel_layouts=mono,showspectrumpic=s={w}x{h}:legend=0:scale=log:fscale=log:drange=80:"
         f"color=intensity:start={lo:g}:stop={hi:g}", pic)
    txt = title.replace(":", "\\:").replace("'", "")
    labels = ""
    for f, s in ((50, "50 Hz"), (100, "100 Hz"), (250, "250 Hz"), (500, "500 Hz"), (1000, "1 kHz"),
                 (2000, "2 kHz"), (5000, "5 kHz"), (10000, "10 kHz")):
        y = top + h * (1.0 - math.log(f / lo) / math.log(hi / lo))
        labels += (f",drawtext=fontfile={FONT}:text='{s}':fontcolor=white@0.85:fontsize=15:x=8:y={y - 8:.0f},"
                   f"drawbox=x=0:y={y:.0f}:w=6:h=1:color=white@0.8:t=fill")
    fc = (f"[0:v]scale={w}:{h},pad={w}:{h + top}:0:{top}:0x111111,"
          f"drawtext=fontfile={FONT}:text='{txt}':fontcolor=white:fontsize=24:x=16:y=16,"
          f"drawtext=fontfile={FONT}:text='Spektrogramm (Summe L+R), Zeit von links nach rechts':"
          f"fontcolor=0xbbbbbb:fontsize=16:x=16:y=50{labels}[bg];"
          f"[bg][2:v]overlay=x='t/{dur:.4f}*{w}':y={top}:shortest=1,format=yuv420p[v]")
    tool("ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-framerate", "30", "-i", pic, "-i", wav,
         "-f", "lavfi", "-i", f"color=c=white:s=3x{h}:r=30", "-filter_complex", fc, "-map", "[v]", "-map", "1:a",
         "-c:v", "libx264", "-preset", "medium", "-crf", "22", "-tune", "stillimage", "-c:a", "aac", "-b:a", "160k",
         "-ar", "48000", "-t", f"{dur:.3f}", base + ".mp4")
    if os.path.exists(pic):
        os.remove(pic)


class Raster:
    """Minimal line plot raster (numpy RGB) with labels added by ImageMagick (text annotation)."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.img = np.full((h, w, 3), 255, np.uint8)
        self.labels: list = []

    def line(self, x0, y0, x1, y1, color, width: int = 2) -> None:
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 2
        xs = np.linspace(x0, x1, n)
        ys = np.linspace(y0, y1, n)
        for dx in range(-(width // 2), width - width // 2):
            for dy in range(-(width // 2), width - width // 2):
                xi = np.clip(np.round(xs).astype(int) + dx, 0, self.w - 1)
                yi = np.clip(np.round(ys).astype(int) + dy, 0, self.h - 1)
                self.img[yi, xi] = color

    def polyline(self, xs, ys, color, width: int = 2) -> None:
        ok = np.isfinite(xs) & np.isfinite(ys)
        xs, ys = np.asarray(xs)[ok], np.asarray(ys)[ok]
        for i in range(len(xs) - 1):
            self.line(xs[i], ys[i], xs[i + 1], ys[i + 1], color, width)

    def dots(self, xs, ys, color, r: int = 3) -> None:
        for x, y in zip(xs, ys):
            if np.isfinite(x) and np.isfinite(y):
                xi, yi = int(round(x)), int(round(y))
                self.img[max(yi - r, 0):yi + r + 1, max(xi - r, 0):xi + r + 1] = color

    def text(self, x: int, y: int, s: str, size: int = 14, color: str = "#333333") -> None:
        self.labels.append((x, y, s, size, color))

    def save(self, path: str) -> None:
        ppm = path[:-4] + ".ppm"
        with open(ppm, "wb") as fh:
            fh.write(f"P6 {self.w} {self.h} 255\n".encode() + self.img.tobytes())
        args = [ppm, "-font", "DejaVu-Sans"]
        for x, y, s, size, color in self.labels:
            args += ["-pointsize", str(size), "-fill", color, "-annotate", f"+{x}+{y}", s]
        ok = tool("convert", *args, path)
        if ok:
            os.remove(ppm)


class Panel:
    def __init__(self, r: Raster, x0, y0, w, h, xlim, ylim, title: str, yfmt: str = "{:.0f}"):
        self.r, self.x0, self.y0, self.w, self.h = r, x0, y0, w, h
        self.xlim, self.ylim = xlim, ylim
        grey = (225, 225, 225)
        for k in range(6):
            yv = ylim[0] + (ylim[1] - ylim[0]) * k / 5
            y = self.Y(yv)
            r.line(x0, y, x0 + w, y, grey, 1)
            r.text(x0 - 62, int(y) + 5, yfmt.format(yv), 12)
        for k in range(int(xlim[0]), int(xlim[1]) + 1):
            x = self.X(k)
            r.line(x, y0, x, y0 + h, grey, 1)
            r.text(int(x) - 4, y0 + h + 18, f"{k}", 12)
        r.line(x0, y0, x0, y0 + h, (90, 90, 90), 1)
        r.line(x0, y0 + h, x0 + w, y0 + h, (90, 90, 90), 1)
        r.text(x0, y0 - 10, title, 15, "#111111")

    def X(self, v):
        return self.x0 + (np.asarray(v, float) - self.xlim[0]) / (self.xlim[1] - self.xlim[0]) * self.w

    def Y(self, v):
        vv = np.clip(np.asarray(v, float), self.ylim[0], self.ylim[1])
        return self.y0 + self.h - (vv - self.ylim[0]) / (self.ylim[1] - self.ylim[0]) * self.h


BLUE, RED, GREEN, ORANGE, GREY = (31, 119, 180), (214, 39, 40), (44, 160, 44), (255, 127, 14), (120, 120, 120)


def plot(res: dict, path: str) -> None:
    tl, ll, lr = res["levels"]
    dur = res["sc"]["dur"]
    r = Raster(1400, 760)
    r.text(20, 30, res["sc"]["title"], 18, "#000000")
    top = max(np.max(ll), np.max(lr))
    p1 = Panel(r, 90, 80, 1270, 280, (0.0, dur), (top - 50.0, top + 2.0),
               "Pegel je 50 ms (dBFS): links blau, rechts rot - die gestrichelten Linien markieren das Passieren")
    p1.r.polyline(p1.X(tl), p1.Y(ll), BLUE, 2)
    p1.r.polyline(p1.X(tl), p1.Y(lr), RED, 2)
    lo, hi = 1.0, 1.0
    for pv in res["vehicles"]:
        times, meas, exact = pv["pitch"]
        rate = pv["voice"]["layers"]["engine"]["rate"]
        lo = min(lo, np.nanmin(meas / rate), np.min(exact / rate))
        hi = max(hi, np.nanmax(meas / rate), np.max(exact / rate))
    p2 = Panel(r, 90, 430, 1270, 260, (0.0, dur), (lo - 0.01, hi + 0.01),
               "Tonhöhe des Motors relativ zur Schleife (Doppler): gemessen (Punkte) / exakt (Linie)", "{:.3f}")
    for k, pv in enumerate(res["vehicles"]):
        tp = pv["veh"]["t_pass"]
        for p in (p1, p2):
            for yy in np.arange(p.y0, p.y0 + p.h, 8):
                r.line(p.X(tp), yy, p.X(tp), yy + 4, GREY, 1)
        times, meas, exact = pv["pitch"]
        rate = pv["voice"]["layers"]["engine"]["rate"]
        col = [GREEN, ORANGE, BLUE, RED][k % 4]
        p2.r.polyline(p2.X(times), p2.Y(exact / rate), col, 2)
        p2.r.dots(p2.X(times), p2.Y(meas / rate), col, 3)
        r.text(int(p1.X(tp)) + 6, 100 + 18 * (k % 2), f"{pv['veh']['model']} {pv['veh']['kmh']:.0f} km/h", 13)
    r.text(660, 745, "Zeit (s)", 14)
    r.save(path)


def loops_demo(ts: TrafficSet, out_dir: str) -> dict:
    """Every loop twice in a row (the loop point lies in the middle of each pair), 0.4 s pause between."""
    parts, info, t = [], {}, 0.0
    for name, x in ts.loops.items():
        y = np.concatenate([x, x])
        info[name] = {"start_s": round(t, 2), "loop_point_s": round(t + len(x) / SR, 3)}
        parts += [y, np.zeros(int(0.4 * SR))]
        t += (len(y) + int(0.4 * SR)) / SR
    y = np.concatenate(parts) * 10.0 ** (-3.0 / 20.0)
    path = os.path.join(out_dir, "loops.wav")
    write_wav(path, y)
    media(path, "Alle Schleifen je zweimal hintereinander (Schleifenpunkt jeweils in der Mitte)", len(y) / SR)
    return info


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Verkehrsgeräusche: Vorbeifahrt-Simulationen, Spektrogramme, Prüfungen")
    ap.add_argument("--sounds", default=os.path.join(ROOT, "assets", "audio", "traffic"))
    ap.add_argument("--out", default=SCRATCH)
    ap.add_argument("--scenario", action="append", choices=list(SCENARIOS))
    ap.add_argument("--no-media", action="store_true", help="nur rechnen und prüfen (keine Dateien außer WAV)")
    ap.add_argument("--gain", action="append", default=[], metavar="NAME=DB",
                    help="gain_db einer Schleife für diesen Lauf überschreiben (Abgleich ausprobieren)")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    ts = TrafficSet(args.sounds)
    for g in args.gain:
        k, v = g.split("=")
        ts.sounds[k]["gain_db"] = float(v)
    summary = {"model": {"c": C_AIR, "ref_m": REF_M, "size_m": SIZE_M, "fade_m": FADE_M, "pan_width": PAN_WIDTH,
                         "master_db": MASTER_DB}, "scenarios": {}}
    for name in args.scenario or list(SCENARIOS):
        res = render(ts, SCENARIOS[name])
        res["loops"] = ts.loops
        chk = analyse(res)
        summary["scenarios"][name] = chk
        path = os.path.join(args.out, f"{name}.wav")
        write_wav(path, res["out"])
        if not args.no_media:
            media(path, SCENARIOS[name]["title"], SCENARIOS[name]["dur"])
            plot(res, os.path.join(args.out, f"{name}_plot.png"))
        print(f"{name}: {chk['title']} - Spitze {chk['peak_dbfs']:.1f} dBFS")
        for v in chk["vehicles"]:
            print(f"   {v['model']:6s} ({v['class']}, {v['engine']}, {v['kmh']:.0f} km/h, {v['lane']}): "
                  f"L-R Anfahrt {v['approach_l_minus_r_db']:+.1f} dB, beim Passieren "
                  f"{v['passing_l_minus_r_db']:+.1f} dB; Tonhöhe nach/vor dem Passieren "
                  f"{v['pitch_after_over_before_measured']:.4f} (exakt {v['pitch_after_over_before_exact']:.4f}, "
                  f"Messfehler max {100 * v['pitch_track_err_max']:.2f} %); Lautheit max "
                  f"{v['peak_loudness_lufs']:.1f} LUFS, Schwerpunkt {v['centroid_hz']:.0f} Hz, "
                  f"Anteil unter 250 Hz {v['below_250hz_db']:.1f} dB")
    if not args.no_media:
        summary["loops_demo"] = loops_demo(ts, args.out)
    with open(os.path.join(args.out, "checks.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=1, ensure_ascii=False, default=float)
    return 0


if __name__ == "__main__":
    sys.exit(main())
