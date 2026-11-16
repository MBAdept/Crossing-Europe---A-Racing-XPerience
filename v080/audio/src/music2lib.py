#!/usr/bin/env python3
"""v0.8.0 audio study, spike 2: "modern" production layer on top of tools/audio/music_synth.py (imported, not
modified): 48 kHz, layered drums, sub bass, wide leads, deeper sidechain pump, multiband master with M/S stage.
Scratch prototype - not part of the repo."""
from __future__ import annotations
import functools, math, os
import numpy as np
import alib
import music_synth as ms


def setup(sr: int = 48000, bpm: float | None = None) -> None:
    ms.SR = sr

    def eq_fir(bands, nfft: int = 16384, length: int = 8192, sr=None):
        return ms._eq_fir(tuple(tuple(b) for b in bands), nfft, length, ms.SR if sr is None else sr)

    ms.eq_fir = eq_fir
    if bpm is not None:
        ms.BPM = bpm
        ms.BEAT = 60.0 / bpm
        ms.BAR = 4.0 * ms.BEAT
        ms.STEP = ms.BAR / 16.0
        ms.DELAY = (0.75 * ms.BEAT, 0.38, 9, 3800.0, 350.0)


# ---------------------------------------------------------------------------------------------------------
# instruments of the modern profile
# ---------------------------------------------------------------------------------------------------------
@functools.lru_cache(maxsize=None)
def kick2(var: int) -> np.ndarray:
    """Layered kick: longer sub (47 Hz), fast pitch sweep for the punch, harder click."""
    SR = ms.SR
    rng = ms.rng_of("kick2", var)
    n = int(0.62 * SR)
    t = np.arange(n) / SR
    f = 47.0 + 62.0 * np.exp(-t / 0.028) + 260.0 * np.exp(-t / 0.004)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR + 0.08 * rng.uniform(-1, 1))
    body *= (0.85 * np.exp(-t / 0.26) + 0.15 * np.exp(-t / 0.05)) * (1.0 - np.exp(-t / 0.0005))
    click = ms.band_noise(rng, n, 1500.0, 8000.0) * np.exp(-t / 0.002) * 0.22
    beater = np.sin(2.0 * np.pi * 4200.0 * t) * np.exp(-t / 0.0015) * 0.10
    x = np.tanh(2.2 * (body + click + beater)) / np.tanh(2.2)
    return ms.frozen(ms.fade_tail(x, 0.08))


@functools.lru_cache(maxsize=None)
def snare2(var: int) -> np.ndarray:
    """Layer for the snare: tighter crack, longer brighter gated room and a short plate tail (stereo)."""
    SR = ms.SR
    rng = ms.rng_of("snare2", var)
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    f1 = 196.0 * (1.0 + 0.2 * np.exp(-t / 0.01))
    body = np.sin(2.0 * np.pi * np.cumsum(f1) / SR) * np.exp(-t / 0.085)
    wires = ms.band_noise(rng, n, 1500.0, 11000.0, -0.5) * np.exp(-t / 0.14) * 0.7
    crack = ms.band_noise(rng, n, 2500.0, 14000.0) * np.exp(-t / 0.0035) * 0.9
    dry = np.tanh(1.5 * (body + wires + crack) * (1.0 - np.exp(-t / 0.0003)))
    out = dry[:, None] + ms._gated_room(rng, dry, 0.30, 0.75, 350.0, 9500.0, 0.34)
    tail = np.stack([ms.band_noise(rng, n, 500.0, 7000.0, -1.5) for _ in range(2)], axis=1)
    tail *= (np.exp(-t / 0.22) * (1.0 - np.exp(-t / 0.02)))[:, None]
    env = np.convolve(np.abs(dry), np.ones(64) / 64.0, mode="same")
    out += 0.12 * tail * np.max(env)
    return ms.frozen(ms.fade_tail(out / np.max(np.abs(out)), 0.05))


@functools.lru_cache(maxsize=None)
def shaker(var: int) -> np.ndarray:
    SR = ms.SR
    rng = ms.rng_of("shaker", var)
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    y = ms.band_noise(rng, n, 5200.0, 13500.0) * (1.0 - np.exp(-t / 0.004)) * np.exp(-t / 0.022)
    return ms.frozen(ms.fade_tail(y, 0.01))


@functools.lru_cache(maxsize=None)
def sub_bass(midi: int, dur: float) -> np.ndarray:
    SR = ms.SR
    f = float(ms.mtof(midi))
    while f < 36.0:
        f *= 2.0
    while f > 75.0:
        f *= 0.5
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    y = np.sin(2.0 * np.pi * f * t) + 0.12 * np.sin(4.0 * np.pi * f * t)
    y *= (1.0 - np.exp(-t / 0.006)) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.02))
    return ms.frozen(ms.fade_tail(y, 0.01))


