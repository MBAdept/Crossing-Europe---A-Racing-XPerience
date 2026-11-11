#!/usr/bin/env python3
"""Natively mixed loops of the player's car on the road – profile "Modern", package AU-C1 (contract D27–D29, §4.7.3;
docs/audio-modern.md "Fahrbahn, Wind, Aufprall"). Writes into assets/audio/modern/vehicle/ (16-bit WAV, 44.1 kHz,
mono; the runtime plays a loop on two panned players – left and right wheels, read at different offsets – so a
mono file gives a wide, decorrelated pair) and registers them in the folder's manifest next to the engine layers of
AU-B (modern_lib.Manifest: only this generator's own entries are replaced).

    python3 tools/audio/modern/vehicle_loops.py               into the repository (with Godot import files)
    python3 tools/audio/modern/vehicle_loops.py --out /tmp/x  into /tmp/x/assets/audio/modern/vehicle (QC determinism)
    python3 tools/audio/modern/vehicle_loops.py --wav /tmp/p  also a preview WAV of every loop (8 s, at ref speed)

Every loop is seamless by construction: noise is periodic (random phases on an FFT grid of the loop length),
events are placed circularly, modulations are periodic, tones have whole numbers of cycles. Behind loop_end follow
LOOP_GUARD frames of the loop's start (Godot reads the frame at the loop end before it wraps – docs "Fallen" 13).

Manifest entries carry, besides the measured values of modern_lib:
    ref_kmh     the road speed the loop is designed for (played at pitch 1)
    pitch_exp   the runtime plays it at pitch (v / ref_kmh) ** pitch_exp
    lufs_pitch  [[pitch, LUFS], …] – the integrated loudness of the loop played at that pitch (the K weighting
                changes with the shifted spectrum); the runtime interpolates it so its level laws hold for the
                loudness the player hears, not for the file at pitch 1
The levels themselves are data (config audio.modern.road): the files carry no level decision (gain_db 0).
Deterministic (fixed seeds, no time stamps): audio_qc.py --determinism runs this twice and compares the bytes.
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

GENERATOR = "tools/audio/modern/vehicle_loops.py"
FOLDER = "vehicle"
SR = ml.SR
LOOP_GUARD = 16                  # frames of continuation behind the loop end (the loop's first frames once more)
PEAK = 0.708                     # every file at -3 dBFS sample peak (the runtime sets the level from the loudness)
PITCHES = [0.2, 0.28, 0.4, 0.56, 0.71, 0.84, 1.0, 1.19, 1.41, 1.68, 2.0, 2.38, 2.83, 3.36]
MEASURE_S = 4.0                  # length of the resampled signal measured per pitch


# ------------------------------------------------------------------------------------------------------------------
# DSP helpers (shared with sfx_modern.py)
# ------------------------------------------------------------------------------------------------------------------

def bp(f, lo, hi, order=2):
    """Band-pass magnitude (Butterworth-like skirts of the given order)."""
    return (1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order))) * (1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order)))


def lp(f, hi, order=2):
    return 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))


def hp(f, lo, order=2):
    return 1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order))


def peak(f, f0, q, gain_db):
    """Resonant bump of gain_db at f0 (1 far away from it)."""
    g = 10.0 ** (gain_db / 20.0)
    x = (f / f0 - f0 / f) * q
    return 1.0 + (g - 1.0) / (1.0 + x * x)


def rms(x) -> float:
    return math.sqrt(float(np.mean(np.asarray(x, np.float64) ** 2))) + 1e-12


def pnoise(n: int, seed: int, shape) -> np.ndarray:
    """Periodic noise of n samples (repeats exactly) with magnitude shape(f), unit RMS."""
    y = ml.periodic_noise(n, SR, seed, shape)
    return y / rms(y)


def cfilter(x: np.ndarray, shape) -> np.ndarray:
    """Circular (periodic) filtering in the frequency domain: a loop stays a loop."""
    n = len(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    return np.fft.irfft(np.fft.rfft(x) * shape(f), n)


def slow(n: int, seed: int, lo: float, hi: float) -> np.ndarray:
    """Periodic slow modulation with unit standard deviation (band lo..hi Hz, pink-ish)."""
    y = ml.periodic_noise(n, SR, seed, lambda f: bp(f, lo, hi, 1) / np.sqrt(f))
    y = y - float(np.mean(y))
    return y / (float(np.std(y)) + 1e-12)


def place(out: np.ndarray, clip: np.ndarray, at: int, gain: float = 1.0, circular: bool = True) -> None:
    """Adds a clip at sample `at` – wrapping around the end of a loop (circular) or cut at the end."""
    n = len(out)
    m = len(clip)
    if circular:
        idx = (at + np.arange(m)) % n
        np.add.at(out, idx, gain * clip)
    else:
        if at >= n or at + m <= 0:
            return
        a = max(at, 0)
        c = clip[a - at:]
        k = min(len(c), n - a)
        out[a:a + k] += gain * c[:k]


def decay_sine(f0: float, tau: float, dur: float, phase: float = 0.0, f_end: float | None = None, attack: float = 0.0005) -> np.ndarray:
    """A decaying (gliding) sine – a resonance struck once."""
    m = max(int(dur * SR), 2)
    t = np.arange(m) / SR
    f = f0 if f_end is None else f_end + (f0 - f_end) * np.exp(-t / max(dur * 0.3, 1e-4))
    ph = 2.0 * np.pi * np.cumsum(np.full(m, f) if np.isscalar(f) else f) / SR + phase
    return np.sin(ph) * np.exp(-t / tau) * (1.0 - np.exp(-t / attack))


def noise_burst(rng, dur: float, lo: float, hi: float, tau: float, attack: float = 0.0003, order: int = 2) -> np.ndarray:
    """A short band-limited noise burst with an exponential decay."""
    m = max(int(dur * SR), 8)
    t = np.arange(m) / SR
    nz = rng.standard_normal(m)
    ff = np.maximum(np.fft.rfftfreq(m, 1.0 / SR), 1.0)
    nz = np.fft.irfft(np.fft.rfft(nz) * bp(ff, lo, hi, order), m)
    nz /= rms(nz)
    return nz * np.exp(-t / tau) * (1.0 - np.exp(-t / attack))


def mixc(*parts) -> np.ndarray:
    """Sum of clips of different lengths: mixc((gain, clip), (gain, clip), …) – each starts at sample 0."""
    m = max(len(c) for _g, c in parts)
    out = np.zeros(m)
    for g, c in parts:
        out[:len(c)] += g * np.asarray(c, np.float64)
    return out


def fade_tail(y: np.ndarray, seconds: float = 0.03) -> np.ndarray:
    k = min(int(seconds * SR), len(y))
    if k > 1:
        y = y.copy()
        y[-k:] *= np.linspace(1.0, 0.0, k) ** 2
    return y


def lufs_at_pitch(y: np.ndarray, pitch: float) -> float:
    """Integrated loudness of loop y played at pitch (linear interpolation, as a resampler reads it)."""
    n = len(y)
    m = int(MEASURE_S * SR)
    pos = (np.arange(m) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    x = y[i] * (1.0 - fr) + y[(i + 1) % n] * fr
    return round(float(qc_lib.integrated_lufs(x, SR)), 2)


def write_wav_import_keep(path: str, loop) -> None:
    """modern_lib.write_wav_import() that keeps the [remap]/[deps] head of an existing .import file (uid and import
    path): modern_lib opens the file for writing before it reads the old head, which empties it (docs/audio-modern.md
    "Offene Punkte"; the same work-around as engine_synth3.py)."""
    imp = path + ".import"
    head = ""
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].strip("\n")
    ml.write_wav_import(path, loop)
    if head:
        with open(imp, encoding="utf-8") as fh:
            params = fh.read().split("[params]", 1)[1]
        with open(imp, "w", encoding="utf-8") as fh:
            fh.write(head + "\n\n[params]" + params)


# ------------------------------------------------------------------------------------------------------------------
# The loops
# ------------------------------------------------------------------------------------------------------------------

def tyre_asphalt(n: int) -> np.ndarray:
    """Dry asphalt: tread impacts and air pumping (a broad hump around 0.9 kHz), the tyre cavity resonance (218 Hz,
    narrow), structure-borne rumble of the macrotexture (30-110 Hz), a little hiss."""
    y = pnoise(n, 1101, lambda f: hp(f, 300.0, 1) * lp(f, 1300.0, 2) * peak(f, 218.0, 9.0, 7.0) * peak(f, 950.0, 1.3, 3.0)
               + 0.5 * bp(f, 30.0, 110.0, 2) + 0.035 * bp(f, 2500.0, 6000.0, 2))
    return y * (1.0 + 0.10 * slow(n, 1102, 0.5, 3.0))


def tyre_concrete(n: int) -> np.ndarray:
    """Brushed concrete: rougher and brighter than asphalt (up to 2.3 kHz), the faint whine of the transverse
    tining (1.15 kHz, narrow), more rumble."""
    y = pnoise(n, 1201, lambda f: hp(f, 350.0, 1) * lp(f, 2000.0, 2) * peak(f, 232.0, 7.0, 6.0) * peak(f, 1250.0, 1.6, 4.0)
               * peak(f, 1150.0, 30.0, 6.0) + 0.6 * bp(f, 28.0, 120.0, 2) + 0.07 * bp(f, 2600.0, 6500.0, 2))
    return y * (1.0 + 0.14 * slow(n, 1202, 0.5, 4.0))


def tyre_deck(n: int) -> np.ndarray:
    """Orthotropic steel deck under asphalt: the rolling noise with the hollow drone of the deck plates (68 and 104
    Hz) and faint metallic partials of the stiffeners."""
    def shape(f):
        rolling = 0.8 * hp(f, 300.0, 1) * lp(f, 1250.0, 2) * peak(f, 215.0, 9.0, 6.0) * peak(f, 900.0, 1.3, 2.0)
        drone = 0.95 * bp(f, 40.0, 170.0, 2) * peak(f, 68.0, 6.0, 10.0) * peak(f, 104.0, 8.0, 7.0)
        metal = 0.06 * ((peak(f, 410.0, 40.0, 14.0) - 1.0) + (peak(f, 655.0, 40.0, 14.0) - 1.0)
                        + (peak(f, 1180.0, 50.0, 14.0) - 1.0))
        return rolling + drone + metal
    y = pnoise(n, 1301, shape)
    return y * (1.0 + 0.16 * slow(n, 1302, 0.5, 2.5))


def tyre_cobbles(n: int, ref_kmh: float) -> np.ndarray:
    """Setts (about 11.5 cm long) at ref_kmh: four wheels strike the sett edges ~120 times a second each, a little
    out of step; every strike a short thud (tyre and sett, 180-260 Hz) with a click, the suspension and body answer
    below 90 Hz, now and then a rattle inside the car."""
    rng = np.random.default_rng(1401)
    v = ref_kmh / 3.6
    rate = v / 0.115
    out = np.zeros(n)
    hits = np.zeros(n)
    for wheel in range(4):
        gain = (1.0, 0.95, 0.8, 0.75)[wheel]
        count = int(round(rate * n / SR))
        base = rng.uniform(0.0, n / count)
        for k in range(count):
            t = base + k * n / count + rng.uniform(-0.2, 0.2) * n / count
            at = int(t) % n
            a = gain * float(np.exp(rng.normal(0.0, 0.38)))
            f0 = rng.uniform(180.0, 260.0)
            clip = mixc((1.0, decay_sine(f0, 0.0035, 0.02, rng.uniform(0, 6.28))), (0.3, noise_burst(rng, 0.006, 900.0, 3200.0, 0.0008)))
            place(out, clip, at, a)
            hits[at] += a
            if rng.random() < 0.06:
                place(out, noise_burst(rng, 0.03, 2800.0, 6000.0, 0.006), at, 0.25 * a)
    body = cfilter(hits, lambda f: bp(f, 25.0, 90.0, 2) * peak(f, 48.0, 3.0, 6.0))
    out /= rms(out)
    body /= rms(body)
    return out + 0.55 * body


def tyre_gravel(n: int) -> np.ndarray:
    """The gravel shoulder: dense crunch of stones crushed and pushed aside under the tyres, an uneven low rumble,
    stones flung against the wheel arches (short metallic pings)."""
    rng = np.random.default_rng(1501)
    m = int(rng.poisson(2600 * n / SR))
    train = np.zeros(n)
    amp = np.clip(rng.lognormal(0.0, 0.5, m), 0.0, 3.5)
    np.add.at(train, rng.integers(0, n, m), amp * rng.choice([-1.0, 1.0], m))
    crunch = cfilter(train, lambda f: bp(f, 1100.0, 7500.0, 2) * peak(f, 2800.0, 1.4, 3.0) + 0.25 * bp(f, 300.0, 1100.0, 1))
    crunch /= rms(crunch)
    crunch = 3.5 * np.tanh(crunch / 3.5)          # a few grains far above the rest would set the peak of the file
    rumble = pnoise(n, 1502, lambda f: bp(f, 20.0, 95.0, 2)) * (1.0 + 0.45 * slow(n, 1503, 1.0, 6.0))
    pings = np.zeros(n)
    for _ in range(int(9 * n / SR)):
        f0 = rng.uniform(2100.0, 5600.0)
        clip = mixc((1.0, decay_sine(f0, rng.uniform(0.005, 0.014), 0.06, rng.uniform(0, 6.28))),
                    (0.5, decay_sine(f0 * rng.uniform(1.37, 1.62), 0.006, 0.05)))
        place(pings, clip, int(rng.integers(0, n)), rng.uniform(0.6, 1.6))
    pings /= rms(pings) + 1e-12
    return crunch + 0.5 * rumble + 0.22 * pings


def tyre_grass(n: int) -> np.ndarray:
    """Off the road at the open limit: a soft swish of grass, the car thumping over uneven ground (low thuds a few
    times a second) and a heavy low rumble."""
    rng = np.random.default_rng(1601)
    swish = pnoise(n, 1602, lambda f: bp(f, 250.0, 3500.0, 1) / np.sqrt(f / 500.0)) * (1.0 + 0.4 * slow(n, 1603, 1.0, 6.0))
    thumps = np.zeros(n)
    for _ in range(int(5.5 * n / SR)):
        clip = mixc((1.0, decay_sine(rng.uniform(32.0, 58.0), rng.uniform(0.05, 0.09), 0.35, 0.0, rng.uniform(26.0, 40.0), 0.004)),
                    (0.2, noise_burst(rng, 0.08, 150.0, 900.0, 0.02)))
        place(thumps, clip, int(rng.integers(0, n)), rng.uniform(0.5, 1.4))
    thumps /= rms(thumps)
    rumble = pnoise(n, 1604, lambda f: bp(f, 16.0, 75.0, 2))
    return 0.55 * swish + thumps + 0.6 * rumble


def tyre_wet(n: int) -> np.ndarray:
    """A wet road: spray hiss of the water pressed out of the tread (1-10 kHz), a fine sizzle, water sloshing in
    the wheel arches (150-900 Hz, moving)."""
    rng = np.random.default_rng(1701)
    hiss = pnoise(n, 1702, lambda f: hp(f, 900.0, 1) * lp(f, 7000.0, 2) * peak(f, 3200.0, 0.8, 4.0))
    m = int(rng.poisson(6000 * n / SR))
    train = np.zeros(n)
    np.add.at(train, rng.integers(0, n, m), rng.standard_normal(m))
    sizzle = cfilter(train, lambda f: bp(f, 4000.0, 9000.0, 2))
    sizzle /= rms(sizzle)
    slosh = pnoise(n, 1703, lambda f: hp(f, 150.0, 1) * lp(f, 900.0, 2)) * (1.0 + 0.6 * slow(n, 1704, 0.5, 4.0))
    return hiss + 0.25 * sizzle + 0.5 * slosh


def tyre_rumble(n: int, rate_hz: float) -> np.ndarray:
    """Profiled edge line / rumble strip: the tyres drum over the raised marks rate_hz times a second (at pitch 1),
    a little irregular (agglomerate dots); every bump a short thunk through the body (140 and 420 Hz)."""
    rng = np.random.default_rng(1801)
    count = int(round(rate_hz * n / SR))
    per = n / count
    out = np.zeros(n)
    bump = np.sin(np.pi * np.arange(int(0.0016 * SR)) / int(0.0016 * SR))
    kern = np.zeros(int(0.03 * SR))
    kern[:len(bump)] += bump
    kern += 0.9 * decay_sine(140.0, 0.008, 0.03) + 0.45 * decay_sine(420.0, 0.004, 0.03)
    for k in range(count):
        at = int(k * per + rng.uniform(-0.08, 0.08) * per) % n
        place(out, kern, at, float(np.clip(1.0 + 0.22 * rng.standard_normal(), 0.4, 1.6)))
    out /= rms(out)
    return out + 0.15 * pnoise(n, 1802, lambda f: bp(f, 100.0, 1500.0, 1))


def slab_loop(ref_kmh: float, seed: int, slabs: int = 8, slab_m: float = 5.0, wheelbase_m: float = 2.7) -> np.ndarray:
    """Concrete slabs: at ref_kmh the front and then the rear axle strike the sealed joint every slab_m – the
    classic 'ta-tock' of an old concrete motorway. The ratio of the gaps (wheelbase / slab) does not depend on the
    speed, so the runtime plays the loop at pitch v / ref and the rhythm is exact at every speed."""
    rng = np.random.default_rng(seed)
    v = ref_kmh / 3.6
    per = slab_m / v
    n = int(round(slabs * per * SR))
    out = np.zeros(n)
    sharp = 90.0 / ref_kmh            # a faster car strikes the edge harder and shorter
    for k in range(slabs):
        a = 10.0 ** (rng.normal(0.0, 2.2) / 20.0)
        for axle, (dt, g) in enumerate(((0.0, 1.0), (wheelbase_m / v, 0.85))):
            thump = decay_sine(rng.uniform(74.0, 84.0), 0.035 * sharp ** 0.5, 0.18, 0.0, rng.uniform(52.0, 60.0), 0.0015)
            tack = noise_burst(rng, 0.02, 500.0, 2600.0, 0.0025 * sharp ** 0.5)
            slap = decay_sine(rng.uniform(280.0, 330.0), 0.010, 0.05)
            clip = mixc((1.0, thump), (1.0, tack), (0.5, slap))
            place(out, clip, int(round((k * per + dt) * SR)) % n, a * g)
    return out


def squeal(n: int, f0: float) -> np.ndarray:
    """Tyre squeal (stick-slip of the tread at the limit of grip): a tone with harmonics whose pitch wavers slowly
    and jitters fast, a fluttering amplitude, and the friction noise under it. f0 * loop length must be a whole
    number (the phase closes)."""
    fm_s = slow(n, 1901, 0.5, 4.0)
    fm_f = slow(n, 1902, 15.0, 60.0)
    inst = f0 * (1.0 + 0.03 * fm_s + 0.012 * fm_f)
    ph = 2.0 * np.pi * np.cumsum(inst) / SR
    tone = np.sin(ph) + 0.35 * np.sin(2.0 * ph + 0.5) + 0.12 * np.sin(3.0 * ph + 1.3)
    am = np.clip(0.65 + 0.35 * slow(n, 1903, 3.0, 14.0), 0.2, 1.4)
    fric = pnoise(n, 1904, lambda f: bp(f, 700.0, 3500.0, 2))
    return tone / rms(tone) * am + 0.3 * fric


def scrub(n: int) -> np.ndarray:
    """Rubber scrubbing sideways without the tone (little slip, wet road, the slide of a crash): broadband rubbing
    with a grainy stick-slip pulse."""
    rng = np.random.default_rng(2001)
    base = pnoise(n, 2002, lambda f: hp(f, 300.0, 1) * lp(f, 3500.0, 2) * peak(f, 1100.0, 1.0, 3.0))
    m = int(rng.poisson(70 * n / SR))
    train = np.zeros(n)
    np.add.at(train, rng.integers(0, n, m), rng.uniform(0.3, 1.0, m))
    env = cfilter(train, lambda f: lp(f, 60.0, 2))
    env = np.maximum(env, 0.0)
    env = 0.45 + env / (float(np.max(env)) + 1e-12)
    return base * env


def wind_low(n: int) -> np.ndarray:
    """Wind, low band: the roar of the air around the body (22-190 Hz, falling)."""
    return pnoise(n, 2101, lambda f: bp(f, 22.0, 190.0, 2) / np.sqrt(f / 50.0) + 0.15 * bp(f, 190.0, 450.0, 1))


def wind_mid(n: int) -> np.ndarray:
    """Wind, middle band: the whoosh (240 Hz - 1.9 kHz)."""
    return pnoise(n, 2201, lambda f: hp(f, 240.0, 1) * lp(f, 1800.0, 2) * peak(f, 650.0, 0.9, 2.0))


def wind_high(n: int) -> np.ndarray:
    """Wind, high band: hiss of the turbulence at mirrors and pillars (2.3-8.5 kHz) with a faint seal whistle."""
    y = pnoise(n, 2301, lambda f: bp(f, 2300.0, 8500.0, 2) * peak(f, 4200.0, 0.8, 2.0))
    whistle = pnoise(n, 2302, lambda f: (peak(f, 3150.0, 60.0, 20.0) - 1.0))
    return y + 0.18 * whistle * (1.0 + 0.5 * slow(n, 2303, 0.3, 2.0))


def wind_buffet(n: int) -> np.ndarray:
    """The 'open window' feeling near top speed: low buffeting (30-120 Hz) pulsing 4-9 times a second."""
    y = pnoise(n, 2401, lambda f: bp(f, 28.0, 120.0, 2) * peak(f, 55.0, 2.0, 4.0))
    am = np.clip(1.0 + 0.85 * slow(n, 2402, 4.0, 9.0), 0.08, 2.5)
    return y * am


def rail_scrape(n: int) -> np.ndarray:
    """Body sheet metal grinding along the guardrail: broadband grinding in grains, the ringing modes of the W-beam,
    sparks (sparse sharp clicks), the low drone of the body."""
    rng = np.random.default_rng(2501)
    grind = pnoise(n, 2502, lambda f: bp(f, 500.0, 9000.0, 1))
    m = int(rng.poisson(420 * n / SR))
    train = np.zeros(n)
    np.add.at(train, rng.integers(0, n, m), rng.uniform(0.2, 1.0, m))
    env = np.maximum(cfilter(train, lambda f: lp(f, 400.0, 2)), 0.0)
    grind = grind * (0.35 + env / (float(np.max(env)) + 1e-12))
    def modes(f):
        s = np.zeros_like(f)
        for f0, q in ((210.0, 35.0), (455.0, 40.0), (790.0, 45.0), (1340.0, 50.0), (2150.0, 55.0), (3400.0, 60.0)):
            s += peak(f, f0, q, 24.0) - 1.0
        return s
    ring = pnoise(n, 2503, modes)
    m2 = int(rng.poisson(90 * n / SR))
    sparks = np.zeros(n)
    for at in rng.integers(0, n, m2):
        place(sparks, noise_burst(rng, 0.004, 4000.0, 11000.0, 0.0004, 0.00005), int(at), rng.uniform(0.3, 1.0))
    sparks /= rms(sparks) + 1e-12
    body = pnoise(n, 2504, lambda f: bp(f, 35.0, 130.0, 2))
    y = grind / rms(grind) + 0.6 * ring + 0.3 * sparks + 0.45 * body
    # soft-limit the sparks' peaks (crest 15.6 → about 11 dB): at speed the loop is loud, and single clicks far above
    # the grinding would drive the master limiter (measured in the worst case)
    r = rms(y)
    return 3.2 * r * np.tanh(y / (3.2 * r))


# id, seconds, function, bus, ref_kmh, pitch_exp, note
def loops() -> list[tuple]:
    return [
        ("tyre_asphalt", 2.0, lambda n: tyre_asphalt(n), "MRoad", 120.0, 0.35,
         "Rollgeräusch Asphalt trocken: Profil und Luftpumpen (Buckel um 0,9 kHz), Reifenhohlraum 218 Hz, Grollen der Textur"),
        ("tyre_concrete", 2.0, lambda n: tyre_concrete(n), "MRoad", 120.0, 0.35,
         "Rollgeräusch Beton: rauer und heller, leises Singen der Querrillen (1,15 kHz)"),
        ("tyre_deck", 2.0, lambda n: tyre_deck(n), "MRoad", 120.0, 0.35,
         "Rollgeräusch auf dem Stahldeck einer Brücke: hohles Dröhnen der Deckbleche (68/104 Hz), Metallpartiale"),
        ("tyre_cobbles", 2.5, lambda n: tyre_cobbles(n, 50.0), "MRoad", 50.0, 0.9,
         "Kopfsteinpflaster bei 50 km/h: vier Räder schlagen etwa 120-mal je Sekunde auf Steinkanten, Karosserie darunter"),
        ("tyre_gravel", 2.5, lambda n: tyre_gravel(n), "MRoad", 80.0, 0.55,
         "Bankett (Schotter): Knirschen, unebenes Grollen, Steine gegen die Radhäuser"),
        ("tyre_grass", 2.5, lambda n: tyre_grass(n), "MRoad", 60.0, 0.4,
         "Gras jenseits des Banketts: Rauschen, dumpfe Schläge über unebenen Boden"),
        ("tyre_wet", 2.0, lambda n: tyre_wet(n), "MRoad", 120.0, 0.3,
         "Nasse Fahrbahn: Sprühzischen, feines Brutzeln, Wasser in den Radhäusern"),
        ("tyre_rumble", 1.0, lambda n: tyre_rumble(n, 100.0), "MRoad", 108.0, 1.0,
         "Profilierte Randlinie / Rüttelstreifen: 100 Schläge je Sekunde bei Tonhöhe 1 (Abstand 30 cm bei 108 km/h)"),
        ("slab_slow", None, lambda n: slab_loop(90.0, 2601), "MRoad", 90.0, 1.0,
         "Betonplatten 5 m, Achsabstand 2,7 m: Vorder- und Hinterachse über die Fuge, entworfen bei 90 km/h"),
        ("slab_fast", None, lambda n: slab_loop(180.0, 2701), "MRoad", 180.0, 1.0,
         "Betonplatten 5 m, Achsabstand 2,7 m, entworfen bei 180 km/h (härterer, kürzerer Schlag)"),
        ("squeal", 2.0, lambda n: squeal(n, 820.0), "MRoad", 0.0, 0.0,
         "Reifenquietschen an der Haftgrenze: Ton 820 Hz mit Obertönen, schwankend und flatternd, Reibrauschen"),
        ("scrub", 1.5, lambda n: scrub(n), "MRoad", 0.0, 0.0,
         "Radieren ohne Ton: wenig Schlupf, nasse Fahrbahn, Rutschen beim Unfall"),
        ("wind_low", 2.0, lambda n: wind_low(n), "MWind", 160.0, 0.3, "Wind, tiefes Band: Brausen um die Karosserie"),
        ("wind_mid", 2.0, lambda n: wind_mid(n), "MWind", 160.0, 0.5, "Wind, mittleres Band: Rauschen"),
        ("wind_high", 2.0, lambda n: wind_high(n), "MWind", 160.0, 0.5,
         "Wind, hohes Band: Zischen an Spiegeln und Säulen, leises Pfeifen einer Dichtung"),
        ("wind_buffet", 3.0, lambda n: wind_buffet(n), "MWind", 230.0, 0.25,
         "Wummern nahe dem Höchsttempo (Gefühl des offenen Fensters): tiefes Brausen, 4-9-mal je Sekunde pulsierend"),
        ("rail_scrape", 2.0, lambda n: rail_scrape(n), "MImpact", 100.0, 0.35,
         "Blech schleift an der Leitplanke: Schleifen in Körnern, Eigenschwingungen der Planke, Funken, Dröhnen"),
    ]


def build(out: str | None, wav_dir: str | None, log=print) -> None:
    man = ml.Manifest(FOLDER, out)
    man.drop_generator(GENERATOR)
    repo = out is None
    total = 0
    for sid, seconds, fn, bus, ref_kmh, pexp, note in loops():
        n = int(round(seconds * SR)) if seconds else 0
        y = np.asarray(fn(n), np.float64)
        if y.ndim != 1:
            raise ValueError(sid)
        n = len(y)
        y = y - float(np.mean(y))
        y = y * (PEAK / float(np.max(np.abs(y))))
        # and the true peak at -3 dBTP at most (QC: <= -1): a soft-limited loop peaks between its samples
        y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
        curve = [[p, lufs_at_pitch(y, p)] for p in PITCHES]
        data = np.concatenate([y, y[:LOOP_GUARD]])
        name = sid + ".wav"
        ml.write_wav16(man.file(name), data)
        if repo:
            write_wav_import_keep(man.file(name), (0, n))
        e = man.add(sid, name, "loop", GENERATOR, loop=(0, n), bus=bus, gain_db=0.0, note=note)
        e["ref_kmh"] = ref_kmh
        e["pitch_exp"] = pexp
        e["lufs_pitch"] = curve
        total += os.path.getsize(man.file(name))
        if wav_dir:
            os.makedirs(wav_dir, exist_ok=True)
            reps = int(math.ceil(8.0 * SR / n))
            ml.write_wav16(os.path.join(wav_dir, sid + ".wav"), np.tile(y, reps)[:int(8.0 * SR)])
        log(f"  {sid:14s} {n / SR:5.2f} s  {e['lufs']:6.1f} LUFS  {e['true_peak_db']:5.1f} dBTP  {bus}")
    man.save()
    log(f"vehicle_loops: {len(loops())} Schleifen, {total / 1e6:.2f} MB -> {man.dir}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Schleifen des Autos auf der Straße (Profil Modern, AU-C1)")
    ap.add_argument("--out", default=None, help="Ordner statt des Repositorys (ohne Import-Dateien)")
    ap.add_argument("--wav", default=None, help="zusätzlich eine Hörprobe je Schleife (8 s) in diesen Ordner")
    args = ap.parse_args()
    build(args.out, args.wav, print if not args.out else (lambda *_a: None))
    return 0


if __name__ == "__main__":
    sys.exit(main())
