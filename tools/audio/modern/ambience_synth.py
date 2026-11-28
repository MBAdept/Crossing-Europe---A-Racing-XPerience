#!/usr/bin/env python3
"""Ambience of the surroundings – profile "Modern", package AU-C2 (contract D25–D29, §4.7.3; docs/audio-modern.md
"Welt, Ambiente, Verkehr"). Writes into assets/audio/modern/ambience/ (Ogg Vorbis, 44.1 kHz) and registers the
sounds in the folder's manifest (modern_lib.Manifest: only this generator's own entries are replaced; files it wrote
before and no longer writes are removed).

    python3 tools/audio/modern/ambience_synth.py               into the repository (with Godot import files)
    python3 tools/audio/modern/ambience_synth.py --out /tmp/x  into /tmp/x/assets/audio/modern/ambience (QC determinism)
    python3 tools/audio/modern/ambience_synth.py --wav /tmp/p  also a preview WAV of every sound

Two kinds of sound:
  * beds (kind "loop", stereo, Ogg Vorbis q3–q4): dense textures without salient single events – wind in grass and
    leaves, crickets, cicadas, the distant traffic of a city by day and by night, water at a quay, the jet fans of a
    tunnel (its reverberation baked in), the hum under a fuel-station or border canopy, rain on the car and the road.
    A salient event inside a loop of 10–14 s would be heard again every 10–14 s; the beds have none. Every bed is
    seamless by construction: noise is periodic (random phases on an FFT grid of the loop length), events are placed
    circularly, modulations are periodic, tones have whole numbers of cycles, reverberation is a circular convolution.
  * events (kind "oneshot", mono, Ogg Vorbis q4): calls and sounds the runtime scatters at random – birds (blackbird,
    chaffinch, great tit, sparrow, crow, skylark, woodpecker), owl, a distant dog, gulls, a distant ship's horn, a
    distant car horn, pigeons, a church bell, a distant scooter. Each carries its own space (a short outdoor or
    street reverberation and the air absorption of some tens of metres); the runtime chooses variant, side, level
    and a small pitch offset, so nothing repeats in step.

Manifest entries carry, besides the measured values of modern_lib:
    bed        (beds) what the runtime uses it for ("breeze", "leaves", …; docs: AmbienceAudio)
    category   (events) the scheduler's category ("bird", "owl", "gull", …)
    lufs_m     (events) momentary maximum (400 ms) of each variant – the runtime sets event levels from it
    vorbis_q   the Vorbis quality written (beds: the first from q3 whose seam is no rougher than twice its surroundings)
The levels are data (config audio.modern.ambience): the files carry no level decision (gain_db 0, peak −3 dBFS).
Deterministic (fixed seeds, no time stamps, Vorbis bit-exact): audio_qc.py --determinism runs this twice and
compares the bytes. Nobody has listened to these sounds while they were made – every choice is a model of the
source (documented next to it) checked by measurement.
"""
from __future__ import annotations

import argparse
import math
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402
import vehicle_loops as vl  # noqa: E402  (DSP helpers and the import writers that keep the .import head)

GENERATOR = "tools/audio/modern/ambience_synth.py"
FOLDER = "ambience"
SR = ml.SR
PEAK = 0.708                    # every file at -3 dBFS sample peak (the runtime sets the level from the loudness)
BED_Q = (3.0, 3.5, 4.0)         # Vorbis qualities tried for a bed (contract §4.7.3: ambience q3–q4)
EVENT_Q = 3.0                   # mono one-shots: q3 is ~80 kbit/s, plenty for calls heard at a distance
TAU2 = 2.0 * np.pi

bp, lp, hp, peak, rms = vl.bp, vl.lp, vl.hp, vl.peak, vl.rms


# ------------------------------------------------------------------------------------------------------------------
# helpers
# ------------------------------------------------------------------------------------------------------------------

def pink(f):
    return 1.0 / np.sqrt(f)


def pn(n: int, seed: int, shape) -> np.ndarray:
    """Periodic noise of n samples, unit RMS."""
    return vl.pnoise(n, seed, shape)


def stereo_noise(n: int, seed: int, shape, corr: float) -> np.ndarray:
    """Two periodic noises (n, 2) with correlation `corr` between the channels, unit RMS each."""
    c = pn(n, seed, shape)
    a = pn(n, seed + 1, shape)
    b = pn(n, seed + 2, shape)
    k = math.sqrt(max(corr, 0.0))
    m = math.sqrt(max(1.0 - corr, 0.0))
    return np.stack([k * c + m * a, k * c + m * b], axis=1)


def slow(n: int, seed: int, lo: float, hi: float) -> np.ndarray:
    """Periodic slow modulation, unit standard deviation."""
    return vl.slow(n, seed, lo, hi)


def db2(x):
    return 10.0 ** (np.asarray(x, np.float64) / 20.0)


def pan_gains(p: float) -> tuple[float, float]:
    th = (min(max(p, -1.0), 1.0) + 1.0) * math.pi / 4.0
    return math.cos(th) * math.sqrt(2.0), math.sin(th) * math.sqrt(2.0)


def place2(out: np.ndarray, clip: np.ndarray, at: int, gain: float, pan: float) -> None:
    """Adds a mono clip circularly into a stereo loop at a pan (equal power, centre = 0 dB per channel)."""
    gl, gr = pan_gains(pan)
    n = len(out)
    idx = (at + np.arange(len(clip))) % n
    np.add.at(out[:, 0], idx, gain * gl * clip)
    np.add.at(out[:, 1], idx, gain * gr * clip)


def ffilter(x: np.ndarray, shape) -> np.ndarray:
    """Zero-phase filtering of a one-shot (not circular: padded so nothing wraps)."""
    x = np.asarray(x, np.float64)
    m = len(x)
    pad = 1 << int(math.ceil(math.log2(m + 4096)))
    f = np.maximum(np.fft.rfftfreq(pad, 1.0 / SR), 1e-3)
    y = np.fft.irfft(np.fft.rfft(x, pad) * shape(f), pad)
    return y[:m]


def cfilter(x: np.ndarray, shape) -> np.ndarray:
    """Circular filtering of a loop (each channel)."""
    if x.ndim == 1:
        return vl.cfilter(x, shape)
    return np.stack([vl.cfilter(x[:, c], shape) for c in range(x.shape[1])], axis=1)