ms.LEAD_PATCHES["super_l"] = {"osc": [("saw", -23.0, 0, 0.3), ("saw", -9.0, 0, 0.3), ("saw", 4.0, 0, 0.3), ("saw", 17.0, 0, 0.3),
                                      ("saw", 0.0, 12, 0.12)], "cut": 5200.0, "glide": 0.03, "vib": 0.12, "att": 0.012,
                              "rel": 0.14, "bright": 0.5}
ms.LEAD_PATCHES["super_r"] = {"osc": [("saw", 21.0, 0, 0.3), ("saw", 8.0, 0, 0.3), ("saw", -5.0, 0, 0.3), ("saw", -16.0, 0, 0.3),
                                      ("saw", 0.0, 12, 0.12)], "cut": 5200.0, "glide": 0.03, "vib": 0.12, "att": 0.012,
                              "rel": 0.14, "bright": 0.5}


# ---------------------------------------------------------------------------------------------------------
# mix
# ---------------------------------------------------------------------------------------------------------
REVERBS2 = {
    "plate": {"ir": ("plate2", 2.6, 0.020, 1.6, 1.2, 10000.0, 0.15), "eq": [("hp", 280.0, 0.7), ("lp", 9000.0, 0.7)]},
    "hall": {"ir": ("hall2", 4.6, 0.045, 3.2, 2.3, 8000.0, 0.2), "eq": [("hp", 200.0, 0.7), ("lp", 8000.0, 0.7)]},
}


def process(x: np.ndarray, spec: dict, duck: np.ndarray | None) -> np.ndarray:
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    if "sat" in spec:
        k = spec["sat"]
        pk = np.max(np.abs(x)) + 1e-12
        x = np.tanh(k * x / pk) / math.tanh(k) * pk
    if spec.get("eq"):
        x = ms.apply_eq(x, spec["eq"])
    if "comp" in spec:
        rel, ratio, att, rls = spec["comp"]
        x = x * ms.compressor_gain(x, ms.integrated_lufs(x) + rel, ratio, att, rls)[:, None]
    if spec.get("chorus"):
        x = ms.chorus(x, mix=spec["chorus"] if isinstance(spec["chorus"], float) else 0.6)
    if "pan" in spec:
        gl, gr = ms.pan_gains(spec["pan"])
        x = np.stack([x[:, 0] * gl, x[:, 1] * gr], axis=1)
    if "duck" in spec and duck is not None:
        x = x * (1.0 - spec["duck"] * (1.0 - duck))[:, None]
    lv = ms.integrated_lufs(x)
    if lv > -150.0:
        x = x * ms.undb(spec["lufs"] - lv)
    return x


def mix2(stems: dict, specs: dict, kick_times: list, n: int, log=print, pump_release: float = 0.17) -> tuple:
    """stems: name -> array; specs: name -> {bus, lufs, eq, sends, duck, ...}. Returns (mix, levels)."""
    buses = {k: np.zeros((n, 2)) for k in ("drums", "inst", "fx")}
    sends = {k: np.zeros((n, 2)) for k in ("plate", "hall", "delay")}
    duck = ms.duck_env(kick_times, n, 1.0, 0.004, 0.02, pump_release)
    levels = {}
    for name, x in stems.items():
        if not np.any(x):
            continue
        spec = specs[name]
        y = process(x[:n] if len(x) >= n else np.pad(x, ((0, n - len(x)), (0, 0)) if x.ndim == 2 else (0, n - len(x))), spec, duck)
        buses[spec["bus"]] += y
        for s, lvl in spec.get("sends", {}).items():
            sends[s] += y * ms.undb(lvl)
        levels[name] = round(ms.integrated_lufs(y), 2)
        if os.environ.get("M2_DEBUG"):
            Y = np.abs(np.fft.rfft(y.mean(axis=1))) ** 2
            ff = np.fft.rfftfreq(len(y), 1.0 / ms.SR)
            tot = np.sum(Y) + 1e-20
            print("    %-10s LUFS %6.1f  rms %6.1f dB  sub(28-56) %6.1f  bass(56-280) %6.1f  >8k %6.1f" % (
                name, levels[name], 10 * math.log10(np.mean(y ** 2) + 1e-20), 10 * math.log10(np.sum(Y[(ff >= 28) & (ff < 56)]) / len(y) ** 2 * 2 + 1e-20),
                10 * math.log10(np.sum(Y[(ff >= 56) & (ff < 280)]) / len(y) ** 2 * 2 + 1e-20), 10 * math.log10(np.sum(Y[ff >= 8000]) / len(y) ** 2 * 2 + 1e-20)))
    d = buses["drums"]
    par = d * ms.compressor_gain(d, ms.integrated_lufs(d) - 2.0, 6.0, 0.003, 0.10)[:, None]
    d = d + 0.5 * ms.undb(4.0) * par
    pk = np.max(np.abs(d)) + 1e-12
    buses["drums"] = np.tanh(1.7 * d / pk) / math.tanh(1.7) * pk          # bus saturation: rounder peaks
    ret = np.zeros((n, 2))
    for name, r in REVERBS2.items():
        ir = np.asarray(ms.reverb_ir(*r["ir"]))
        wet = np.stack([ms.convolve(sends[name][:, c], ir[:, c]) for c in range(2)], axis=1)
        ret += ms.apply_eq(wet, r["eq"])
    dly = np.asarray(ms.pingpong_ir(*ms.DELAY))
    ret += ms.convolve(0.5 * (sends["delay"][:, 0] + sends["delay"][:, 1]), dly)
    return buses["drums"] + buses["inst"] + buses["fx"] + ret, levels


