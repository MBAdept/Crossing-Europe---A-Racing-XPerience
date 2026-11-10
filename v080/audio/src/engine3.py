#!/usr/bin/env python3
"""v0.8.0 audio study, spike 1: prototype of the proposed "modern" engine/vehicle sound, rendered offline from
the frame trace of a scripted drive (the same drive the real game played for the "old" recording).

Everything here is something the game runtime could do: a stereo cycle bank played cycle-synchronously (as
EngineAudio does today, two channels), control-rate modulation, clips, and loop layers that Godot would mix
natively (turbo, driveline, tyres, wind) with pitch/level laws. Scratch prototype - not part of the repo.
"""
from __future__ import annotations
import csv, math, os, sys
import numpy as np
import alib
from bankio import Bank

SR = 48000


# ---------------------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------------------
def smooth_ar(x: np.ndarray, up_s: float, down_s: float, sr: float) -> np.ndarray:
    au = 1.0 - math.exp(-1.0 / (up_s * sr))
    ad = 1.0 - math.exp(-1.0 / (down_s * sr))
    y = np.empty_like(x)
    acc = float(x[0])
    for i in range(len(x)):
        v = x[i]
        acc += (v - acc) * (au if v > acc else ad)
        y[i] = acc
    return y


def shaped_noise(rng, n: int, gain_fn, sr: int = SR) -> np.ndarray:
    nn = 1 << int(math.ceil(math.log2(max(n, 2))))
    X = np.fft.rfft(rng.standard_normal(nn))
    f = np.fft.rfftfreq(nn, 1.0 / sr)
    y = np.fft.irfft(X * gain_fn(np.maximum(f, 1e-3)), nn)[:n]
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def bp(f, lo, hi, order=2):
    return (1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order))) * (1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order)))


def peak(f, f0, q, gain_db):
    g = 10 ** (gain_db / 20.0)
    x = (f / f0 - f0 / f) * q
    return 1.0 + (g - 1.0) / (1.0 + x * x)


def slow_noise(rng, n: int, lo: float, hi: float, sr: int = SR) -> np.ndarray:
    """Band-limited control noise (unit std), generated at 200 Hz and interpolated."""
    m = int(n / sr * 200) + 8
    x = shaped_noise(rng, m, lambda f: bp(f, lo, hi, 1) / np.sqrt(f), 200)
    return np.interp(np.arange(n) / sr, np.arange(m) / 200.0, x)


def place(out: np.ndarray, clip: np.ndarray, at: int, gain=1.0, pan: float | None = None) -> None:
    if at >= len(out) or at + len(clip) <= 0:
        return
    a = max(at, 0)
    c = clip[a - at:]
    m = min(len(c), len(out) - a)
    if m <= 0:
        return
    if c.ndim == 1:
        if pan is None:
            out[a:a + m] += c[:m, None] * gain
        else:
            ang = (pan + 1.0) * math.pi / 4.0
            out[a:a + m, 0] += c[:m] * gain * math.cos(ang) * math.sqrt(2.0)
            out[a:a + m, 1] += c[:m] * gain * math.sin(ang) * math.sqrt(2.0)
    else:
        out[a:a + m] += c[:m] * gain


def varispeed(loop: np.ndarray, rate: np.ndarray, start: float = 0.0) -> np.ndarray:
    """Reads a seamless loop with a time-varying rate (linear interpolation) - what pitch_scale does."""
    n = len(loop)
    ph = (start + np.cumsum(rate) - rate) % n
    i = np.floor(ph).astype(int)
    fr = ph - i
    return loop[i] * (1.0 - fr) + loop[(i + 1) % n] * fr


def lookahead_limiter(x: np.ndarray, ceiling_db: float = -0.8, look_s: float = 0.002, rel_s: float = 0.12) -> np.ndarray:
    ceil = 10 ** (ceiling_db / 20.0)
    pk = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    w = int(look_s * SR)
    # running minimum over the lookahead window, then release smoothing
    m = need.copy()
    for k in range(1, w + 1):
        m[:-k] = np.minimum(m[:-k], need[k:])
    g = np.empty_like(m)
    acc = 1.0
    a = 1.0 - math.exp(-1.0 / (rel_s * SR))
    for i in range(len(m)):
        acc = m[i] if m[i] < acc else acc + (1.0 - acc) * a
        g[i] = acc
    return x * g[:, None]


# ---------------------------------------------------------------------------------------------------------
# trace
# ---------------------------------------------------------------------------------------------------------
class Trace:
    def __init__(self, path: str):
        rows = list(csv.DictReader(open(path)))
        self.t = np.array([float(r["t"]) for r in rows])
        self.speed = np.array([float(r["speed_kmh"]) for r in rows])
        self.thr = np.array([float(r["throttle"]) for r in rows])
        self.rpm = np.array([float(r["rpm"]) for r in rows])
        self.gear = np.array([int(r["gear"]) for r in rows])
        self.load = np.array([float(r["load"]) for r in rows])
        self.boost = np.array([float(r["boost"]) for r in rows])
        self.phase = [r["phase"] for r in rows]
        self.dur = float(self.t[-1] + (self.t[1] - self.t[0]))

    def at(self, arr: np.ndarray, ta: np.ndarray, hold: bool = False) -> np.ndarray:
        if hold:
            idx = np.clip(np.searchsorted(self.t, ta, side="right") - 1, 0, len(arr) - 1)
            return arr[idx].astype(float)
        return np.interp(ta, self.t, arr)

    def phase_time(self, name: str, which: int = 0) -> tuple:
        idx = [i for i, p in enumerate(self.phase) if p == name]
        if not idx:
            return (0.0, 0.0)
        runs = []
        s = idx[0]
        for a, b in zip(idx, idx[1:] + [None]):
            if b is None or b != a + 1:
                runs.append((self.t[s], self.t[a] + (self.t[1] - self.t[0])))
                s = b
        return runs[min(which, len(runs) - 1)]