def conv(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    """Linear convolution (FFT) of a one-shot with an impulse response: the result is len(x) + len(h) - 1 long."""
    m = len(x) + len(h) - 1
    pad = 1 << int(math.ceil(math.log2(m)))
    return np.fft.irfft(np.fft.rfft(x, pad) * np.fft.rfft(h, pad), pad)[:m]


def cconv(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    """Circular convolution of a loop with an impulse response shorter than the loop (a periodic signal through a
    linear system: the steady state is exactly periodic)."""
    n = len(x)
    if len(h) >= n:
        h = h[:n - 1]
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(h, n), n)


def room_ir(seconds: float, seed: int, rt60_lo: float, rt60_hi: float, early: list[tuple[float, float]],
            lp_hz: float = 9000.0, direct: float = 1.0, drr_db: float = 8.0) -> np.ndarray:
    """A synthetic impulse response: the direct sound, a few early reflections (delay s, gain) and a diffuse tail of
    noise that decays with rt60_lo below 1 kHz and rt60_hi above (two bands, crossover at 1 kHz), low-passed. The
    tail's energy is set by the direct-to-reverberant ratio drr_db (direct² / tail energy): outdoors the direct sound
    dominates (open land ~10 dB), a far source or a tunnel is mostly reverberation (below 0 dB)."""
    m = int(seconds * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(m) / SR
    h = np.zeros(m)
    h[0] = direct
    for d, g in early:
        k = int(d * SR)
        if k < m:
            h[k] += g * (1.0 if rng.random() < 0.5 else -1.0)
    nz = rng.standard_normal(m)
    lo = ffilter(nz, lambda f: lp(f, 1000.0, 2))
    hi = nz - lo
    onset = np.clip(t / 0.012, 0.0, 1.0)
    tail = lo * np.exp(-6.91 * t / rt60_lo) + hi * np.exp(-6.91 * t / rt60_hi)
    tail *= onset
    tail *= math.sqrt(max(direct, 0.05) ** 2 * 10.0 ** (-drr_db / 10.0) / max(float(np.sum(tail ** 2)), 1e-20))
    h += tail
    return ffilter(h, lambda f: lp(f, lp_hz, 2))


def finish_event(y: np.ndarray, fade_in_s: float = 0.002, fade_out_s: float = 0.05) -> np.ndarray:
    """Short fades at both ends (no click when the runtime starts or the file ends), the tail trimmed where it has
    fallen 50 dB under the peak (and faded over the last fade_out_s)."""
    y = np.asarray(y, np.float64)
    a = np.abs(y)
    thr = float(np.max(a)) * 10.0 ** (-50.0 / 20.0)
    idx = np.nonzero(a > thr)[0]
    if len(idx):
        y = y[max(idx[0] - 32, 0): idx[-1] + 1]
    k = min(int(fade_in_s * SR), len(y) // 4)
    if k > 1:
        y[:k] *= np.linspace(0.0, 1.0, k)
    return vl.fade_tail(y, fade_out_s)


def tone(freq: np.ndarray, amp: np.ndarray, harmonics=((1, 1.0),), phase: float = 0.0) -> np.ndarray:
    """A tone along a frequency contour (Hz per sample) with an amplitude envelope and harmonics (k, gain); harmonics
    above 0.45 × SR are left out."""
    ph = TAU2 * np.cumsum(freq) / SR + phase
    out = np.zeros(len(freq))
    fmax = float(np.max(freq))
    for k, g in harmonics:
        if k * fmax < 0.45 * SR:
            out += g * np.sin(k * ph)
    return out * amp


def env_arch(m: int, attack: float = 0.25, release: float = 0.35) -> np.ndarray:
    """Smooth envelope: raised-cosine attack and release (shares of the length)."""
    e = np.ones(m)
    a = max(int(m * attack), 1)
    r = max(int(m * release), 1)
    e[:a] = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, a))
    e[-r:] = 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, r))
    return e


def contour(m: int, pts: list[tuple[float, float]]) -> np.ndarray:
    """A frequency contour through (share of the length, Hz) points, smooth (cosine interpolation)."""
    x = np.linspace(0.0, 1.0, m)
    xs = np.array([p[0] for p in pts])
    ys = np.array([p[1] for p in pts])
    out = np.empty(m)
    for i in range(len(pts) - 1):
        sel = (x >= xs[i]) & (x <= xs[i + 1])
        u = (x[sel] - xs[i]) / max(xs[i + 1] - xs[i], 1e-9)
        w = 0.5 - 0.5 * np.cos(np.pi * u)
        out[sel] = ys[i] + (ys[i + 1] - ys[i]) * w
    return out


def seq(parts: list[tuple[float, np.ndarray]], tail_s: float = 0.0) -> np.ndarray:
    """Clips at start times (s): [(t, clip), …] into one mono signal."""
    end = max(int(t * SR) + len(c) for t, c in parts) + int(tail_s * SR)
    out = np.zeros(end)
    for t, c in parts:
        k = int(t * SR)
        out[k:k + len(c)] += c
    return out


def distant(y: np.ndarray, metres: float, ir: np.ndarray | None) -> np.ndarray:
    """Air absorption over `metres` (a gentle low-pass, ISO 9613 at 20 °C / 70 % in a simplified fit: ~ −0.01 dB/m at
    4 kHz, ~ −0.04 dB/m at 8 kHz) and the space of the place."""
    def air(f):
        return db2(-(metres * (0.0006 * (f / 1000.0) ** 1.8)))
    y = ffilter(y, air)
    if ir is not None:
        y = conv(y, ir)
    return y


# outdoor spaces of the events: open land (ground and a hedge or two), forest (dense scattering), street (facades)
def ir_open(seed: int) -> np.ndarray:
    return room_ir(0.9, seed, 0.7, 0.45, [(0.006, 0.45), (0.031, 0.18), (0.067, 0.10)], 9000.0, drr_db=10.0)


def ir_forest(seed: int) -> np.ndarray:
    return room_ir(1.6, seed, 1.4, 0.9, [(0.004, 0.40), (0.019, 0.22), (0.037, 0.16), (0.055, 0.12)], 7500.0,
                   drr_db=4.0)


def ir_street(seed: int) -> np.ndarray:
    return room_ir(1.5, seed, 1.25, 0.8, [(0.009, 0.5), (0.042, 0.32), (0.071, 0.25), (0.113, 0.16)], 8000.0,
                   drr_db=3.0)


def ir_far(seed: int) -> np.ndarray:
    """A sound from far away over open land or water: echoes from distant buildings and slopes, a long tail."""
    return room_ir(3.0, seed, 2.4, 1.2, [(0.12, 0.30), (0.31, 0.20), (0.55, 0.12)], 4000.0, drr_db=-2.0)


# ------------------------------------------------------------------------------------------------------------------
# beds
# ------------------------------------------------------------------------------------------------------------------

def bed_breeze(n: int) -> np.ndarray:
    """Open land: a soft breeze – a low rush and the swish of grass and hedges, gusting every few seconds (gusts
    0.05–0.4 Hz, ±4 dB, partly different left and right), the swish louder in the gusts."""
    rush = stereo_noise(n, 101, lambda f: bp(f, 140.0, 900.0, 2) * pink(f), 0.55) * 0.6
    swish = stereo_noise(n, 111, lambda f: bp(f, 1500.0, 6500.0, 2) * peak(f, 3600.0, 0.8, 4.0), 0.25)
    g_common = slow(n, 121, 0.05, 0.4)
    g_l = slow(n, 122, 0.05, 0.4)
    g_r = slow(n, 123, 0.05, 0.4)
    gust = np.stack([0.7 * g_common + 0.3 * g_l, 0.7 * g_common + 0.3 * g_r], axis=1)
    flutter = np.abs(stereo_noise(n, 131, lambda f: bp(f, 1.5, 9.0, 2), 0.2))
    flutter = flutter / np.mean(flutter)
    y = rush * db2(4.0 * gust) + 0.45 * swish * db2(6.0 * gust) * (0.55 + 0.45 * flutter)
    return y


