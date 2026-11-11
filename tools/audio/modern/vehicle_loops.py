#!/usr/bin/env python3
"""Natively mixed loops of the player's car on the road – profile "Modern", package AU-C1, reworked by AU-R (contract
D27–D29, §4.7.3; docs/audio-modern.md "Fahrbahn, Wind, Aufprall"). Writes into assets/audio/modern/vehicle/ (mono,
44.1 kHz) and registers them in the folder's manifest next to the engine layers of AU-B (modern_lib.Manifest: only
this generator's own entries are replaced; files it wrote before and no longer writes are removed).

    python3 tools/audio/modern/vehicle_loops.py               into the repository (with Godot import files)
    python3 tools/audio/modern/vehicle_loops.py --out /tmp/x  into /tmp/x/assets/audio/modern/vehicle (QC determinism)
    python3 tools/audio/modern/vehicle_loops.py --wav /tmp/p  also a preview WAV of every loop (8 s, at ref speed)

Every loop is seamless by construction: noise is periodic (random phases on an FFT grid of the loop length),
events are placed circularly, modulations are periodic, tones have whole numbers of cycles.

Two kinds of file (AU-R, KRITIK-FAHRBAHN B1 – the 2-s loops read twice at L/2 repeated exactly every second):
  * the rolling, wet, snow and wind layers – noise and dense event textures, played on two panned players (the
    left and the right wheels) – have one loop PER SIDE: "<id>" for the left, "<id>_b" for the right (the entry of
    the left names it in "pair"), the same generator with another seed (+SIDE_B) and another length (4–7.6 s, the
    two lengths without a small common multiple), as Ogg Vorbis q5 – noise needs no PCM, and the budget of contract
    §4.11 would not hold 13 pairs of long WAV loops (§4.7.3 names WAV for tonal loops). An Ogg loop runs to the
    end of its file (loop_offset 0).
  * tonal and transient loops (squeal, scrub, the concrete slabs, the guardrail scrape) stay 16-bit WAV with
    LOOP_GUARD frames of the loop's start behind loop_end (Godot reads the frame at the loop end before it wraps –
    docs "Fallen" 13). The slab patterns are 32 slabs long (KRITIK-FAHRBAHN B4: 8 slabs repeated every 40 m).

Manifest entries carry, besides the measured values of modern_lib:
    ref_kmh     the road speed the loop is designed for (played at pitch 1)
    pitch_exp   the runtime plays it at pitch (v / ref_kmh) ** pitch_exp
    lufs_pitch  [[pitch, LUFS], …] – the integrated loudness of the loop (as written: after Vorbis) played at that
                pitch (the K weighting changes with the shifted spectrum); the runtime interpolates it so its level
                laws hold for the loudness the player hears, not for the file at pitch 1
    pair        (left loop of a pair) the id of the right side's own loop
The levels themselves are data (config audio.modern.road): the files carry no level decision (gain_db 0).
Deterministic (fixed seeds, no time stamps, Vorbis bit-exact): audio_qc.py --determinism runs this twice and
compares the bytes.
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
OGG_Q = 5.0                      # Vorbis quality of the noise loops (the music's quality)
SIDE_B = 50                      # seed offset of the right side's own loop
SLABS = 32                       # slabs per concrete pattern (5 m each: the pattern repeats every 160 m)
# The 32-slab patterns are built from AU-C1's 8-slab designs (what the user heard): their 8 joints × 2 axles per
# design, struck in a shuffled order (rounds of all 8, never the same joint twice in a row) and each time a little
# harder or softer (SLAB_ACCENT_DB), never harder than the hardest joint of AU-C1 (AU-R2, KRITIK-R H1). Between 110
# and 150 km/h both designs sound at once and in step (R3): their strikes meet on the same instants and add partly
# coherently (every strike's decaying sines start at phase 0), so the balance of the pair depends on WHICH strike of
# the slow design meets which of the fast one – AU-R's new random strikes shifted it by +1.7 dB at 400 Hz (130 km/h,
# measured in the game by KRITIK-R, and in the model of scratch slab_search.py to 0.05 dB). With AU-C1's strikes
# paired as in AU-C1 (slow joint j meets fast joint j, the same order for both designs) the pair keeps AU-C1's
# balance at every speed.
SLAB_SOURCE = {90.0: 2601, 180.0: 2701}    # ref_kmh -> seed of AU-C1's 8-slab design
SLAB_SOURCE_N = 8
SLAB_ORDER_SEED = 3301
SLAB_ACCENT_DB = 1.2


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


TWELFTH = [1000.0 * 2.0 ** (k / 12.0) for k in range(-68, 51)]   # 1/12-octave centres 19.7 Hz .. 18.4 kHz


def band_db(y: np.ndarray, centres: list[float], half: float) -> np.ndarray:
    """Energy per band (centre × 2^±half octaves; dB, relative to the whole signal)."""
    f = np.fft.rfftfreq(len(y), 1.0 / SR)
    p = np.abs(np.fft.rfft(y)) ** 2
    tot = float(p.sum()) + 1e-30
    return np.array([10.0 * np.log10(float(p[(f >= c * 2.0 ** -half) & (f < c * 2.0 ** half)].sum()) / tot + 1e-30)
                     for c in centres])


def match_loop(y: np.ndarray, ref: np.ndarray, max_db: float = 4.0, rounds: int = 4) -> np.ndarray:
    """Loop y with the spectral balance of ref (AU-R: a new seed and length of an event texture moves its low
    third-octave bands by 1–3 dB – few events per band; the user heard ref). Matched in 1/12-octave bands, so the
    third octaves still agree when the runtime plays both a little higher or lower (a pitch shift moves energy across
    band edges): a smooth gain curve over log frequency (corrections at the band centres, interpolated, at most
    max_db; bands more than 40 dB under ref's loudest left alone), applied circularly over the whole loop, so the loop
    stays seamless."""
    t_ref = band_db(ref, TWELFTH, 1.0 / 24.0)
    keep = t_ref > t_ref.max() - 40.0
    lc = np.log(np.array(TWELFTH))
    for _ in range(rounds):
        d = np.where(keep, np.clip(t_ref - band_db(y, TWELFTH, 1.0 / 24.0), -max_db, max_db), 0.0)
        y = cfilter(y, lambda f, d=d: 10.0 ** (np.interp(np.log(np.maximum(f, 1.0)), lc, d, left=d[0], right=d[-1]) / 20.0))
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


def write_ogg_import_keep(path: str) -> None:
    """modern_lib.write_ogg_import() for a loop from the start of the file, keeping the [remap]/[deps] head of an
    existing .import file (the same work-around as write_wav_import_keep)."""
    imp = path + ".import"
    head = ""
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].strip("\n")
    ml.write_ogg_import(path, 0.0)
    if head:
        with open(imp, encoding="utf-8") as fh:
            params = fh.read().split("[params]", 1)[1]
        with open(imp, "w", encoding="utf-8") as fh:
            fh.write(head + "\n\n[params]" + params)


# ------------------------------------------------------------------------------------------------------------------
# The loops
# ------------------------------------------------------------------------------------------------------------------

def tyre_asphalt(n: int, s: int = 0) -> np.ndarray:
    """Dry asphalt: tread impacts and air pumping (a broad hump around 0.9 kHz), the tyre cavity resonance (218 Hz,
    narrow), structure-borne rumble of the macrotexture (30-110 Hz), a little hiss. s = seed offset (the other side's
    own loop)."""
    y = pnoise(n, 1101 + s, lambda f: hp(f, 300.0, 1) * lp(f, 1300.0, 2) * peak(f, 218.0, 9.0, 7.0) * peak(f, 950.0, 1.3, 3.0)
               + 0.5 * bp(f, 30.0, 110.0, 2) + 0.035 * bp(f, 2500.0, 6000.0, 2))
    return y * (1.0 + 0.10 * slow(n, 1102 + s, 0.5, 3.0))


def tyre_concrete(n: int, s: int = 0) -> np.ndarray:
    """Brushed concrete: rougher and brighter than asphalt (up to 2.3 kHz), the faint whine of the transverse
    tining (1.15 kHz, narrow), more rumble."""
    y = pnoise(n, 1201 + s, lambda f: hp(f, 350.0, 1) * lp(f, 2000.0, 2) * peak(f, 232.0, 7.0, 6.0) * peak(f, 1250.0, 1.6, 4.0)
               * peak(f, 1150.0, 30.0, 6.0) + 0.6 * bp(f, 28.0, 120.0, 2) + 0.07 * bp(f, 2600.0, 6500.0, 2))
    return y * (1.0 + 0.14 * slow(n, 1202 + s, 0.5, 4.0))


def tyre_deck(n: int, s: int = 0) -> np.ndarray:
    """Orthotropic steel deck under asphalt: the rolling noise with the hollow drone of the deck plates (68 and 104
    Hz) and faint metallic partials of the stiffeners."""
    def shape(f):
        rolling = 0.8 * hp(f, 300.0, 1) * lp(f, 1250.0, 2) * peak(f, 215.0, 9.0, 6.0) * peak(f, 900.0, 1.3, 2.0)
        drone = 0.95 * bp(f, 40.0, 170.0, 2) * peak(f, 68.0, 6.0, 10.0) * peak(f, 104.0, 8.0, 7.0)
        metal = 0.06 * ((peak(f, 410.0, 40.0, 14.0) - 1.0) + (peak(f, 655.0, 40.0, 14.0) - 1.0)
                        + (peak(f, 1180.0, 50.0, 14.0) - 1.0))
        return rolling + drone + metal
    y = pnoise(n, 1301 + s, shape)
    return y * (1.0 + 0.16 * slow(n, 1302 + s, 0.5, 2.5))


def tyre_cobbles(n: int, ref_kmh: float, s: int = 0, cap: float | None = None, draws: list | None = None) -> np.ndarray:
    """Setts (about 11.5 cm long) at ref_kmh: four wheels strike the sett edges ~120 times a second each, a little
    out of step; every strike a short thud (tyre and sett, 180-260 Hz) with a click, the suspension and body answer
    below 90 Hz, now and then a rattle inside the car. cap (AU-R2, KRITIK-R M5): no stone is struck harder than
    this (the log-normal draw of its strength is limited to cap; the draws stay the same): a longer loop draws more
    stones, and its hardest ones stood out 1.6–3 dB above the hardest of AU-C1's 2.5-s loop, every loop length.
    draws: if a list, the strength draws are appended to it."""
    rng = np.random.default_rng(1401 + s)
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
            d = float(rng.normal(0.0, 0.38))
            if draws is not None:
                draws.append(d)
            a = gain * float(np.exp(d if cap is None else min(d, cap)))
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


def tyre_gravel(n: int, s: int = 0) -> np.ndarray:
    """The gravel shoulder: dense crunch of stones crushed and pushed aside under the tyres, an uneven low rumble,
    stones flung against the wheel arches (short metallic pings)."""
    rng = np.random.default_rng(1501 + s)
    m = int(rng.poisson(2600 * n / SR))
    train = np.zeros(n)
    amp = np.clip(rng.lognormal(0.0, 0.5, m), 0.0, 3.5)
    np.add.at(train, rng.integers(0, n, m), amp * rng.choice([-1.0, 1.0], m))
    crunch = cfilter(train, lambda f: bp(f, 1100.0, 7500.0, 2) * peak(f, 2800.0, 1.4, 3.0) + 0.25 * bp(f, 300.0, 1100.0, 1))
    crunch /= rms(crunch)
    crunch = 3.5 * np.tanh(crunch / 3.5)          # a few grains far above the rest would set the peak of the file
    rumble = pnoise(n, 1502 + s, lambda f: bp(f, 20.0, 95.0, 2)) * (1.0 + 0.45 * slow(n, 1503 + s, 1.0, 6.0))
    pings = np.zeros(n)
    for _ in range(int(9 * n / SR)):
        f0 = rng.uniform(2100.0, 5600.0)
        clip = mixc((1.0, decay_sine(f0, rng.uniform(0.005, 0.014), 0.06, rng.uniform(0, 6.28))),
                    (0.5, decay_sine(f0 * rng.uniform(1.37, 1.62), 0.006, 0.05)))
        place(pings, clip, int(rng.integers(0, n)), rng.uniform(0.6, 1.6))
    pings /= rms(pings) + 1e-12
    return crunch + 0.5 * rumble + 0.22 * pings


def tyre_snow(n: int, s: int = 0) -> np.ndarray:
    """Packed snow under the tyres (AU-R; before, the gravel loop with its stone pings stood in): a soft, dense
    crunch of compacted crystals – lower, gentler grains than gravel, no stones against the wheel arches – that swells
    and fades as the tyres compact uneven snow, and a faint dull rumble."""
    rng = np.random.default_rng(3101 + s)
    m = int(rng.poisson(3400 * n / SR))
    train = np.zeros(n)
    amp = np.clip(rng.lognormal(0.0, 0.35, m), 0.0, 2.5)
    np.add.at(train, rng.integers(0, n, m), amp * rng.choice([-1.0, 1.0], m))
    crunch = cfilter(train, lambda f: bp(f, 450.0, 3800.0, 2) * peak(f, 1300.0, 1.2, 3.0) + 0.3 * bp(f, 150.0, 450.0, 1))
    crunch /= rms(crunch)
    crunch *= np.clip(1.0 + 0.3 * slow(n, 3102 + s, 1.0, 5.0), 0.3, 2.0)
    rumble = pnoise(n, 3103 + s, lambda f: bp(f, 22.0, 80.0, 2))
    return crunch + 0.3 * rumble


def tyre_grass(n: int, s: int = 0) -> np.ndarray:
    """Off the road at the open limit: a soft swish of grass, the car thumping over uneven ground (low thuds a few
    times a second) and a heavy low rumble."""
    rng = np.random.default_rng(1601 + s)
    swish = pnoise(n, 1602 + s, lambda f: bp(f, 250.0, 3500.0, 1) / np.sqrt(f / 500.0)) * (1.0 + 0.4 * slow(n, 1603 + s, 1.0, 6.0))
    thumps = np.zeros(n)
    for _ in range(int(5.5 * n / SR)):
        clip = mixc((1.0, decay_sine(rng.uniform(32.0, 58.0), rng.uniform(0.05, 0.09), 0.35, 0.0, rng.uniform(26.0, 40.0), 0.004)),
                    (0.2, noise_burst(rng, 0.08, 150.0, 900.0, 0.02)))
        place(thumps, clip, int(rng.integers(0, n)), rng.uniform(0.5, 1.4))
    thumps /= rms(thumps)
    rumble = pnoise(n, 1604 + s, lambda f: bp(f, 16.0, 75.0, 2))
    return 0.55 * swish + thumps + 0.6 * rumble


def tyre_wet(n: int, s: int = 0) -> np.ndarray:
    """A wet road: spray hiss of the water pressed out of the tread (1-10 kHz), a fine sizzle, water sloshing in
    the wheel arches (150-900 Hz, moving)."""
    rng = np.random.default_rng(1701 + s)
    hiss = pnoise(n, 1702 + s, lambda f: hp(f, 900.0, 1) * lp(f, 7000.0, 2) * peak(f, 3200.0, 0.8, 4.0))
    m = int(rng.poisson(6000 * n / SR))
    train = np.zeros(n)
    np.add.at(train, rng.integers(0, n, m), rng.standard_normal(m))
    sizzle = cfilter(train, lambda f: bp(f, 4000.0, 9000.0, 2))
    sizzle /= rms(sizzle)
    slosh = pnoise(n, 1703 + s, lambda f: hp(f, 150.0, 1) * lp(f, 900.0, 2)) * (1.0 + 0.6 * slow(n, 1704 + s, 0.5, 4.0))
    return hiss + 0.25 * sizzle + 0.5 * slosh


def tyre_rumble(n: int, rate_hz: float, s: int = 0) -> np.ndarray:
    """Profiled edge line / rumble strip: the tyres drum over the raised marks rate_hz times a second (at pitch 1),
    a little irregular (agglomerate dots); every bump a short thunk through the body (140 and 420 Hz)."""
    rng = np.random.default_rng(1801 + s)
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
    y = out + 0.15 * pnoise(n, 1802 + s, lambda f: bp(f, 100.0, 1500.0, 1))
    # the strongest bumps softly limited (crest 13 → about 10 dB): at 200 km/h the strip alone reached the master
    # limiter (measured)
    r = rms(y)
    return 2.8 * r * np.tanh(y / (2.8 * r))


AXLES = ((0.0, 1.0), (1.0, 0.85))   # (share of wheelbase / v after the front axle, gain) of the two strikes


def slab_strikes(ref_kmh: float, seed: int, slabs: int = 8) -> list[tuple[float, np.ndarray, np.ndarray]]:
    """The joints of slab_loop(ref_kmh, seed, slabs) one by one: [(accent dB, front strike, rear strike), …] – the
    same random draws in the same order, so they are bit-identical to that loop's. Every strike: the thump of the
    tyre over the joint (74-84 Hz falling to 52-60 Hz), the tack of the edge (noise 0.5-2.6 kHz) and a slap
    (280-330 Hz); a faster car strikes the edge harder and shorter."""
    rng = np.random.default_rng(seed)
    sharp = 90.0 / ref_kmh
    out = []
    for _k in range(slabs):
        acc = float(rng.normal(0.0, 2.2))
        clips = []
        for _axle in AXLES:
            thump = decay_sine(rng.uniform(74.0, 84.0), 0.035 * sharp ** 0.5, 0.18, 0.0, rng.uniform(52.0, 60.0), 0.0015)
            tack = noise_burst(rng, 0.02, 500.0, 2600.0, 0.0025 * sharp ** 0.5)
            slap = decay_sine(rng.uniform(280.0, 330.0), 0.010, 0.05)
            clips.append(mixc((1.0, thump), (1.0, tack), (0.5, slap)))
        out.append((acc, clips[0], clips[1]))
    return out


def _slab_place(out: np.ndarray, k: int, per: float, gap: float, strike: tuple, a: float) -> None:
    n = len(out)
    for clip, (share, g) in zip(strike[1:], AXLES):
        place(out, clip, int(round((k * per + share * gap) * SR)) % n, a * g)


def slab_loop(ref_kmh: float, seed: int, slabs: int = 8, slab_m: float = 5.0, wheelbase_m: float = 2.7) -> np.ndarray:
    """Concrete slabs (AU-C1's design, the reference of the patterns below): at ref_kmh the front and then the rear
    axle strike the sealed joint every slab_m – the classic 'ta-tock' of an old concrete motorway. The ratio of the
    gaps (wheelbase / slab) does not depend on the speed, so the runtime plays the loop at pitch v / ref and the
    rhythm is exact at every speed."""
    v = ref_kmh / 3.6
    per = slab_m / v
    out = np.zeros(int(round(slabs * per * SR)))
    for k, strike in enumerate(slab_strikes(ref_kmh, seed, slabs)):
        _slab_place(out, k, per, wheelbase_m / v, strike, 10.0 ** (strike[0] / 20.0))
    return out


def slab_order(slabs: int, source_n: int, seed: int) -> list[int]:
    """Which joint of the source each slab of a pattern strikes: rounds of a shuffled order of all source joints,
    never the same joint twice in a row."""
    rng = np.random.default_rng(seed)
    order: list[int] = []
    while len(order) < slabs:
        p = [int(j) for j in rng.permutation(source_n)]
        if order and p[0] == order[-1]:
            p[0], p[-1] = p[-1], p[0]
        order += p
    return order[:slabs]


def slab_accents(slabs: int, seed: int, spread_db: float) -> np.ndarray:
    """Per slab of a pattern: how much harder (dB) its joint is struck than in the source (normal, spread_db)."""
    return np.random.default_rng(seed + 1).normal(0.0, spread_db, slabs)


def slab_pattern(ref_kmh: float, source_seed: int, order: list[int], accents_db: np.ndarray, top_db: float = 0.0,
                 slab_m: float = 5.0, wheelbase_m: float = 2.7) -> np.ndarray:
    """A concrete pattern of len(order) slabs made of the joints of AU-C1's design slab_loop(ref_kmh, source_seed)
    (AU-R2): slab k strikes the source's joint order[k] with that joint's accent + accents_db[k], but never harder
    than top_db relative to the source's hardest strike (peak of accent × strike). The same order and accents for
    both designs keep AU-C1's pairing of their strikes (see SLAB_SOURCE)."""
    strikes = slab_strikes(ref_kmh, source_seed, SLAB_SOURCE_N)
    v = ref_kmh / 3.6
    per = slab_m / v
    out = np.zeros(int(round(len(order) * per * SR)))

    def strike_peak(s, a):
        return a * max(float(np.max(np.abs(s[1]))) * AXLES[0][1], float(np.max(np.abs(s[2]))) * AXLES[1][1])

    top = max(strike_peak(s, 10.0 ** (s[0] / 20.0)) for s in strikes) * 10.0 ** (top_db / 20.0)
    for k, j in enumerate(order):
        s = strikes[j]
        a = 10.0 ** ((s[0] + float(accents_db[k])) / 20.0)
        a = min(a, a * top / max(strike_peak(s, a), 1e-12))
        _slab_place(out, k, per, wheelbase_m / v, s, a)
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


def wind_low(n: int, s: int = 0) -> np.ndarray:
    """Wind, low band: the roar of the air around the body (22-190 Hz, falling)."""
    return pnoise(n, 2101 + s, lambda f: bp(f, 22.0, 190.0, 2) / np.sqrt(f / 50.0) + 0.15 * bp(f, 190.0, 450.0, 1))


def wind_mid(n: int, s: int = 0) -> np.ndarray:
    """Wind, middle band: the whoosh (240 Hz - 1.9 kHz)."""
    return pnoise(n, 2201 + s, lambda f: hp(f, 240.0, 1) * lp(f, 1800.0, 2) * peak(f, 650.0, 0.9, 2.0))


def wind_high(n: int, s: int = 0) -> np.ndarray:
    """Wind, high band: hiss of the turbulence at mirrors and pillars (2.3-8.5 kHz) with a faint seal whistle."""
    y = pnoise(n, 2301 + s, lambda f: bp(f, 2300.0, 8500.0, 2) * peak(f, 4200.0, 0.8, 2.0))
    whistle = pnoise(n, 2302 + s, lambda f: (peak(f, 3150.0, 60.0, 20.0) - 1.0))
    return y + 0.18 * whistle * (1.0 + 0.5 * slow(n, 2303 + s, 0.3, 2.0))


def wind_buffet(n: int, s: int = 0) -> np.ndarray:
    """The 'open window' feeling near top speed: low buffeting (30-120 Hz) pulsing 4-9 times a second."""
    y = pnoise(n, 2401 + s, lambda f: bp(f, 28.0, 120.0, 2) * peak(f, 55.0, 2.0, 4.0))
    am = np.clip(1.0 + 0.85 * slow(n, 2402 + s, 4.0, 9.0), 0.08, 2.5)
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


# AU-C1's loop lengths (s): the generator renders that loop once more as the reference of the third-octave balance
# of the new pair (match_loop) – what the user heard.
OLD_SECONDS = {"tyre_asphalt": 2.0, "tyre_concrete": 2.0, "tyre_deck": 2.0, "tyre_cobbles": 2.5, "tyre_gravel": 2.5,
               "tyre_grass": 2.5, "tyre_wet": 2.0, "tyre_rumble": 1.0, "wind_low": 2.0, "wind_mid": 2.0, "wind_high": 2.0,
               "wind_buffet": 3.0}
# The pans of AU-C1's two players per layer (road.tyres.pan, road.wind.pan of its configuration).
OLD_PAN = {"MRoad": 0.55, "MWind": 0.7}
# Layers that sound on one side at a time: the rumble strip is under the wheels that leave the lane, AU-C1's other
# player was silent – what was heard is the loop itself.
ONE_SIDED = ("tyre_rumble",)


def heard(ref: np.ndarray, pan: float) -> np.ndarray:
    """What AU-C1 played of its loop ref: two players panned to ±pan (equal-power law) reading the same loop half a
    loop apart at the same pitch. In each channel the two copies add with the loop's harmonics (multiples of 1 /
    length) alternately in phase and out of phase; for a texture with a strong rhythm (cobbles, rumble strip) that
    shapes the third octaves by up to 2.4 dB (measured in the game: Pflaster 50 km/h +1.0 dB at 126 Hz). The energy
    over both channels is that of ref + a · (ref shifted by half a loop), with 2a / (1 + a²) = cos(pan · π/2), the
    correlation of the two players' channel gains."""
    c = float(np.cos(pan * np.pi / 2.0))
    a = (1.0 - np.sqrt(1.0 - c * c)) / c if c > 1e-9 else 0.0
    return ref + a * np.roll(ref, len(ref) // 2)


def _pair(sid: str, sec_a: float, sec_b: float, fn, bus: str, ref_kmh: float, pexp: float, note: str) -> list[tuple]:
    """A layer of the two panned players: the left side's loop and the right side's own loop (seed + SIDE_B), both
    matched to the spectral balance of AU-C1's loop of this layer as its two players sounded (heard; where there was
    one). The new sides are independent, their energies add."""
    old = OLD_SECONDS.get(sid)

    def make(n: int, s: int, f=fn) -> np.ndarray:
        y = f(n, s)
        if not old:
            return y
        ref = f(int(round(old * SR)), 0)
        return match_loop(y, ref if sid in ONE_SIDED else heard(ref, OLD_PAN.get(bus, 0.55)))
    return [(sid, sec_a, lambda n: make(n, 0), bus, ref_kmh, pexp, note + "; linke Seite", "ogg", sid + "_b"),
            (sid + "_b", sec_b, lambda n: make(n, SIDE_B), bus, ref_kmh, pexp,
             note + "; rechte Seite: eigene Schleife (anderer Seed, andere Länge)", "ogg", "")]


# id, seconds, function, bus, ref_kmh, pitch_exp, note, format, pair. Lengths of a pair: 4–7.6 s, their ratio far
# from a small fraction (the sum of both sides never repeats; each side repeats after 4 s or more at its design
# speed, also at top speed).
def loops() -> list[tuple]:
    out = []
    out += _pair("tyre_asphalt", 5.3, 6.7, tyre_asphalt, "MRoad", 120.0, 0.35,
                 "Rollgeräusch Asphalt trocken: Profil und Luftpumpen (Buckel um 0,9 kHz), Reifenhohlraum 218 Hz, Grollen der Textur")
    out += _pair("tyre_concrete", 5.1, 6.3, tyre_concrete, "MRoad", 120.0, 0.35,
                 "Rollgeräusch Beton: rauer und heller, leises Singen der Querrillen (1,15 kHz)")
    out += _pair("tyre_deck", 4.9, 6.1, tyre_deck, "MRoad", 120.0, 0.35,
                 "Rollgeräusch auf dem Stahldeck einer Brücke: hohles Dröhnen der Deckbleche (68/104 Hz), Metallpartiale")
    out += _pair("tyre_cobbles", 5.7, 7.1, lambda n, s: tyre_cobbles(n, 50.0, s), "MRoad", 50.0, 0.9,
                 "Kopfsteinpflaster bei 50 km/h: vier Räder schlagen etwa 120-mal je Sekunde auf Steinkanten, Karosserie darunter")
    out += _pair("tyre_gravel", 4.7, 5.9, tyre_gravel, "MRoad", 80.0, 0.55,
                 "Bankett (Schotter): Knirschen, unebenes Grollen, Steine gegen die Radhäuser")
    out += _pair("tyre_grass", 4.3, 5.5, tyre_grass, "MRoad", 60.0, 0.4,
                 "Gras jenseits des Banketts: Rauschen, dumpfe Schläge über unebenen Boden")
    out += _pair("tyre_wet", 5.5, 6.9, tyre_wet, "MRoad", 120.0, 0.3,
                 "Nasse Fahrbahn: Sprühzischen, feines Brutzeln, Wasser in den Radhäusern")
    out += _pair("tyre_snow", 5.0, 6.4, tyre_snow, "MRoad", 80.0, 0.5,
                 "Schnee: weiches, dichtes Knirschen gepressten Schnees, ohne Steinschläge, leises dumpfes Grollen")
    out += _pair("tyre_rumble", 4.1, 5.3, lambda n, s: tyre_rumble(n, 100.0, s), "MRoad", 108.0, 1.0,
                 "Profilierte Randlinie / Rüttelstreifen: 100 Schläge je Sekunde bei Tonhöhe 1 (Abstand 30 cm bei 108 km/h)")
    order = slab_order(SLABS, SLAB_SOURCE_N, SLAB_ORDER_SEED)
    accents = slab_accents(SLABS, SLAB_ORDER_SEED, SLAB_ACCENT_DB)

    def slabs(ref_kmh: float) -> np.ndarray:
        src = SLAB_SOURCE[ref_kmh]
        return match_loop(slab_pattern(ref_kmh, src, order, accents), slab_loop(ref_kmh, src))
    out += [
        ("slab_slow", None, lambda n: slabs(90.0), "MRoad", 90.0, 1.0,
         f"Betonplatten 5 m, Achsabstand 2,7 m: Vorder- und Hinterachse über die Fuge, entworfen bei 90 km/h ({SLABS} Platten "
         "aus den 8 Fugen von AU-C1, gemischte Folge)", "wav", ""),
        ("slab_fast", None, lambda n: slabs(180.0), "MRoad", 180.0, 1.0,
         f"Betonplatten 5 m, Achsabstand 2,7 m, entworfen bei 180 km/h (härterer, kürzerer Schlag; {SLABS} Platten aus den "
         "8 Fugen von AU-C1, dieselbe Folge wie das langsame Muster)", "wav", ""),
        ("squeal", 2.0, lambda n: squeal(n, 820.0), "MRoad", 0.0, 0.0,
         "Reifenquietschen an der Haftgrenze: Ton 820 Hz mit Obertönen, schwankend und flatternd, Reibrauschen", "wav", ""),
        ("scrub", 1.5, lambda n: scrub(n), "MRoad", 0.0, 0.0,
         "Radieren ohne Ton: wenig Schlupf, nasse Fahrbahn, Rutschen beim Unfall", "wav", ""),
    ]
    out += _pair("wind_low", 5.9, 7.3, wind_low, "MWind", 160.0, 0.3, "Wind, tiefes Band: Brausen um die Karosserie")
    out += _pair("wind_mid", 5.6, 6.8, wind_mid, "MWind", 160.0, 0.5, "Wind, mittleres Band: Rauschen")
    out += _pair("wind_high", 5.2, 6.6, wind_high, "MWind", 160.0, 0.5,
                 "Wind, hohes Band: Zischen an Spiegeln und Säulen, leises Pfeifen einer Dichtung")
    out += _pair("wind_buffet", 6.2, 7.6, wind_buffet, "MWind", 230.0, 0.25,
                 "Wummern nahe dem Höchsttempo (Gefühl des offenen Fensters): tiefes Brausen, 4-9-mal je Sekunde pulsierend")
    out.append(("rail_scrape", 2.0, lambda n: rail_scrape(n), "MImpact", 100.0, 0.35,
                "Blech schleift an der Leitplanke: Schleifen in Körnern, Eigenschwingungen der Planke, Funken, Dröhnen", "wav", ""))
    return out


def _entry_files(e: dict) -> list[str]:
    return list(e.get("files") or ([e["file"]] if "file" in e else []))


def build(out: str | None, wav_dir: str | None, log=print) -> None:
    man = ml.Manifest(FOLDER, out)
    before = {f for e in man.sounds.values() if e.get("generator") == GENERATOR for f in _entry_files(e)}
    man.drop_generator(GENERATOR)
    repo = out is None
    total = 0
    written: set[str] = set()
    for sid, seconds, fn, bus, ref_kmh, pexp, note, fmt, pair in loops():
        n = int(round(seconds * SR)) if seconds else 0
        y = np.asarray(fn(n), np.float64)
        if y.ndim != 1:
            raise ValueError(sid)
        n = len(y)
        y = y - float(np.mean(y))
        y = y * (PEAK / float(np.max(np.abs(y))))
        # and the true peak at -3 dBTP at most (QC: <= -1): a soft-limited loop peaks between its samples
        y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
        if fmt == "ogg":
            name = sid + ".ogg"
            # Vorbis codes the end of a stream with a larger error than its middle (measured: 1.4e-2 against 5.7e-3
            # RMS for wind_buffet at q5); for a smooth low loop that error can make the seam the roughest spot of the
            # loop. The first quality from OGG_Q up whose seam is no rougher than twice its surroundings is kept.
            for q in (OGG_Q, OGG_Q + 1.0, OGG_Q + 2.0, OGG_Q + 3.0):
                ml.write_ogg(man.file(name), y, quality=q)
                played = qc_lib.read_audio(man.file(name))[0][:, 0]     # what the game decodes
                seam = qc_lib.loop_seam(played[:, None], 0, len(played), 0.1, SR)
                if max(seam["ratio"], seam["kink_ratio"]) <= 2.0 or max(seam["loop_ratio"], seam["loop_kink_ratio"]) <= 1.0:
                    break
            if len(played) != n:
                raise ValueError(f"{sid}: Vorbis liefert {len(played)} statt {n} Frames")
            if repo:
                write_ogg_import_keep(man.file(name))
        else:
            name = sid + ".wav"
            ml.write_wav16(man.file(name), np.concatenate([y, y[:LOOP_GUARD]]))
            played = y
            if repo:
                write_wav_import_keep(man.file(name), (0, n))
        curve = [[p, lufs_at_pitch(played, p)] for p in PITCHES]
        e = man.add(sid, name, "loop", GENERATOR, loop=(0, n), bus=bus, gain_db=0.0, note=note)
        e["ref_kmh"] = ref_kmh
        e["pitch_exp"] = pexp
        e["lufs_pitch"] = curve
        if pair:
            e["pair"] = pair
        if fmt == "ogg":
            e["vorbis_q"] = q
        written.add(name)
        total += os.path.getsize(man.file(name))
        if wav_dir:
            os.makedirs(wav_dir, exist_ok=True)
            reps = int(math.ceil(8.0 * SR / n))
            ml.write_wav16(os.path.join(wav_dir, sid + ".wav"), np.tile(played, reps)[:int(8.0 * SR)])
        log(f"  {sid:16s} {n / SR:5.2f} s  {e['lufs']:6.1f} LUFS  {e['true_peak_db']:5.1f} dBTP  {fmt}  {bus}")
    man.save()
    if repo:
        # files of this generator's earlier entries that it no longer writes (AU-C1's 2-s WAV loops)
        for name in sorted(before - written):
            for p in (man.file(name), man.file(name) + ".import"):
                if os.path.exists(p):
                    os.remove(p)
                    log(f"  entfernt: {os.path.basename(p)}")
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