# ---------------------------------------------------------------------------------------------------------
# cycle player (EngineAudio's algorithm, n channels) with per-cycle gain jitter
# ---------------------------------------------------------------------------------------------------------
class CyclePlayer:
    def __init__(self, bank: Bank, seed: int = 7, cycle_jitter_db: float = 0.0):
        self.b = bank
        self.rng = np.random.default_rng(seed)
        self.phase = 0.0
        self.var = {}
        for key, s in bank.src.items():
            nv = len(s["cycles"])
            a = int(self.rng.integers(nv))
            self.var[key] = [a, (a + 1) % nv]
        self.jit = cycle_jitter_db
        self.cyc_gain = [1.0, 1.0]            # previous, current cycle
        self.boundaries: list = []

    def _new_cycle(self):
        for key, st in self.var.items():
            nv = len(self.b.src[key]["cycles"])
            prev = st[1]
            nxt = int(self.rng.integers(nv - 1))
            if nxt >= prev:
                nxt += 1
            st[0], st[1] = prev, nxt
        self.cyc_gain = [self.cyc_gain[1], 10 ** (self.jit * float(self.rng.standard_normal()) / 20.0) if self.jit else 1.0]

    def _read(self, key, ph: np.ndarray) -> np.ndarray:
        s = self.b.src[key]
        prev_c = s["cycles"][self.var[key][0]]
        cur_c = s["cycles"][self.var[key][1]]
        pos = ph * s["period"]
        i = np.floor(pos).astype(int)
        fr = (pos - i)[:, None]
        x = (cur_c[i] * (1.0 - fr) + cur_c[np.minimum(i + 1, len(cur_c) - 1)] * fr) * self.cyc_gain[1]
        ov = s["overlap"]
        m = pos < ov
        if np.any(m):
            pp = pos[m] + s["period"]
            j = np.floor(pp).astype(int)
            fj = (pp - j)[:, None]
            last = len(prev_c) - 1
            xp = (prev_c[np.minimum(j, last)] * (1.0 - fj) + prev_c[np.minimum(j + 1, last)] * fj) * self.cyc_gain[0]
            w = (pos[m] / ov)[:, None]
            w = w * w * (3.0 - 2.0 * w)
            x[m] = (1.0 - w) * xp + w * x[m]
        return x

    def render(self, rpm: np.ndarray, load: np.ndarray, on_gain: np.ndarray | None = None) -> np.ndarray:
        b = self.b
        n = len(rpm)
        y = np.zeros((n, b.ch))
        nb = len(b.rpms)
        gain = float(b.mix.get("gain", 1.0))
        off_gain = float(b.mix.get("off_gain", 1.0))
        lrpm = np.log(b.rpms)
        pos = 0
        while pos < n:
            chunk = min(n - pos, 16384)
            inc = rpm[pos:pos + chunk] / (120.0 * b.sr)
            cum = self.phase + np.cumsum(inc) - inc
            k = int(np.searchsorted(cum, 1.0))
            seg = min(k, chunk)
            ph = np.minimum(cum[:seg], 0.999999)
            r = np.clip(rpm[pos:pos + seg], b.rpms[0], b.rpms[-1])
            ld = np.clip(load[pos:pos + seg], 0.0, 1.0)
            lr = np.log(r)
            i0 = np.clip(np.searchsorted(b.rpms, r) - 1, 0, nb - 2)
            alpha = np.clip((lr - lrpm[i0]) / (lrpm[i0 + 1] - lrpm[i0]), 0.0, 1.0)
            w_on = np.sin(0.5 * np.pi * ld)
            if on_gain is not None:
                w_on = w_on * on_gain[pos:pos + seg]
            w_off = np.cos(0.5 * np.pi * ld) * off_gain
            out = np.zeros((seg, b.ch))
            for i in np.unique(np.concatenate([i0, i0 + 1])):
                wi = np.where(i0 == i, 1.0 - alpha, 0.0) + np.where(i0 + 1 == i, alpha, 0.0)
                if not np.any(wi > 0.0):
                    continue
                out += (wi * w_on)[:, None] * self._read((i, "on"), ph) + (wi * w_off)[:, None] * self._read((i, "off"), ph)
            y[pos:pos + seg] = gain * out
            pos += seg
            nxt = cum[k] if k < chunk else cum[-1] + inc[-1]
            if nxt < 1.0:
                self.phase = nxt
                continue
            self.phase = nxt - 1.0
            self._new_cycle()
            self.boundaries.append(pos)
        return y