def bed_leaves(n: int) -> np.ndarray:
    """Forest: the canopy – dense rustle of leaves (1.5–10 kHz, fluttering 2–12 Hz), the roar of the trees in the
    gusts (80–500 Hz), slower gusts than in the open."""
    rustle = stereo_noise(n, 201, lambda f: bp(f, 1200.0, 7000.0, 2) * peak(f, 3000.0, 0.7, 3.0), 0.15)
    roar = stereo_noise(n, 211, lambda f: bp(f, 60.0, 520.0, 2) * pink(f), 0.5)
    gc = slow(n, 221, 0.03, 0.25)
    gust = np.stack([0.75 * gc + 0.25 * slow(n, 222, 0.03, 0.25), 0.75 * gc + 0.25 * slow(n, 223, 0.03, 0.25)], axis=1)
    flutter = np.abs(stereo_noise(n, 231, lambda f: bp(f, 2.0, 12.0, 2), 0.1))
    flutter = flutter / np.mean(flutter)
    return 0.7 * rustle * db2(5.0 * gust) * (0.5 + 0.5 * flutter) + roar * db2(6.0 * gust)


def bed_crickets(n: int) -> np.ndarray:
    """A summer night on open land: field crickets calling (each chirp 4 syllables of 14 ms every 32 ms on a carrier
    of 4.3–5.1 kHz, 1.8–2.6 chirps a second), seven of them at different distances and sides, a bush cricket's
    faint buzz at 9–13 kHz and the low air of the night. Each cricket has a whole number of chirps per loop."""
    rng = np.random.default_rng(301)
    out = np.zeros((n, 2))
    loop_s = n / SR
    for i in range(7):
        fc = rng.uniform(4300.0, 5100.0)
        rate = rng.uniform(1.8, 2.6)
        k = max(1, int(round(rate * loop_s)))
        period = n / k
        dist_db = -rng.uniform(0.0, 16.0)
        pan = rng.uniform(-0.9, 0.9)
        offset = rng.uniform(0.0, period)
        syl_m = int(0.014 * SR)
        e = env_arch(syl_m, 0.3, 0.45)
        for c in range(k):
            at = offset + c * period + rng.normal(0.0, 0.006) * SR
            g = db2(dist_db + rng.normal(0.0, 1.0))
            for s in range(4):
                f = np.full(syl_m, fc) * np.linspace(1.0, 0.985, syl_m)
                syl = tone(f, e, ((1, 1.0), (2, 0.08)))
                place2(out, syl, int(at + s * 0.032 * SR), g, pan)
    # distance: farther crickets are a little duller (one shared gentle low-pass on the far half is enough)
    buzz_env = 0.5 + 0.5 * np.cos(TAU2 * 41.0 * np.arange(n) / SR)
    buzz = stereo_noise(n, 311, lambda f: bp(f, 9000.0, 13000.0, 3), 0.3) * (buzz_env[:, None] ** 3) * 0.06
    air = stereo_noise(n, 321, lambda f: bp(f, 40.0, 600.0, 1) * pink(f), 0.6) * 0.05
    return out + buzz + air


def bed_cicadas(n: int) -> np.ndarray:
    """A Mediterranean summer day: cicadas – a chorus of rough buzzes (noise 4–9 kHz pulsed 220–260 times a second)
    that swells and fades over seconds, and two rhythmic singers (bursts of 120 ms, 3–4 a second)."""
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    rng = np.random.default_rng(401)
    loop_s = n / SR
    for i in range(4):
        fp = round(rng.uniform(220.0, 260.0) * loop_s) / loop_s            # whole number of pulses per loop
        pulses = (0.5 + 0.5 * np.cos(TAU2 * fp * t + rng.uniform(0, 6.28))) ** 6
        fpk = rng.uniform(4200.0, 5600.0)
        carrier = pn(n, 411 + i, lambda f, fpk=fpk: bp(f, 3000.0, 8000.0, 2) * peak(f, fpk, 1.5, 6.0) * lp(f, 9000.0, 3))
        swell = db2(7.0 * slow(n, 421 + i, 0.05, 0.25) - 4.0)
        y = carrier * pulses * swell * db2(-rng.uniform(0.0, 9.0))
        gl, gr = pan_gains(rng.uniform(-0.8, 0.8))
        out[:, 0] += gl * y
        out[:, 1] += gr * y
    for i in range(2):
        rate = rng.uniform(3.0, 4.0)
        k = max(1, int(round(rate * loop_s)))
        period = n / k
        burst_m = int(0.12 * SR)
        e = env_arch(burst_m, 0.15, 0.4)
        car = pn(burst_m, 431 + i, lambda f: bp(f, 3500.0, 6500.0, 3))
        pls = (0.5 + 0.5 * np.cos(TAU2 * 300.0 * np.arange(burst_m) / SR)) ** 4
        clip = car * pls * e
        pan = rng.uniform(-0.7, 0.7)
        g0 = db2(-rng.uniform(2.0, 8.0))
        for c in range(k):
            place2(out, clip, int(c * period + rng.normal(0.0, 0.004) * SR), g0 * db2(rng.normal(0.0, 0.8)), pan)
    return out


def _passing(n: int, seed: int, count: int, lo: float, hi: float, gain_db: float) -> np.ndarray:
    """Distant vehicles passing along streets nearby: swells of band noise of 2–4 s that move across the stereo image
    and brighten towards their middle."""
    rng = np.random.default_rng(seed)
    out = np.zeros((n, 2))
    for i in range(count):
        dur = rng.uniform(2.0, 4.0)
        m = int(dur * SR)
        nz = rng.standard_normal(m)
        lo_m = ffilter(nz, lambda f: bp(f, lo, hi * 0.5, 2))
        hi_m = ffilter(nz, lambda f: bp(f, hi * 0.5, hi, 2))
        e = env_arch(m, 0.45, 0.45)
        clip = (lo_m + hi_m * e) * e
        clip /= rms(clip)
        at = int(rng.uniform(0, n))
        p0 = rng.uniform(-0.8, 0.8)
        p1 = -p0 * rng.uniform(0.4, 1.0)
        g = db2(gain_db - rng.uniform(0.0, 8.0))
        pans = np.linspace(p0, p1, m)
        th = (pans + 1.0) * np.pi / 4.0
        idx = (at + np.arange(m)) % n
        np.add.at(out[:, 0], idx, g * np.cos(th) * math.sqrt(2.0) * clip)
        np.add.at(out[:, 1], idx, g * np.sin(th) * math.sqrt(2.0) * clip)
    return out


def _hum(n: int, f0: float, gains: list[float], beat: float = 0.0) -> np.ndarray:
    """Mains hum at a whole number of cycles per loop: harmonics k·f0 with gains, optionally a second source
    `beat` Hz higher (both rounded to whole cycles)."""
    t = np.arange(n) / SR
    loop_s = n / SR
    y = np.zeros(n)
    for src, df in ((0, 0.0), (1, beat)):
        if src and beat == 0.0:
            continue
        for k, g in enumerate(gains, start=1):
            f = round((k * (f0 + df)) * loop_s) / loop_s
            y += g * np.sin(TAU2 * f * t + 0.7 * k + src)
    return y