# ---------------------------------------------------------------------------------------------------------
# master
# ---------------------------------------------------------------------------------------------------------
def band_split(x: np.ndarray, edges: list) -> list:
    """Linear-phase band split with raised-cosine crossovers (one octave wide), bands sum to the input."""
    n = len(x)
    X = np.fft.rfft(x, axis=0)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / ms.SR), 1.0)
    lows = []
    for fc in edges:
        z = np.clip(np.log2(f / fc) + 0.5, 0.0, 1.0)
        lows.append(0.5 + 0.5 * np.cos(np.pi * z))          # 1 below fc/sqrt2, 0 above fc*sqrt2
    masks = [lows[0]] + [lows[i] - lows[i - 1] for i in range(1, len(lows))] + [1.0 - lows[-1]]
    return [np.fft.irfft(X * m[:, None], n, axis=0) for m in masks]


MASTER2_EQ = [("hp", 24.0, 0.7), ("ls", 62.0, 1.0), ("peak", 105.0, 0.5, 1.0), ("peak", 520.0, 2.2, 0.55),
              ("peak", 3200.0, 0.5, 0.8), ("hs", 11000.0, 0.0)]


def master2(x: np.ndarray, measure: slice, target: float = -14.0, ceiling: float = -1.0, log=print) -> tuple:
    x = ms.apply_eq(x, MASTER2_EQ)
    # 1. multiband compression (140 Hz / 3.2 kHz)
    bands = band_split(x, [140.0, 3200.0])
    out = np.zeros_like(x)
    info = {}
    for nm, b, (rel_thr, ratio, att, rls) in zip(("low", "mid", "high"), bands,
                                                 ((0.0, 3.0, 0.020, 0.16), (1.0, 2.0, 0.012, 0.14), (0.5, 2.5, 0.004, 0.09))):
        p = np.mean(b[measure] ** 2)
        lvl = 10.0 * math.log10(max(p, 1e-14))
        g = ms.compressor_gain(b, lvl + rel_thr, ratio, att, rls, 6.0)
        gr_avg = float(np.mean(20.0 * np.log10(g[measure])))
        out += b * g[:, None] * ms.undb(-0.6 * gr_avg)
        info["mb_%s_gr_db" % nm] = round(gr_avg, 2)
    x = out
    # 2. glue
    g = ms.compressor_gain(x, ms.integrated_lufs(x[measure]) + 3.0, 2.0, 0.020, 0.25, 6.0)
    x = x * g[:, None]
    # 3. M/S: mono below 120 Hz, more side above 4 kHz
    mid = 0.5 * (x[:, 0] + x[:, 1])
    side = 0.5 * (x[:, 0] - x[:, 1])
    side = ms.apply_eq(side, [("hp", 120.0, 0.7071), ("hs", 4000.0, 2.0)]) * ms.undb(1.0)
    x = np.stack([mid + side, mid - side], axis=1)
    # 4. loudness with soft clip + true-peak limiter
    gain = ms.undb(target - ms.integrated_lufs(x[measure]))
    for it in range(8):
        y = x * gain
        knee = ms.undb(ceiling - 5.0)
        over = np.abs(y) > knee
        y = np.where(over, np.sign(y) * (knee + (1.0 - knee) * np.tanh((np.abs(y) - knee) / (1.0 - knee))), y)
        y, gr = ms.limiter(y, ceiling - 0.7)
        lv = ms.integrated_lufs(y[measure])
        if abs(lv - target) < 0.03:
            break
        gain *= ms.undb(target - lv)
    info.update({"glue_gr_db": round(float(ms.db(g.min())), 2), "limiter_gr_db": round(float(gr.min()), 2), "lufs": round(lv, 2)})
    log("  Master2: " + ", ".join("%s %s" % kv for kv in info.items()))
    return y, info