def bed_city_day(n: int) -> np.ndarray:
    """A city by day: the wash of traffic in the streets around (pink noise mostly below 2 kHz, slowly changing),
    a few vehicles passing in nearby streets, the hum of building ventilation and a little high air."""
    wash = stereo_noise(n, 501, lambda f: bp(f, 35.0, 2200.0, 1) * pink(f) * peak(f, 120.0, 0.7, 4.0), 0.35)
    wash *= db2(3.0 * slow(n, 511, 0.03, 0.2))[:, None]
    passing = _passing(n, 521, 7, 70.0, 3000.0, -4.0)
    hum = _hum(n, 100.0, [0.03, 0.012, 0.008], 0.25)
    air = stereo_noise(n, 531, lambda f: bp(f, 2500.0, 9000.0, 1), 0.2) * 0.06
    return wash + passing + hum[:, None] * np.array([1.0, 0.8]) + air


def bed_city_night(n: int) -> np.ndarray:
    """A city at night: a lower wash, a steady distant drone of a ring road, fewer passing vehicles, the ventilation
    hum relatively louder."""
    wash = stereo_noise(n, 601, lambda f: bp(f, 35.0, 1500.0, 1) * pink(f), 0.4) * 0.55
    wash *= db2(2.0 * slow(n, 611, 0.03, 0.15))[:, None]
    drone = stereo_noise(n, 621, lambda f: bp(f, 55.0, 320.0, 2), 0.7) * 0.35
    passing = _passing(n, 631, 3, 70.0, 2500.0, -6.0)
    hum = _hum(n, 100.0, [0.035, 0.015, 0.009], 0.25)
    return wash + drone + passing + hum[:, None] * np.array([0.8, 1.0])


def bed_water(n: int) -> np.ndarray:
    """Water at a quay or a bank: small waves lapping (splashes clustered at the wave period of ~5 s), a gentle
    swelling wash, a few gurgles and the wind over the water."""
    rng = np.random.default_rng(701)
    out = np.zeros((n, 2))
    loop_s = n / SR
    waves = max(1, int(round(loop_s / 5.0)))
    wave_p = n / waves
    for w in range(waves):
        centre = w * wave_p + rng.uniform(0, wave_p * 0.2)
        for s in range(int(rng.integers(5, 10))):
            at = int(centre + rng.normal(0.0, 0.5) * SR)
            dur = rng.uniform(0.15, 0.45)
            m = int(dur * SR)
            t = np.arange(m) / SR
            clip = vl.noise_burst(rng, dur, 250.0, rng.uniform(1200.0, 2400.0), dur * 0.35, attack=rng.uniform(0.01, 0.04))
            clip = clip * (1.0 - np.exp(-t / 0.02))
            place2(out, clip, at, db2(-rng.uniform(2.0, 12.0)), rng.uniform(-0.9, 0.9))
    for g in range(int(loop_s * 1.2)):
        dur = rng.uniform(0.03, 0.08)
        f0 = rng.uniform(300.0, 700.0)
        clip = vl.decay_sine(f0, dur * 0.4, dur, f_end=f0 * rng.uniform(1.4, 2.0))
        place2(out, clip, int(rng.uniform(0, n)), db2(-rng.uniform(14.0, 22.0)), rng.uniform(-0.8, 0.8))
    t = np.arange(n) / SR
    swell = 0.6 + 0.4 * np.cos(TAU2 * waves / loop_s * t + 1.0)
    wash = stereo_noise(n, 711, lambda f: bp(f, 90.0, 3500.0, 1) * pink(f), 0.3) * 0.35 * swell[:, None]
    wind = stereo_noise(n, 721, lambda f: bp(f, 60.0, 700.0, 1) * pink(f), 0.5) * 0.15
    return out + wash + wind


def bed_tunnel_fans(n: int) -> np.ndarray:
    """Inside a road tunnel: jet fans under the ceiling – broadband airflow (50 Hz – 4 kHz), the blade-pass tone of
    an 8-bladed fan at 1485 /min (198 Hz and harmonics, modulated at the rotation), motor hum at 100 Hz – all
    through the reverberation of a long concrete tube (2.6 s below 1 kHz, 1.3 s above; two decorrelated responses)."""
    t = np.arange(n) / SR
    loop_s = n / SR
    flow = pn(n, 801, lambda f: bp(f, 50.0, 4000.0, 1) * pink(f) * peak(f, 220.0, 0.8, 3.0))
    frot = round(24.75 * loop_s) / loop_s
    fbp = 8.0 * frot
    blades = sum(g * np.sin(TAU2 * k * fbp * t + k) for k, g in ((1, 1.0), (2, 0.4), (3, 0.18)))
    blades *= 1.0 + 0.25 * np.cos(TAU2 * frot * t)
    hum = _hum(n, 100.0, [1.0, 0.3, 0.15])
    src = flow + 0.25 * blades + 0.12 * hum
    out = np.zeros((n, 2))
    for c in range(2):
        h = room_ir(3.2, 811 + c, 2.6, 1.3, [(0.011 + 0.004 * c, 0.5), (0.029, 0.35), (0.047 + 0.006 * c, 0.3)],
                    6000.0, direct=0.25, drr_db=-9.0)
        out[:, c] = cconv(src, h)
    return out


def bed_hum(n: int) -> np.ndarray:
    """Under a canopy (fuel station, border post): the 100-Hz hum of lamp ballasts and a transformer (harmonics to
    500 Hz, two sources beating slowly), a refrigerated cabinet's compressor rumbling near 50 Hz, ventilation hiss."""
    hum = _hum(n, 100.0, [1.0, 0.55, 0.3, 0.16, 0.08], 0.25)
    comp = pn(n, 901, lambda f: bp(f, 35.0, 180.0, 3) * peak(f, 49.75, 6.0, 12.0)) * 0.35
    hiss = stereo_noise(n, 911, lambda f: bp(f, 800.0, 7000.0, 1), 0.3) * 0.05
    mono = 0.6 * hum + comp
    return np.stack([mono, mono * 0.9], axis=1) + hiss


def bed_rain(n: int) -> np.ndarray:
    """Rain heard from a car standing or rolling slowly: a hiss of countless fine drops, drops on the road and in
    puddles, drops pinging on the roof and bonnet (plate modes 1.2–3.6 kHz), its intensity drifting slowly."""
    rng = np.random.default_rng(1001)
    out = np.zeros((n, 2))
    loop_s = n / SR
    hiss = stereo_noise(n, 1011, lambda f: bp(f, 250.0, 8000.0, 1) * peak(f, 2800.0, 0.6, 4.0) * lp(f, 9000.0, 2), 0.2) * 0.35
    out += hiss
    # splashes on the road and in puddles
    for i in range(int(loop_s * 70)):
        dur = rng.uniform(0.01, 0.04)
        clip = vl.noise_burst(rng, dur, 400.0, rng.uniform(2500.0, 5000.0), dur * 0.3)
        place2(out, clip, int(rng.uniform(0, n)), db2(-rng.uniform(6.0, 20.0)), rng.uniform(-1.0, 1.0))
    # drops on the car: a click and the ring of the panel
    modes = [1250.0, 1710.0, 2240.0, 2890.0, 3570.0]
    for i in range(int(loop_s * 22)):
        f0 = modes[int(rng.integers(0, len(modes)))] * rng.uniform(0.96, 1.04)
        ring = vl.decay_sine(f0, rng.uniform(0.006, 0.02), 0.06, phase=rng.uniform(0, 6.28))
        click = vl.noise_burst(rng, 0.004, 1500.0, 6000.0, 0.0008)
        clip = vl.mixc((0.6, ring), (0.5, click))
        place2(out, clip, int(rng.uniform(0, n)), db2(-rng.uniform(4.0, 16.0)), rng.uniform(-0.6, 0.6))
    out *= db2(2.0 * slow(n, 1021, 0.05, 0.3))[:, None]
    return out


BEDS = [
    # id, seconds, function, note
    ("breeze", 10.3, bed_breeze, "Offenes Land: leichter Wind, Rauschen in Gras und Hecken, Böen alle paar Sekunden"),
    ("leaves", 9.7, bed_leaves, "Wald: dichtes Blätterrauschen, Brausen der Kronen in den Böen"),
    ("crickets", 9.1, bed_crickets, "Sommernacht auf dem Land: sieben Feldgrillen, leises Schwirren einer Laubheuschrecke"),
    ("cicadas", 9.9, bed_cicadas, "Sommertag am Mittelmeer: Zikaden-Chor, an- und abschwellend, zwei rhythmische Sänger"),
    ("city_day", 11.3, bed_city_day, "Stadt am Tag: Verkehr in den Straßen ringsum, vorbeifahrende Autos in der Nähe, Lüftungsbrummen"),
    ("city_night", 10.1, bed_city_night, "Stadt in der Nacht: leiser Verkehr, fernes Dröhnen einer Ringstraße, Lüftungsbrummen"),
    ("water", 10.5, bed_water, "Wasser an Kai oder Ufer: kleine Wellen, Glucksen, Wind über dem Wasser"),
    ("tunnel_fans", 8.9, bed_tunnel_fans, "Im Straßentunnel: Strahlventilatoren (Strömung, Blattton 198 Hz, Motorbrummen) im Hall der Röhre"),
    ("hum", 6.0, bed_hum, "Unter dem Dach von Tankstelle oder Grenze: Brummen der Leuchten und eines Trafos, Kühlregal, Lüftung"),
    ("rain", 10.7, bed_rain, "Regen am stehenden oder langsamen Auto: feines Rauschen, Tropfen auf Straße und Pfützen, Pingen auf dem Blech"),
]


# ------------------------------------------------------------------------------------------------------------------
# events
# ------------------------------------------------------------------------------------------------------------------

def _note(dur: float, pts: list[tuple[float, float]], harm=((1, 1.0), (2, 0.2), (3, 0.06)), vib_hz: float = 0.0,
          vib: float = 0.0, attack: float = 0.2, release: float = 0.35, rng=None) -> np.ndarray:
    m = max(int(dur * SR), 16)
    f = contour(m, pts)
    if vib > 0.0:
        f = f * (1.0 + vib * np.sin(TAU2 * vib_hz * np.arange(m) / SR + (rng.uniform(0, 6.28) if rng is not None else 0.0)))
    return tone(f, env_arch(m, attack, release), harm)


def ev_blackbird(seed: int) -> np.ndarray:
    """Blackbird song: a phrase of 5–8 fluted, gliding notes (1.4–2.8 kHz, 80–240 ms, a little vibrato), then the
    quieter squeaky twitter that ends it (6–9 chirps at 4–7 kHz)."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for i in range(int(rng.integers(5, 9))):
        dur = rng.uniform(0.08, 0.24)
        f0 = rng.uniform(1400.0, 2700.0)
        shape = int(rng.integers(0, 3))
        if shape == 0:
            pts = [(0.0, f0 * 0.92), (0.4, f0 * 1.06), (1.0, f0 * 0.9)]
        elif shape == 1:
            pts = [(0.0, f0), (1.0, f0 * rng.uniform(1.15, 1.35))]
        else:
            pts = [(0.0, f0 * 1.2), (0.6, f0), (1.0, f0 * 0.82)]
        parts.append((t, _note(dur, pts, ((1, 1.0), (2, 0.18), (3, 0.05)), 28.0, 0.012, rng=rng) * db2(rng.normal(0, 2.0))))
        t += dur + rng.uniform(0.02, 0.07)
    t += 0.05
    for i in range(int(rng.integers(6, 10))):
        dur = rng.uniform(0.025, 0.045)
        f0 = rng.uniform(4200.0, 7000.0)
        parts.append((t, 0.35 * _note(dur, [(0.0, f0 * 1.1), (1.0, f0 * 0.8)], ((1, 1.0), (2, 0.1)), attack=0.1,
                                      release=0.4)))
        t += dur + rng.uniform(0.01, 0.03)
    return seq(parts, 0.05)


def ev_chaffinch(seed: int) -> np.ndarray:
    """Chaffinch song: an accelerating, descending trill in three parts (6.5→5 kHz at 14/s, 4.8→3.6 kHz at 11/s,
    3.8→3 kHz at 8/s) and the flourish at the end (a quick sweep up and down)."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for count, rate, f_hi, f_lo, dur in ((5, 14.0, 6500.0, 5000.0, 0.025), (5, 11.0, 4800.0, 3600.0, 0.035),
                                         (3, 8.0, 3800.0, 3000.0, 0.05)):
        k = rng.uniform(0.95, 1.05)
        for i in range(count):
            parts.append((t, _note(dur, [(0.0, f_hi * k), (1.0, f_lo * k)], ((1, 1.0), (2, 0.08)), attack=0.1, release=0.5)
                          * db2(rng.normal(0, 1.0))))
            t += 1.0 / rate
    parts.append((t + 0.02, 1.1 * _note(0.18, [(0.0, 2600.0), (0.45, 5200.0), (1.0, 2800.0)], ((1, 1.0), (2, 0.12)),
                                        attack=0.15, release=0.3)))
    return seq(parts, 0.05)


def ev_great_tit(seed: int) -> np.ndarray:
    """Great tit: "zi-zi-bä" – a high short note (~6.8 kHz) and a lower, longer one (~4.4 kHz), three or four times."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    hi = rng.uniform(6300.0, 7100.0)
    lo = rng.uniform(4100.0, 4600.0)
    for i in range(int(rng.integers(3, 5))):
        parts.append((t, _note(0.05, [(0.0, hi * 1.02), (1.0, hi * 0.97)], ((1, 1.0), (2, 0.05)), attack=0.15, release=0.4)))
        t += 0.09
        parts.append((t, _note(0.09, [(0.0, lo * 1.04), (1.0, lo * 0.95)], ((1, 1.0), (2, 0.1)), attack=0.2, release=0.4)))
        t += 0.09 + 0.15
    return seq(parts, 0.05)


def ev_sparrow(seed: int) -> np.ndarray:
    """House sparrow: "tschilp" chirps – a fast up-and-down glide (3.2→4.6→3.4 kHz) with strong harmonics and some
    breathiness, three to six at irregular gaps."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for i in range(int(rng.integers(3, 7))):
        dur = rng.uniform(0.06, 0.09)
        f0 = rng.uniform(3000.0, 3500.0)
        note = _note(dur, [(0.0, f0), (0.4, f0 * 1.42), (1.0, f0 * 1.05)], ((1, 1.0), (2, 0.45), (3, 0.2)),
                     attack=0.12, release=0.35)
        breath = vl.noise_burst(rng, dur, 3000.0, 7000.0, dur * 0.4) * 0.08
        parts.append((t, vl.mixc((1.0, note), (1.0, breath))))
        t += dur + rng.uniform(0.12, 0.35)
    return seq(parts, 0.05)


def _harsh(dur: float, f0: float, rng, formants=((1200.0, 4.0, 8.0), (2400.0, 4.0, 6.0)), jitter: float = 0.04,
           noise: float = 0.25) -> np.ndarray:
    """A harsh voiced call (crow, gull, dog): a pulse train with jittered period through formant resonances, plus
    noise."""
    m = int(dur * SR)
    f = np.full(m, f0) * (1.0 + jitter * vl.slow(m, int(rng.integers(1, 1 << 30)), 15.0, 60.0))
    ph = np.cumsum(f) / SR
    saw = 2.0 * (ph - np.floor(ph)) - 1.0
    y = saw + noise * rng.standard_normal(m)

    def shape(fr):
        s = lp(fr, 5000.0, 1) * hp(fr, f0 * 0.6, 2)
        for fc, q, g in formants:
            s = s * peak(fr, fc, q, g)
        return s
    return ffilter(y, shape)


def ev_crow(seed: int) -> np.ndarray:
    """Carrion crow: two or three harsh "kraa" calls (pulse train ~550 Hz, formants 1.2 / 2.4 kHz, noisy), far away."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for i in range(int(rng.integers(2, 4))):
        dur = rng.uniform(0.28, 0.4)
        c = _harsh(dur, rng.uniform(500.0, 620.0), rng) * env_arch(int(dur * SR), 0.12, 0.4)
        parts.append((t, c * db2(rng.normal(0, 1.5))))
        t += dur + rng.uniform(0.25, 0.45)
    return seq(parts, 0.05)


def ev_skylark(seed: int) -> np.ndarray:
    """Skylark high above a field: three seconds of unbroken warbling – short notes of 20–60 ms at 2.5–6.5 kHz with
    quick glides, barely a gap."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    while t < 3.0:
        dur = rng.uniform(0.02, 0.06)
        f0 = rng.uniform(2500.0, 6500.0)
        parts.append((t, _note(dur, [(0.0, f0), (1.0, f0 * rng.uniform(0.8, 1.25))], ((1, 1.0), (2, 0.1)),
                               attack=0.15, release=0.35) * db2(rng.normal(0, 2.5))))
        t += dur + rng.uniform(0.0, 0.02)
    y = seq(parts, 0.05)
    return y * env_arch(len(y), 0.15, 0.2)


def ev_woodpecker(seed: int) -> np.ndarray:
    """Great spotted woodpecker drumming: 16 strikes in 0.6 s, slowing a little and fading; each a resonant knock of
    dry wood (decaying partials 640 / 1150 / 1930 Hz and a click)."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for i in range(16):
        knock = vl.mixc((1.0, vl.decay_sine(640.0, 0.009, 0.04)), (0.6, vl.decay_sine(1150.0, 0.006, 0.03)),
                        (0.35, vl.decay_sine(1930.0, 0.004, 0.02)), (0.5, vl.noise_burst(rng, 0.004, 1500.0, 8000.0, 0.001)))
        parts.append((t, knock * (1.0 - 0.035 * i)))
        t += 0.034 + 0.0012 * i
    return seq(parts, 0.05)


def ev_owl(seed: int, full: bool) -> np.ndarray:
    """Tawny owl: the long "huuu" (~420 Hz, falling a little, breathy); full: after a pause the quavering
    "hu … hu-hu-huuuu" (tremolo 13 Hz)."""
    rng = np.random.default_rng(seed)
    f0 = rng.uniform(400.0, 450.0)
    a = _note(0.8, [(0.0, f0 * 1.02), (0.3, f0 * 1.04), (1.0, f0 * 0.93)], ((1, 1.0), (2, 0.06)), attack=0.25, release=0.5)
    a += vl.noise_burst(rng, 0.8, 300.0, 1200.0, 0.5, attack=0.1) * 0.03
    if not full:
        return a
    b = _note(0.16, [(0.0, f0 * 1.05), (1.0, f0)], ((1, 1.0), (2, 0.05)), attack=0.3, release=0.4)
    m = int(1.25 * SR)
    trem = 0.55 + 0.45 * np.cos(TAU2 * 13.0 * np.arange(m) / SR)
    c = _note(1.25, [(0.0, f0 * 1.06), (0.5, f0 * 1.04), (1.0, f0 * 0.95)], ((1, 1.0), (2, 0.05)), attack=0.1,
              release=0.35) * trem
    return seq([(0.0, a), (1.9, b), (2.45, c)], 0.05)


def ev_dog(seed: int) -> np.ndarray:
    """A dog barking far away (a farm, a village): two or three barks (420→320 Hz, formants 0.9 / 1.8 / 3.2 kHz,
    120 ms)."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for i in range(int(rng.integers(2, 4))):
        dur = rng.uniform(0.1, 0.15)
        m = int(dur * SR)
        b = _harsh(dur, rng.uniform(380.0, 450.0), rng, ((900.0, 3.0, 10.0), (1800.0, 4.0, 6.0), (3200.0, 4.0, 3.0)),
                   0.06, 0.35)
        b *= env_arch(m, 0.08, 0.6) * np.linspace(1.0, 0.8, m)
        parts.append((t, b))
        t += dur + rng.uniform(0.22, 0.4)
    return seq(parts, 0.05)


def ev_gull(seed: int, kind: int) -> np.ndarray:
    """Herring gull: "kyow" calls – a nasal, harmonic-rich voice gliding up and down (900→1500→750 Hz, formants
    1.8 / 3 kHz); kind 0 one call, 1 two, 2 the long call: a drawn-out "aaaow" and a laughing series."""
    rng = np.random.default_rng(seed)

    def kyow(dur: float, f_lo: float, f_hi: float) -> np.ndarray:
        m = int(dur * SR)
        f = contour(m, [(0.0, f_lo), (0.35, f_hi), (1.0, f_lo * 0.82)])
        ph = np.cumsum(f) / SR
        saw = 2.0 * (ph - np.floor(ph)) - 1.0
        y = saw + 0.12 * rng.standard_normal(m)
        y = ffilter(y, lambda fr: lp(fr, 6000.0, 1) * hp(fr, 600.0, 2) * peak(fr, 1800.0, 3.0, 9.0) * peak(fr, 3000.0, 4.0, 6.0))
        return y * env_arch(m, 0.12, 0.45)
    if kind == 0:
        return seq([(0.0, kyow(0.32, 900.0, 1500.0))], 0.05)
    if kind == 1:
        return seq([(0.0, kyow(0.3, 950.0, 1550.0)), (0.42, kyow(0.26, 900.0, 1450.0) * 0.8)], 0.05)
    parts = [(0.0, kyow(0.6, 800.0, 1300.0))]
    t = 0.75
    for i in range(6):
        parts.append((t, kyow(0.14, 1000.0 - 25 * i, 1350.0 - 30 * i) * (0.9 - 0.06 * i)))
        t += 0.19
    return seq(parts, 0.05)


def ev_ship_horn(seed: int) -> np.ndarray:
    """A ship's horn across the harbour: a deep tone (~125 Hz, rich harmonics) for 2.4 s, far away."""
    m = int(3.2 * SR)
    t = np.arange(m) / SR
    f = np.full(m, 124.0) * (1.0 + 0.004 * np.sin(TAU2 * 3.1 * t))
    amp = np.clip(t / 0.35, 0.0, 1.0) * np.clip((2.8 - t) / 0.5, 0.0, 1.0)
    y = tone(f, amp, tuple((k, 1.0 / k ** 0.9) for k in range(1, 30)))
    return ffilter(y, lambda fr: lp(fr, 1600.0, 2) * peak(fr, 380.0, 1.5, 5.0))


def ev_city_horn(seed: int, double: bool) -> np.ndarray:
    """A car horn some streets away: a two-tone disc horn (415 / 510 Hz, buzzy harmonics), once or twice."""
    rng = np.random.default_rng(seed)

    def toot(dur: float) -> np.ndarray:
        m = int(dur * SR)
        amp = env_arch(m, 0.04, 0.12)
        y = np.zeros(m)
        for f0 in (415.0 * rng.uniform(0.98, 1.02), 510.0 * rng.uniform(0.98, 1.02)):
            ph = np.cumsum(np.full(m, f0)) / SR
            sq = np.tanh(3.0 * np.sin(TAU2 * ph))
            y += sq
        return ffilter(y * amp, lambda fr: bp(fr, 300.0, 4000.0, 2) * peak(fr, 2200.0, 2.0, 6.0))
    if double:
        return seq([(0.0, toot(0.16)), (0.26, toot(0.22))], 0.05)
    return seq([(0.0, toot(rng.uniform(0.35, 0.6)))], 0.05)


def ev_pigeon(seed: int) -> np.ndarray:
    """Feral pigeon: a soft "ruu-guu-gu" – breathy low tones (~280–340 Hz) with gliding pitch."""
    rng = np.random.default_rng(seed)
    parts = []
    t = 0.0
    for dur, pts in ((0.36, [(0.0, 300.0), (0.5, 335.0), (1.0, 285.0)]), (0.24, [(0.0, 320.0), (1.0, 300.0)]),
                     (0.42, [(0.0, 310.0), (0.4, 330.0), (1.0, 270.0)])):
        k = rng.uniform(0.95, 1.05)
        note = _note(dur, [(p, f * k) for p, f in pts], ((1, 1.0), (2, 0.25), (3, 0.08)), attack=0.3, release=0.45)
        breath = vl.noise_burst(rng, dur, 200.0, 1500.0, dur * 0.5, attack=0.05) * 0.12
        parts.append((t, vl.mixc((1.0, note), (1.0, breath))))
        t += dur + rng.uniform(0.06, 0.12)
    return seq(parts, 0.05)


def ev_bell(seed: int, prime: float, strikes: int) -> np.ndarray:
    """A church bell (minor-third bell: hum 0.5, prime 1, tierce 1.2, quint 1.5, nominal 2, upper partials 2.5 / 3 /
    4 × the prime, the low ones ringing longest), struck once or twice, heard from some streets away."""
    rng = np.random.default_rng(seed)
    m = int(7.0 * SR)
    t = np.arange(m) / SR
    ring_out = np.clip((7.0 - t) / 2.0, 0.0, 1.0) ** 2        # the buffer ends in silence (no cut-off ringing)
    partials = ((0.5, 0.55, 3.2), (1.0, 0.8, 2.2), (1.2, 0.6, 1.8), (1.5, 0.35, 1.4), (2.0, 0.7, 1.2), (2.5, 0.25, 0.7),
                (3.0, 0.2, 0.55), (4.0, 0.12, 0.35))
    strike = np.zeros(m)
    for ratio, g, tau in partials:
        f = prime * ratio * rng.uniform(0.997, 1.003)
        beat = 1.0 + 0.04 * np.sin(TAU2 * rng.uniform(0.3, 1.2) * t)
        strike += g * np.sin(TAU2 * f * t + rng.uniform(0, 6.28)) * np.exp(-t / tau) * beat * ring_out
    strike += np.concatenate([vl.noise_burst(rng, 0.008, 1500.0, 6000.0, 0.002), np.zeros(m - int(0.008 * SR))])[:m] * 0.3
    if strikes == 1:
        return strike
    second = np.zeros(m)
    prime2 = prime * 0.84
    for ratio, g, tau in partials:
        second += g * np.sin(TAU2 * prime2 * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t / tau) * ring_out
    return seq([(0.0, strike), (1.6, second * 0.9)], 0.0)


def ev_scooter(seed: int) -> np.ndarray:
    """A two-stroke scooter passing in a street nearby: a buzzing engine (firing ~110–135 Hz, rich harmonics) rising
    and falling in pitch (Doppler) and level over three seconds."""
    rng = np.random.default_rng(seed)
    m = int(3.2 * SR)
    t = np.arange(m) / SR
    u = (t - 1.5) / 1.1
    f = 122.0 * (1.0 + 0.06 * np.tanh(-u * 1.8)) * (1.0 + 0.01 * np.sin(TAU2 * 6.0 * t))
    ph = np.cumsum(f) / SR
    pulse = (0.5 + 0.5 * np.cos(TAU2 * ph)) ** 6
    y = pulse - np.mean(pulse) + 0.3 * vl.pnoise(m, int(rng.integers(1, 1 << 30)), lambda fr: bp(fr, 600.0, 5000.0, 1)) * pulse
    amp = 1.0 / (1.0 + u * u)
    y = y * amp
    return ffilter(y, lambda fr: bp(fr, 90.0, 4500.0, 1) * peak(fr, 900.0, 1.2, 5.0))


# id, category, space, metres, [variant makers], note
EVENTS = [
    ("bird_blackbird", "bird", "open", 30.0, [lambda: ev_blackbird(2101), lambda: ev_blackbird(2102), lambda: ev_blackbird(2103)],
     "Amsel: Flötenstrophe mit gleitenden Tönen und quietschendem Schluss"),
    ("bird_chaffinch", "bird", "open", 25.0, [lambda: ev_chaffinch(2201), lambda: ev_chaffinch(2202)],
     "Buchfink: schneller, absteigender Triller mit Schnörkel am Ende"),
    ("bird_tit", "bird", "open", 20.0, [lambda: ev_great_tit(2301), lambda: ev_great_tit(2302)],
     "Kohlmeise: „zi-zi-bä“, drei- bis viermal"),
    ("bird_sparrow", "sparrow", "street", 12.0, [lambda: ev_sparrow(2401), lambda: ev_sparrow(2402)],
     "Haussperling: „tschilp“-Rufe in unregelmäßigem Abstand"),
    ("bird_crow", "crow", "open", 80.0, [lambda: ev_crow(2501), lambda: ev_crow(2502)],
     "Rabenkrähe: zwei bis drei raue „kraa“ in der Ferne"),
    ("bird_skylark", "skylark", "open", 60.0, [lambda: ev_skylark(2601)],
     "Feldlerche hoch über dem Feld: ununterbrochenes Trillern"),
    ("bird_woodpecker", "woodpecker", "forest", 40.0, [lambda: ev_woodpecker(2701)],
     "Buntspecht: Trommelwirbel aus 16 Schlägen"),
    ("owl", "owl", "forest", 70.0, [lambda: ev_owl(2801, False), lambda: ev_owl(2802, True)],
     "Waldkauz: langes „huuu“; tremolierendes „hu … hu-hu-huuuu“"),
    ("dog", "dog", "far", 250.0, [lambda: ev_dog(2901), lambda: ev_dog(2902)],
     "Hund in der Ferne (Hof, Dorf): zwei bis drei Beller"),
    ("gull", "gull", "open", 40.0, [lambda: ev_gull(3001, 0), lambda: ev_gull(3002, 1), lambda: ev_gull(3003, 2)],
     "Silbermöwe: einzelnes und doppeltes „kjau“, langer Ruf mit Lachreihe"),
    ("ship_horn", "ship", "far", 900.0, [lambda: ev_ship_horn(3101)],
     "Schiffshorn über den Hafen: tiefer Ton, weit weg"),
    ("city_horn", "horn", "street", 120.0, [lambda: ev_city_horn(3201, False), lambda: ev_city_horn(3202, True)],
     "Hupe einige Straßen weiter: Zweiklang-Hupe, einmal oder zweimal"),
    ("pigeon", "pigeon", "street", 10.0, [lambda: ev_pigeon(3301), lambda: ev_pigeon(3302)],
     "Stadttaube: weiches „ruu-guu-gu“"),
    ("church_bell", "bell", "street", 300.0, [lambda: ev_bell(3401, 330.0, 1), lambda: ev_bell(3402, 392.0, 2)],
     "Kirchenglocke einige Straßen weiter: ein Schlag; zwei Glocken nacheinander"),
    ("scooter", "scooter", "street", 25.0, [lambda: ev_scooter(3501)],
     "Motorroller fährt in einer Nachbarstraße vorbei (Zweitakter, Doppler)"),
]

SPACES = {"open": ir_open, "forest": ir_forest, "street": ir_street, "far": ir_far}


# ------------------------------------------------------------------------------------------------------------------
# build
# ------------------------------------------------------------------------------------------------------------------

def _entry_files(e: dict) -> list[str]:
    return list(e.get("files") or ([e["file"]] if "file" in e else []))


def render_bed(seconds: float, fn) -> np.ndarray:
    n = int(round(seconds * SR))
    y = np.asarray(fn(n), np.float64)
    if y.shape != (n, 2):
        raise ValueError(f"{fn.__name__}: Form {y.shape}")
    y = y - np.mean(y, axis=0)
    y = y * (PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y, -3.0)


def render_event(variant, space: str, metres: float, seed: int) -> np.ndarray:
    y = np.asarray(variant(), np.float64)
    y = distant(y, metres, SPACES[space](seed))
    y = finish_event(y)
    y = y * (PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y[:, None], -3.0)[:, 0]


def build(out: str | None, wav_dir: str | None, log=print, only: list[str] | None = None) -> None:
    man = ml.Manifest(FOLDER, out)
    before = {f for e in man.sounds.values() if e.get("generator") == GENERATOR for f in _entry_files(e)}
    if only is None:
        man.drop_generator(GENERATOR)
    repo = out is None
    total = 0
    written: set[str] = set()
    for sid, seconds, fn, note in BEDS:
        if only is not None and sid not in only:
            written.update(_entry_files(man.sounds.get(sid, {})))
            continue
        y = render_bed(seconds, fn)
        n = len(y)
        name = sid + ".ogg"
        q = BED_Q[0]
        for q in BED_Q:
            ml.write_ogg(man.file(name), y, quality=q)
            played = qc_lib.read_audio(man.file(name))[0]
            seam = qc_lib.loop_seam(played, 0, len(played), 0.1, SR)
            if max(seam["ratio"], seam["kink_ratio"]) <= 2.0 or max(seam["loop_ratio"], seam["loop_kink_ratio"]) <= 1.0:
                break
        if len(played) != n:
            raise ValueError(f"{sid}: Vorbis liefert {len(played)} statt {n} Frames")
        if repo:
            ml.write_ogg_import(man.file(name), 0.0)
        e = man.add(sid, name, "loop", GENERATOR, loop=(0, n), bus="MAmb", gain_db=0.0, note=note)
        e["bed"] = sid
        e["vorbis_q"] = q
        written.add(name)
        total += os.path.getsize(man.file(name))
        if wav_dir:
            os.makedirs(wav_dir, exist_ok=True)
            reps = int(math.ceil(20.0 * SR / n))
            ml.write_wav16(os.path.join(wav_dir, sid + ".wav"), np.tile(played, (reps, 1))[:int(20.0 * SR)])
        log(f"  {sid:16s} {n / SR:5.2f} s  {e['lufs']:6.1f} LUFS  {e['true_peak_db']:5.1f} dBTP  q{q:g}  "
            f"{os.path.getsize(man.file(name)) / 1e3:6.1f} kB")
    for k, (sid, cat, space, metres, makers, note) in enumerate(EVENTS):
        if only is not None and sid not in only:
            written.update(_entry_files(man.sounds.get(sid, {})))
            continue
        names = []
        lufs_m = []
        for v, mk in enumerate(makers):
            y = render_event(mk, space, metres, 5000 + 31 * k + v)
            name = f"{sid}_{chr(97 + v)}.ogg" if len(makers) > 1 else sid + ".ogg"
            ml.write_ogg(man.file(name), y, quality=EVENT_Q)
            if repo:
                _write_oneshot_import(man.file(name))
            played = qc_lib.read_audio(man.file(name))[0]
            lufs_m.append(round(float(qc_lib.momentary_max(played, SR)), 2))
            names.append(name)
            written.add(name)
            total += os.path.getsize(man.file(name))
            if wav_dir:
                os.makedirs(wav_dir, exist_ok=True)
                ml.write_wav16(os.path.join(wav_dir, name.replace(".ogg", ".wav")), played)
        e = man.add(sid, names if len(names) > 1 else names[0], "oneshot", GENERATOR, bus="MAmb", gain_db=0.0, note=note)
        e["category"] = cat
        e["lufs_m"] = lufs_m
        e["vorbis_q"] = EVENT_Q
        log(f"  {sid:16s} {len(names)} ×  momentan {np.mean(lufs_m):6.1f} LUFS  {cat}")
    man.save()
    if repo:
        for name in sorted(before - written):
            for p in (man.file(name), man.file(name) + ".import"):
                if os.path.exists(p):
                    os.remove(p)
                    log(f"  entfernt: {os.path.basename(p)}")
    log(f"ambience_synth: {len(BEDS)} Betten, {sum(len(e[4]) for e in EVENTS)} Ereignis-Varianten, "
        f"{total / 1e6:.2f} MB -> {man.dir}")


def _write_oneshot_import(path: str) -> None:
    """Import settings of an Ogg one-shot (no loop); modern_lib keeps the [remap]/[deps] head of an existing file."""
    ml.write_ogg_import(path, None)


def main() -> int:
    ap = argparse.ArgumentParser(description="Ambiente der Umgebung (Profil Modern, AU-C2)")
    ap.add_argument("--out", default=None, help="Ordner statt des Repositorys (ohne Import-Dateien)")
    ap.add_argument("--wav", default=None, help="zusätzlich eine Hörprobe je Klang in diesen Ordner")
    ap.add_argument("--only", default=None, help="nur diese Klänge (Kommaliste), die übrigen Einträge bleiben")
    args = ap.parse_args()
    only = [s.strip() for s in args.only.split(",")] if args.only else None
    build(args.out, args.wav, print if not args.out else (lambda *_a: None), only)
    return 0


if __name__ == "__main__":
    sys.exit(main())
