#!/usr/bin/env python3
"""Motor v3 - offline synthesis of the engine sounds of the profile "Modern" (v0.8.0, package AU-B; contract D27,
docs/motorsound.md section "Modern").

Per car a stereo cycle bank (format "ce-engine-bank-2": <car>.json + <car>.i16, raw interleaved int16 at 32 kHz
stereo) for scripts/audio/modern/engine_bank2.gd, and the natively mixed sounds of the car itself (turbo tones and
hiss, driveline whine, tip-in, shift thump, blow-off; 16-bit WAV at 44.1 kHz) for
scripts/audio/modern/vehicle_layers.gd.

The physical model is the one of the Arcade banks: tools/audio/engine_synth.py is imported, never edited (its
profiles, 0-D gas exchange, exhaust and intake networks, mechanics). What this tool adds:

  * three layers per rpm point instead of two loads:
      "off"  closed throttle - everything the engine does on overrun and at idle (stereo)
      "on"   full load WITHOUT induction: exhaust pulses, valve rasp, tailpipe jet, mechanics, knock (stereo)
      "in"   full-throttle induction alone: intake pulses and compressor whoosh (mono)
    The runtime moves "in" with the pedal and "on"/"off" with the engine load, so intake and exhaust are separate
    voices of one cycle-synchronous mixer (same cycle start, no phasing between them).
  * stereo from one listener point (mono compatible): constant-power panning per tailpipe (V8), per cylinder bank
    (boxer) or centred (inline engines), flow noise (rasp, jet, hiss) with an independent share per channel.
    The channels of every bank are levelled against each other (the long-term balance is 0 dB by construction).
  * a "modern" retune per car (CHAR): more flow noise and steepening, per-car width, saturation and loudness.
  * levels: every bank is shaped to a target curve in K-weighted loudness (relative to the car's full load), so
    that the loudness plan (full throttle / cruise / idle) falls out of the bank; each bank is stored at full
    16-bit scale with its own "gain".
  * measured helpers for the runtime: correlation with the neighbouring rpm point ("xrpm") and between the loads
    ("xload") - the mixer keeps the power constant while it blends.
  * clips: 12 crackles, shift cracks, the start clip (the Arcade generators, panned; the Gran Turismo's bangs carry
    a distant echo).

    python3 tools/audio/modern/engine_synth3.py                 all five cars and the vehicle sounds into the repo
    python3 tools/audio/modern/engine_synth3.py --out DIR       the same below DIR (no Godot import files)
    python3 tools/audio/modern/engine_synth3.py --car kombi --only banks --jobs 1
    python3 tools/audio/modern/engine_synth3.py --info          rpm points and sizes, nothing rendered
Deterministic (fixed seeds per car / bank / channel); about 25 s per car, two cars at a time by default.
After a run into the repository: godot --headless --path . --import (completes the .import files of the WAVs).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modern_lib as ml  # noqa: E402  (puts tools/audio and tools/audio/qc on sys.path)
import engine_synth as es  # noqa: E402  (frozen Arcade tool: imported, never edited)
import qc_lib  # noqa: E402

GENERATOR = "tools/audio/modern/engine_synth3.py"
FORMAT = "ce-engine-bank-2"
SR = es.SR                       # 32 kHz, the bank rate
OVERLAP = es.OVERLAP             # 128 frames of continuation after each cycle
N_VAR = 8                        # cycle variants of "off" and "on"
N_VAR_ON_LOW = 4                 # ... of "on" below ON_LOW_X (only heard blended: idle share, launch)
ON_LOW_X = 1.35                  # x idle rpm
N_VAR_IN = 4                     # mono variants of "in", two per stereo block
FILE_PEAK = 0.84                 # every bank is stored with this sample peak (its "gain" restores the level)
REF_PEAK = 0.708                 # designed peak of the full-load bank at the reference rpm (before mix.gain)
PAN_REF_X = 0.9                  # a source this far off the centre line (m) gets the full pan
INTERNAL_LUFS = -18.0            # designed full-load loudness of the Gran Turismo inside the mixer (before the bus)
CARS = list(es.CARS)
MODE_ST, MODE_L, MODE_R = 0, 1, 2

# ------------------------------------------------------------------------------------------------------------------
# Character table of the five engines (audio study of v0.8.0): what makes each car its own in the Modern profile.
#   retune   dB on top of the calibrated component levels of the Arcade profile (flow noise, induction, mechanics)
#   nl       factor on the steepening of strong exhaust pulses (brightness under load)
#   pan      "centre" (one exhaust image), "tailpipe" (each pipe at its place), "group" (each cylinder bank a side)
#   width    pan width of the exhaust image; noise = independent share of the flow noise per channel (0..1)
#   on / off target loudness of the banks in dB re the car's full load over x = (rpm - idle) / (redline - idle)
#   loudness full-throttle loudness of the car relative to the plan's target (all five stay within +-1.5 dB)
#   runtime  parameters the mixer and the vehicle layers read from the bank ("layers" / "mix")
# ------------------------------------------------------------------------------------------------------------------
ON_CURVE = [(0.0, -7.5), (0.12, -5.5), (0.28, -3.2), (0.5, -1.2), (0.7, -0.3), (0.85, 0.0), (1.0, 0.3), (1.2, 0.3)]
OFF_CURVE = [(0.0, -8.6), (0.12, -9.6), (0.28, -9.0), (0.5, -8.4), (0.75, -7.4), (1.0, -6.4), (1.2, -6.4)]

CHAR: dict = {
    "kompakt": {
        "retune": {"rasp": 4.0, "jet": 5.0, "intake": 4.0, "whoosh": 5.0, "mech": 2.0, "hiss": 3.0},
        "nl": 1.5, "pan": "centre", "width": 0.0, "noise": 0.55, "clip_pan": 0.25,
        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.2,
        "mix": {"in_gain": 1.0, "idle_load": 0.2},
        "saturation": 1.0, "turbo_depth": 0.25,
        "turbo": {"tone": "turbo_single", "tone_level": 0.060, "hiss_level": 0.030},
        "blowoff": {"sound": "blowoff_hatch"},
        "driveline": {"fd_level": 0.011, "gm_level": 0.008},
        "tipin": {"level": 0.9}, "thump": {"level": 0.8}, "limiter_pop": 0.35,
    },
    "kombi": {
        "retune": {"rasp": 2.0, "jet": 3.0, "intake": 3.0, "whoosh": 6.0, "mech": 2.0, "knock": 1.0},
        "nl": 1.3, "pan": "centre", "width": 0.0, "noise": 0.5, "clip_pan": 0.0,
        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -1.0,
        "mix": {"in_gain": 1.0, "idle_load": 0.25},
        "saturation": 0.5, "turbo_depth": 0.3,
        "turbo": {"tone": "turbo_single", "tone_level": 0.050, "hiss_level": 0.045},
        "blowoff": None,
        "driveline": {"fd_level": 0.012, "gm_level": 0.006},
        "tipin": {"level": 0.7}, "thump": {"level": 1.0}, "limiter_pop": 0.0,
    },
    "limousine": {
        "retune": {"rasp": 2.5, "jet": 4.0, "intake": 3.0, "whoosh": 3.0, "mech": 1.0, "hiss": 2.0},
        "nl": 1.25, "pan": "centre", "width": 0.0, "noise": 0.4, "clip_pan": 0.5,
        "on": ON_CURVE, "off": OFF_CURVE, "loudness": -0.5,
        "mix": {"in_gain": 0.9, "idle_load": 0.2},
        "saturation": 0.6, "turbo_depth": 0.2,
        "turbo": {"tone": "turbo_single", "tone_level": 0.022, "hiss_level": 0.020},
        "blowoff": {"sound": "blowoff_soft"},
        "driveline": {"fd_level": 0.008, "gm_level": 0.005},
        "tipin": {"level": 0.6}, "thump": {"level": 0.6}, "limiter_pop": 0.0,
    },
    "sportwagen": {
        "retune": {"rasp": 4.0, "jet": 5.0, "intake": 6.0, "whoosh": 3.0, "mech": 3.0, "hiss": 3.0},
        "nl": 1.5, "pan": "group", "width": 0.55, "noise": 0.8, "clip_pan": 0.45,
        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.5,
        "mix": {"in_gain": 1.15, "idle_load": 0.2},
        "saturation": 1.35, "turbo_depth": 0.0,
        "turbo": None, "blowoff": None,
        "driveline": {"fd_level": 0.012, "gm_level": 0.012},
        "tipin": {"level": 1.0}, "thump": {"level": 0.9}, "limiter_pop": 0.5,
    },
    "gran_turismo": {
        "retune": {"rasp": 4.0, "jet": 6.0, "intake": 5.0, "whoosh": 5.0, "mech": 2.0, "hiss": 3.0},
        "nl": 1.5, "pan": "tailpipe", "width": 0.62, "noise": 0.8, "clip_pan": 0.0,
        "on": ON_CURVE, "off": OFF_CURVE, "loudness": 0.8,
        "mix": {"in_gain": 1.0, "idle_load": 0.2},
        "saturation": 1.25, "turbo_depth": 0.25,
        "turbo": {"tone": "turbo_twin", "tone_level": 0.036, "hiss_level": 0.030},
        "blowoff": {"sound": "blowoff_gt"},
        "driveline": {"fd_level": 0.012, "gm_level": 0.008},
        "tipin": {"level": 1.0}, "thump": {"level": 1.0}, "limiter_pop": 0.5,
    },
}

# ------------------------------------------------------------------------------------------------------------------
# Stereo: the listener path of the frozen model, panned for the channel that is being rendered
# ------------------------------------------------------------------------------------------------------------------
_CH = {"ch": 0, "width": 0.0}
_orig_listener_path = es.listener_path


def pan_gains(pan: float) -> tuple:
    """Constant-power pan (-1 left .. +1 right): gains of the left and right channel; (1, 1) in the centre."""
    a = (float(np.clip(pan, -1.0, 1.0)) + 1.0) * math.pi / 4.0
    return math.sqrt(2.0) * math.cos(a), math.sqrt(2.0) * math.sin(a)


def _listener_path_panned(f, pos, shadow=None):
    g, r1 = _orig_listener_path(f, pos, shadow)
    ch = _CH["ch"]
    if ch != 0:
        gl, gr = pan_gains(float(np.clip(pos[0] / PAN_REF_X, -1.0, 1.0)) * _CH["width"])
        g = g * (gl if ch < 0 else gr)
    return g, r1


es.listener_path = _listener_path_panned


class Chan:
    """Context: models built and transfer functions solved inside belong to this channel (-1 left, +1 right, 0 none)."""

    def __init__(self, ch: int, width: float = 0.0):
        self.ch, self.width = ch, width

    def __enter__(self):
        self.prev = dict(_CH)
        _CH["ch"], _CH["width"] = self.ch, self.width

    def __exit__(self, *a):
        _CH.update(self.prev)


def _hp(y: np.ndarray, fc: float = 22.0) -> np.ndarray:
    return es.spectral_filter(y, lambda f: es.highpass_gain(f, fc, 2))


def kpow(x: np.ndarray) -> float:
    """K-weighted mean power of a mono signal at the bank rate (the measure of the frozen tool)."""
    return es.k_weighted_power(np.asarray(x, float))


def lufs_st(y: np.ndarray) -> float:
    """Loudness of a steady stereo signal (frames, 2): BS.1770 without gating."""
    return -0.691 + 10.0 * math.log10(max(kpow(y[:, 0]) + kpow(y[:, 1]), 1e-20))


class StereoCar:
    """The physical model of one car for both channels: a centre model (calibration, sources, mono components) and,
    for the pan mode "tailpipe", one model per channel whose exhaust network is solved with the pan of each pipe."""

    def __init__(self, car: str):
        self.car = car
        self.prof = es.PROFILES[car]
        self.ch = CHAR[car]
        self.mode = self.ch["pan"]
        with Chan(0):
            self.mc = es.CarModel(car)
            self.mc.op = dict(self.mc.op, nl=self.mc.op["nl"] * self.ch["nl"])
            self.mc.calibrate()
        self.k = dict(self.mc.cal["k"])
        for comp, d in self.ch["retune"].items():
            if comp in self.k:
                self.k[comp] *= 10.0 ** (d / 20.0)
        self.side = {}
        if self.mode == "tailpipe":
            for c in (-1, 1):
                with Chan(c, self.ch["width"]):
                    m = es.CarModel(car)
                    m.op = dict(self.mc.op)
                    m.cal = dict(self.mc.cal, k=self.k)
                    self.side[c] = m
        # cylinder bank -> pan (mode "group"): bank a to the left, b to the right
        self.group_pan = {"a": -self.ch["width"], "b": self.ch["width"]}
        self.rho = math.sqrt(max(1.0 - self.ch["noise"] ** 2, 0.0))   # common share of the flow noise

    # --- helpers -------------------------------------------------------------------------------------------
    def _tf(self, c: int, T_hdr: float) -> dict:
        if self.mode == "tailpipe":
            with Chan(c, self.ch["width"]):
                return self.side[c].exhaust_tf(T_hdr)
        return self.mc.exhaust_tf(T_hdr)

    def _through_exhaust(self, srcs: list, T_hdr: float, n_len: int, key: str = "h", per_ch: list | None = None) -> np.ndarray:
        """Sources at the exhaust ports (or crackle nodes) -> stereo signal at the listener. srcs: one array per
        port (None = silent); per_ch: optional [left sources, right sources] (independent noise per channel)."""
        out = np.zeros((n_len, 2))
        sl = per_ch if per_ch is not None else [srcs, srcs]
        if self.mode == "group" and key == "h":
            cyls = self.mc.cyls
            for g, pan in self.group_pan.items():
                gl, gr = pan_gains(pan)
                for c, gain in ((0, gl), (1, gr)):
                    sel = [x if self.mc.geo["groups"][k] == g else None for k, x in zip(cyls, sl[c])]
                    out[:, c] += gain * es.fft_convolve_sum(sel, self.mc.exhaust_tf(T_hdr)[key], n_len)
            return out
        for c, chn in ((0, -1), (1, 1)):
            out[:, c] = es.fft_convolve_sum(sl[c], self._tf(chn, T_hdr)[key], n_len)
        return out

    def _pair(self, rng_l, rng_r, n: int, lo: float, hi: float, slope: float) -> tuple:
        """Two noise signals with the car's common share (rho) and an independent share per channel."""
        a = es.band_noise(rng_l, n, lo, hi, slope)
        b = es.band_noise(rng_r, n, lo, hi, slope)
        w = self.ch["noise"]
        return a, self.rho * a + w * b

    # --- components ----------------------------------------------------------------------------------------
    def components(self, ev: dict, opp: dict, n_len: int, seed: int) -> dict:
        """Every sound component of es.CarModel.render_components for the given events, as stereo signals
        (n_len, 2) at the listener - same formulas, the sources computed once for both channels."""
        mc = self.mc
        cal = mc.cal
        tf = mc.exhaust_tf(opp["T_hdr"])
        T = opp["T_hdr"]
        rng_l = np.random.default_rng(es.seed_of(seed, "L"))
        rng_r = np.random.default_rng(es.seed_of(seed, "R"))
        rng_m = np.random.default_rng(es.seed_of(seed, "M"))
        parts = {}
        q = mc.exhaust_sources(ev, opp, tf, n_len)
        parts["exh"] = self._through_exhaust(q, T, n_len)
        # valve flow noise (rasp)
        nl_, nr_ = [], []
        for x in q:
            env = (np.maximum(x, 0.0) / cal["q_ref"]) ** 1.5
            a, b = self._pair(rng_l, rng_r, n_len, 350.0, 9000.0, -1.5)
            nl_.append(a * env)
            nr_.append(b * env)
        parts["rasp"] = self._through_exhaust(None, T, n_len, per_ch=[nl_, nr_])
        # tailpipe jet noise, driven by the pulsating exit velocity of the whole exhaust (mono sum)
        y = 0.5 * (parts["exh"][:, 0] + parts["exh"][:, 1])
        nn = es.fft_size(n_len + 4096)
        f = np.fft.rfftfreq(nn, 1.0 / SR)
        u_ac = np.fft.irfft(np.fft.rfft(y, nn) / (2j * np.pi * f + 2.0 * np.pi * 12.0), nn)[:n_len]
        u_ac *= 4.0 * np.pi * mc.tail_r / es.RHO_AIR / mc.tail_area
        v = np.maximum(opp["v_tail"] + u_ac, 0.0)
        fpk = float(np.clip(0.25 * max(opp["v_tail"], 5.0) / mc.tail_d, 120.0, 2500.0))
        a, b = self._pair(rng_l, rng_r, n_len, 0.5 * fpk, 10.0 * fpk, -1.0)
        drive = (v / cal["v_ref"]) ** 2.0
        parts["jet"] = np.stack([a * drive, b * drive], axis=1)
        # induction (centre): pulses, throttle hiss on overrun, compressor whoosh
        itf = mc.intake_tf(opp["load"])
        x = es.fft_convolve_sum(mc.intake_sources(ev, opp, n_len), itf["h"], n_len)
        parts["intake"] = np.stack([x, x], axis=1)
        hs = opp["hiss"] * (0.25 + 0.75 * (1.0 - opp["fire"])) * (0.6 + 0.4 * opp["rpm"] / mc.eng["redline_rpm"])
        a, b = self._pair(rng_l, rng_r, n_len, 1400.0, 7500.0, 0.0)
        parts["hiss"] = np.stack([es.fft_convolve_sum([a * hs], [itf["h_hiss"]], n_len),
                                  es.fft_convolve_sum([b * hs], [itf["h_hiss"]], n_len)], axis=1)
        wh = (opp["air"] * opp["rpm"] / cal["air_ref"]) ** 2 * (1.0 if opp["load"] == "on" else 0.15)
        x = es.fft_convolve_sum([es.band_noise(rng_m, n_len, 250.0, 5000.0, -2.0) * wh], [itf["h_whoosh"]], n_len)
        parts["whoosh"] = np.stack([x, x], axis=1)
        # mechanics (centre; the valve train of a boxer comes from its two banks)
        for name, src in mc.mech_sources(ev, opp, n_len, rng_m).items():
            x = es.fft_convolve_sum([src], [mc.mech_full[name]], n_len)
            parts[name] = np.stack([x, x], axis=1)
        if self.mode == "group":
            st = np.zeros((n_len, 2))
            for g, pan in self.group_pan.items():
                sel = np.array([mc.geo["groups"][k] == g for k in ev["cyl"]])
                sub = {kk: (vv[sel] if isinstance(vv, np.ndarray) and len(vv) == len(sel) else vv) for kk, vv in ev.items()}
                src = mc.mech_sources(sub, opp, n_len, np.random.default_rng(es.seed_of(seed, "mech", g)))["mech"]
                x = es.fft_convolve_sum([src], [mc.mech_full["mech"]], n_len)
                gl, gr = pan_gains(0.6 * pan)
                st[:, 0] += gl * x
                st[:, 1] += gr * x
            parts["mech"] = st
        return parts

    def layer(self, parts: dict, names) -> np.ndarray:
        y = np.zeros_like(parts["exh"])
        for c in names:
            if c in parts and self.k.get(c, 0.0) != 0.0:
                y += self.k[c] * parts[c]
        return np.stack([_hp(y[:, 0]), _hp(y[:, 1])], axis=1)

    # --- steady banks --------------------------------------------------------------------------------------
    def render_point(self, period: int) -> dict:
        """One rpm point: the steady signals of the three layers, cut at the cycle starts.
        Returns {"off": [cycles (P + OVERLAP, 2)], "on": [...], "in": [mono cycles], "rpm", "delay_ms"}."""
        mc = self.mc
        rpm = 120.0 * SR / period
        out = {"rpm": rpm, "period": period}
        n_warm = int(math.ceil(0.30 * SR / period)) + 1
        n_total = n_warm + N_VAR + 1
        n_len = n_total * period + OVERLAP + 16
        a0 = n_warm * period
        for load in ("off", "on"):
            opp = mc.operating_point(rpm, load)
            tf = mc.exhaust_tf(opp["T_hdr"])
            ev = mc.steady_events(opp, n_total, tf["D"], np.random.default_rng(es.seed_of(self.car, period, load)))
            parts = self.components(ev, opp, n_len, es.seed_of(self.car, period, load, "noise3"))
            out["delay_ms_" + load] = tf["D"] * 1000.0
            if load == "off":
                ys = {"off": self.layer(parts, es.COMPONENTS)}
            else:
                ys = {"on": self.layer(parts, [c for c in es.COMPONENTS if c not in ("intake", "whoosh", "hiss")]),
                      "in": self.layer(parts, ["intake", "whoosh"])}
            for name, y in ys.items():
                cyc = []
                for i in range(N_VAR):
                    c = y[a0 + i * period:a0 + i * period + period + OVERLAP].copy()
                    c -= np.mean(c[:period], axis=0)      # no DC per cycle (random variants would wobble)
                    cyc.append(c)
                out[name] = cyc
        out["in"] = [c[:, 0].copy() for c in out["in"][:N_VAR_IN]]
        if rpm < ON_LOW_X * mc.eng["idle_rpm"]:
            out["on"] = out["on"][:N_VAR_ON_LOW]
        return out


# ------------------------------------------------------------------------------------------------------------------
# Levels
# ------------------------------------------------------------------------------------------------------------------
def steady(cycles: list, period: int) -> np.ndarray:
    return np.concatenate([c[:period] for c in cycles], axis=0)


def balance_channels(cycles: list, period: int) -> float:
    """Levels the two channels of a bank against each other (K-weighted power over all variants); returns the
    correction applied to the right channel in dB."""
    y = steady(cycles, period)
    pl, pr = kpow(y[:, 0]), kpow(y[:, 1])
    if pl <= 0.0 or pr <= 0.0:
        return 0.0
    g = (pl / pr) ** 0.25          # half of the difference to each side
    for c in cycles:
        c[:, 0] /= g
        c[:, 1] *= g
    return 20.0 * math.log10(g) * 2.0


def curve(table, x: float) -> float:
    return float(np.interp(x, [a for a, _ in table], [b for _, b in table]))


def mean_cycle(cycles: list, period: int, n: int = 2048) -> np.ndarray:
    """Mean over the variants, resampled to n points per cycle (per channel)."""
    m = np.mean([c[:period] for c in cycles], axis=0)
    m = m[:, None] if m.ndim == 1 else m
    xs = np.arange(n) * (period / n)
    return np.stack([np.interp(xs, np.arange(period), m[:, c], period=period) for c in range(m.shape[1])], axis=1)


def coherence(ca: list, pa: int, cb: list, pb: int) -> float:
    """Correlation that decides the power of a blend of two banks whose variants are picked independently:
    <mean cycle A, mean cycle B> / sqrt(mean power A x mean power B), both stretched to the same cycle length."""
    ma, mb = mean_cycle(ca, pa), mean_cycle(cb, pb)
    if ma.shape[1] != mb.shape[1]:
        mb = np.repeat(mb, ma.shape[1], axis=1) if mb.shape[1] == 1 else mb
        ma = np.repeat(ma, mb.shape[1], axis=1) if ma.shape[1] == 1 else ma
    pwa = float(np.mean([np.mean(c[:pa] ** 2) for c in ca]))
    pwb = float(np.mean([np.mean(c[:pb] ** 2) for c in cb]))
    if pwa <= 0.0 or pwb <= 0.0:
        return 0.0
    return float(np.mean(ma * mb) / math.sqrt(pwa * pwb))


def saturate(x: np.ndarray, drive: float) -> np.ndarray:
    """The load-dependent saturation of the runtime mixer (engine_mix_thread.gd), for the level calibration."""
    bias = 0.10 * (drive - 1.0)
    return (np.tanh(x * drive + bias) - math.tanh(bias)) / drive ** 0.55


# ------------------------------------------------------------------------------------------------------------------
# Clips
# ------------------------------------------------------------------------------------------------------------------
def _trim_st(st: np.ndarray, floor_db: float = -50.0, max_s: float = 0.0) -> np.ndarray:
    """es._trim_clip for a stereo clip (the same cut for both channels)."""
    env = np.max(np.abs(st), axis=1)
    first = max(int(np.argmax(env > env.max() * 0.01)) - int(0.002 * SR), 0)
    last = len(env) - int(np.argmax(env[::-1] > env.max() * 10.0 ** (floor_db / 20.0)))
    if max_s:
        last = min(last, first + int(max_s * SR))
    st = st[first:last].copy()
    fade = max(16, min(len(st) // 4, int(0.02 * SR)))
    st[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    st[:16] *= np.linspace(0.0, 1.0, 16)[:, None]
    return st


def _lowpass(x: np.ndarray, fc: float) -> np.ndarray:
    n = es.fft_size(len(x) + 1024)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x, n, axis=0) / (1.0 + (f / fc) ** 2)[:, None], n, axis=0)[:len(x)]


def add_echo(st: np.ndarray) -> np.ndarray:
    """The distant slap of a bang (Gran Turismo): two low-passed echoes from the surroundings, the second one with
    the sides swapped."""
    taps = ((0.187, False, -19.0), (0.311, True, -25.0))
    n = len(st) + int(0.36 * SR)
    out = np.zeros((n, 2))
    out[:len(st)] = st
    src = _lowpass(st, 2500.0)
    for d_s, flip, g_db in taps:
        d = int(d_s * SR)
        out[d:d + len(st)] += (src[:, ::-1] if flip else src) * 10.0 ** (g_db / 20.0)
    fade = int(0.03 * SR)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    return out


class Clips:
    """Crackles, shift cracks and the start clip of a car: the generators of the frozen tool, run once per channel
    with the same seeds (pan mode "tailpipe": every afterfire sits at its muffler) or once in mono."""

    def __init__(self, sc: StereoCar):
        self.sc = sc
        self.mono = None
        if sc.mode != "tailpipe":
            self.mono = es.CarModel(sc.car)
            self.mono.op = dict(sc.mc.op)
            self.mono.cal = dict(sc.mc.cal, k=sc.k)
            self.mono._tf_cache = sc.mc._tf_cache      # same networks, solved once

    def _run(self, fn, *args) -> list:
        """A clip generator -> list of raw clips; stereo arrays for "tailpipe", mono arrays otherwise."""
        orig = es._trim_clip
        es._trim_clip = lambda y, floor_db=-50.0, max_s=0.0: y
        try:
            if self.sc.mode == "tailpipe":
                raw = []
                for c in (-1, 1):
                    with Chan(c, self.sc.ch["width"]):
                        r = fn(self.sc.side[c], *args)
                        raw.append(r if isinstance(r, list) else [r])
                return [np.stack([l, r], axis=1) for l, r in zip(raw[0], raw[1])]
            r = fn(self.mono, *args)
            return r if isinstance(r, list) else [r]
        finally:
            es._trim_clip = orig

    @staticmethod
    def _as_st(c: np.ndarray) -> np.ndarray:
        return c if c.ndim == 2 else np.stack([c, c], axis=1)

    def build(self, idle_rms: float, log) -> dict:
        cs = self.sc.prof["clips"]
        out: dict = {}
        echo = self.sc.car == "gran_turismo"
        if cs.get("crackle"):
            raw = self._run(lambda m, s: es.crackle_clips(m, s, 12), cs["crackle"])
            cl = [_trim_st(self._as_st(c)) for c in raw]
            if echo:
                cl = [add_echo(c) for c in cl]
            pk = max(float(np.max(np.abs(c))) for c in cl)
            out["crackle"] = [c * 0.75 / pk for c in cl]
        if cs.get("shift"):
            raw = self._run(es.shift_clips, cs["shift"])
            cl = [_trim_st(self._as_st(c), -55.0, 0.28) for c in raw]
            if echo:
                cl = [add_echo(c) for c in cl]
            pk = max(float(np.max(np.abs(c))) for c in cl)
            out["shift"] = [c * 0.7 / pk for c in cl]
        if cs.get("start"):
            st = self._as_st(self._run(es.start_clip)[0]).copy()
            tail = st[-int(0.3 * SR):]
            st *= idle_rms / (math.sqrt(float(np.mean(tail ** 2))) + 1e-12)
            pk = float(np.max(np.abs(st)))
            if pk > 0.9:
                log(f"  Startclip-Spitze {pk:.2f} -> 0.9")
                st *= 0.9 / pk
            out["start"] = [st]
        return out


# ------------------------------------------------------------------------------------------------------------------
# Building one car
# ------------------------------------------------------------------------------------------------------------------
def build_car(car: str, out_dir: str, log=print) -> dict:
    """Renders the bank of one car and writes <car>.i16 and <car>.json into out_dir. Returns the metadata
    (mix.gain still 1.0 - set_car_gains() levels the cars against each other)."""
    t0 = time.time()
    prof = es.PROFILES[car]
    ch = CHAR[car]
    sc = StereoCar(car)
    eng = prof["engine"]
    idle, red = float(eng["idle_rpm"]), float(eng["redline_rpm"])
    periods = es.rpm_points(eng, prof["ratios"])
    pts = [sc.render_point(P) for P in periods]
    banks = []
    for pt in pts:
        P = pt["period"]
        x = (pt["rpm"] - idle) / (red - idle)
        for name in ("off", "on"):
            bal = balance_channels(pt[name], P)
            banks.append({"rpm": pt["rpm"], "period": P, "layer": name, "cycles": pt[name], "x": x, "bal_db": bal,
                          "lev": lufs_st(steady(pt[name], P)), "delay_ms": pt["delay_ms_" + name]})
        y = steady(pt["in"], P)
        banks.append({"rpm": pt["rpm"], "period": P, "layer": "in", "cycles": pt["in"], "x": x, "bal_db": 0.0,
                      "lev": -0.691 + 10.0 * math.log10(max(2.0 * kpow(y), 1e-20)), "delay_ms": pt["delay_ms_on"]})
    # --- level shaping: target curves in loudness re full load, half of each bank's own deviation is kept
    keep = 0.5
    by = {(b["period"], b["layer"]): b for b in banks}
    for name in ("off", "on"):
        bs = [b for b in banks if b["layer"] == name]
        xs = np.log([b["rpm"] for b in bs])
        fit = np.polyval(np.polyfit(xs, [b["lev"] for b in bs], 2), xs)
        for b, fv in zip(bs, fit):
            target = curve(ch[name], b["x"]) + keep * (b["lev"] - float(fv))
            b["g"] = 10.0 ** ((target - b["lev"]) / 20.0)
    for b in banks:
        if b["layer"] == "in":
            b["g"] = by[(b["period"], "on")]["g"]         # induction keeps its synthesised relation to the exhaust
    ref_rpm = 0.5 * red
    on_ref = min((b for b in banks if b["layer"] == "on"), key=lambda b: abs(math.log(b["rpm"] / ref_rpm)))
    scale = REF_PEAK / max(float(np.max(np.abs(c))) for c in on_ref["cycles"]) / on_ref["g"]
    peak_all = max(float(np.max(np.abs(c))) * b["g"] * scale for b in banks for c in b["cycles"])
    if peak_all > 0.97:
        log(f"  {car}: Spitze {peak_all:.2f} > 0.97 -> alle Banken {20 * math.log10(0.97 / peak_all):.1f} dB leiser")
        scale *= 0.97 / peak_all
    for b in banks:
        b["g"] *= scale
        b["lev_out"] = b["lev"] + 20.0 * math.log10(b["g"])
    # --- coherence with the lower rpm neighbour and between the loads (the runtime keeps the power while blending)
    rpm_sorted = sorted({b["period"] for b in banks}, reverse=True)       # periods descending = rpm ascending
    for i, P in enumerate(rpm_sorted):
        for name in ("off", "on", "in"):
            b = by[(P, name)]
            b["xrpm"] = 0.0
            if i > 0:
                lo = by[(rpm_sorted[i - 1], name)]
                b["xrpm"] = coherence(lo["cycles"], lo["period"], b["cycles"], P)
        on, off = by[(P, "on")], by[(P, "off")]
        on["xload"] = off["xload"] = coherence(off["cycles"], P, on["cycles"], P)
        by[(P, "in")]["xload"] = 0.0
    # --- loudness of the car at full load as the runtime plays it: on + in through the saturation
    drive_amt = float(ch["saturation"])
    full = []
    for P in rpm_sorted:
        on, inn = by[(P, "on")], by[(P, "in")]
        if not (0.5 * red <= on["rpm"] <= 0.95 * red):
            continue
        n = min(len(on["cycles"]), len(inn["cycles"]))
        y = np.concatenate([on["cycles"][i][:P] * on["g"]
                            + (inn["cycles"][i][:P] * inn["g"] * ch["mix"]["in_gain"])[:, None] for i in range(n)], axis=0)
        full.append(lufs_st(saturate(y, 1.0 + drive_amt * min(on["rpm"] / red, 1.0))))
    loud_full = float(np.mean(full))
    # --- clips
    idle_b = by[(rpm_sorted[0], "off")]
    idle_rms = math.sqrt(float(np.mean((steady(idle_b["cycles"], idle_b["period"]) * idle_b["g"]) ** 2)))
    clips = Clips(sc).build(idle_rms, log)
    # --- pack: every bank at FILE_PEAK with its gain; mono variants two per stereo block
    blocks, pos, jbanks = [], 0, []

    def put(st: np.ndarray) -> int:
        nonlocal pos
        at = pos
        blocks.append(st)
        pos += len(st)
        return at

    for b in banks:
        pk = max(float(np.max(np.abs(c))) for c in b["cycles"]) * b["g"]
        gain = pk / FILE_PEAK
        cyc = []
        if b["layer"] == "in":
            cs = [c * b["g"] / gain for c in b["cycles"]]
            for i in range(0, len(cs), 2):
                at = put(np.stack([cs[i], cs[i + 1]], axis=1))
                cyc += [[at, len(cs[i]), MODE_L], [at, len(cs[i]), MODE_R]]
        else:
            for c in b["cycles"]:
                cyc.append([put(c * b["g"] / gain), len(c), MODE_ST])
        jbanks.append({"rpm": round(b["rpm"], 3), "layer": b["layer"], "period": float(b["period"]), "overlap": OVERLAP,
                       "gain": round(gain, 6), "lufs": round(b["lev_out"], 2), "xrpm": round(b["xrpm"], 3),
                       "xload": round(b["xload"], 3), "cycles": cyc})
    jclips = {}
    for name, lst in clips.items():
        jclips[name] = []
        for c in lst:
            jclips[name].append([put(c), len(c), MODE_ST])
    data = np.concatenate(blocks, axis=0)
    # the file is a container of cycles, yet the QC measures it like a sound: keep its true peak below -1 dBTP
    tp = qc_lib.true_peak_db(data)
    file_scale = 1.0
    if tp > -1.05:
        file_scale = 10.0 ** ((-1.1 - tp) / 20.0)
        data = data * file_scale
        for jb in jbanks:
            jb["gain"] = round(jb["gain"] / file_scale, 6)
    arc = prof["layers"]
    layers: dict = {"limiter": dict(arc["limiter"], pop=ch["limiter_pop"]),
                    "saturation": {"amount": ch["saturation"], "bias": 0.10, "comp": 0.55},
                    "driveline": dict({"wheel_m": 2.05, "final_ratio": 3.2, "pinion_teeth": 12, "mesh_teeth": 29,
                                       "sound": "driveline_whine"}, **ch["driveline"]),
                    "tipin": dict({"sound": "tipin"}, **ch["tipin"]),
                    "thump": dict({"sound": "shift_thump"}, **ch["thump"])}
    if arc.get("turbo") and ch["turbo"]:
        layers["turbo"] = dict(arc["turbo"], depth=ch["turbo_depth"], hiss="turbo_hiss", **ch["turbo"])
    if arc.get("crackle") and "crackle" in jclips:
        layers["crackle"] = dict(arc["crackle"], pan=ch["clip_pan"])
    if arc.get("blowoff") and ch["blowoff"]:
        layers["blowoff"] = dict(arc["blowoff"], **ch["blowoff"])
    if "shift" in jclips:
        layers["shift"] = {"pan": ch["clip_pan"]}
    meta = {"format": FORMAT, "car": car, "sample_rate": SR, "channels": 2, "data": f"{car}.i16",
            "engine": prof["engine"], "gearbox": prof["gearbox"], "banks": jbanks, "clips": jclips, "layers": layers,
            "mix": dict({"gain": 1.0, "off_gain": 1.0, "clip_gain": round(1.0 / file_scale, 6)}, **ch["mix"]),
            "synth": {"generator": GENERATOR, "model": 3, "pan": ch["pan"], "width": ch["width"], "noise": ch["noise"],
                      "retune_db": ch["retune"], "nl_scale": ch["nl"], "ref_rpm": round(ref_rpm),
                      "loudness_full": round(loud_full, 2), "loudness_offset_db": ch["loudness"],
                      "balance_db_max": round(max(abs(b["bal_db"]) for b in banks), 2),
                      "cycles": "[offset, length, mode] in frames; mode 0 = stereo, 1 = mono in the left samples, 2 = mono in the right samples",
                      "gain": "factor that restores the designed level of a bank (stored at full scale); clips: mix.clip_gain",
                      "lufs": "K-weighted loudness of the bank at its designed level (before mix.gain)",
                      "xrpm": "coherence with the next lower rpm point of the same layer", "xload": "coherence off/on"}}
    os.makedirs(out_dir, exist_ok=True)
    ml.write_i16(os.path.join(out_dir, f"{car}.i16"), data)
    with open(os.path.join(out_dir, f"{car}.json"), "w", encoding="utf-8") as fh:
        fh.write(es.format_json(meta))
    log(f"{car}: {len(periods)} Drehzahlpunkte {120.0 * SR / periods[0]:.0f}..{120.0 * SR / periods[-1]:.0f}/min, "
        f"{len(jbanks)} Banken, Clips {', '.join(f'{k}:{len(v)}' for k, v in jclips.items()) or '-'}; "
        f"{data.shape[0] * 4 / 1e6:.2f} MB; Volllast {loud_full:.1f} LUFS; True Peak der Datei {tp:.1f} dBTP; "
        f"Kanalabgleich bis {meta['synth']['balance_db_max']:.2f} dB; {time.time() - t0:.0f} s")
    return meta


def set_car_gains(out_dir: str, log=print) -> None:
    """mix.gain of every car from its full-load loudness as the runtime plays it (synth.loudness_full) and its
    offset in the character table: the Gran Turismo lands at INTERNAL_LUFS + its offset inside the mixer, the
    others relative to it. The bus level (config audio.modern.levels.MEngine) makes the plan's -16 LUFS of it."""
    for car in CARS:
        path = os.path.join(out_dir, f"{car}.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            meta = json.load(fh)
        want = INTERNAL_LUFS + CHAR[car]["loudness"]
        # the saturation compresses: iterate the gain on the measured small-signal estimate once (good to ~0.3 dB,
        # the game run with capture_mix.gd is the reference)
        meta["mix"]["gain"] = round(10.0 ** ((want - meta["synth"]["loudness_full"]) / 20.0), 4)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(es.format_json(meta))
        log(f"  mix.gain {car}: {meta['mix']['gain']:.3f} ({20 * math.log10(meta['mix']['gain']):+.1f} dB)")


def register_banks(out: str | None, cars: list) -> None:
    man = ml.Manifest("engines", out)
    man.drop_generator(GENERATOR)
    for car in cars:
        man.add(car, f"{car}.i16", "bank", GENERATOR, bus="MEngine",
                note="Zyklenbank Motor v3 (ce-engine-bank-2): Zyklen und Clips hintereinander, kein abspielbarer Klang")
    man.save()


# ------------------------------------------------------------------------------------------------------------------
# Vehicle sounds (natively mixed: assets/audio/modern/vehicle)
# ------------------------------------------------------------------------------------------------------------------
VSR = ml.SR


def _vnoise(n: int, seed: int, shape) -> np.ndarray:
    """Periodic noise with unit RMS."""
    y = ml.periodic_noise(n, VSR, seed, shape)
    return y / (math.sqrt(float(np.mean(y * y))) + 1e-12)


def _bp(f, lo, hi, order=2):
    return (1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order))) * (1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order)))


def _peak(f, f0, q, gain_db):
    g = 10.0 ** (gain_db / 20.0)
    x = (f / f0 - f0 / f) * q
    return 1.0 + (g - 1.0) / (1.0 + x * x)


def turbo_tone(f_hz: float, seconds: float, seed: int) -> np.ndarray:
    """A charger's tone as a seamless loop: a narrow band around f_hz (phase noise 2-40 Hz, slow amplitude
    flutter) with weak harmonics - not a pure sine. f_hz x seconds must be a whole number."""
    n = int(round(seconds * VSR))
    t = np.arange(n) / VSR
    pn = _vnoise(n, seed, lambda f: _bp(f, 2.0, 40.0, 1) / np.sqrt(f))
    am = _vnoise(n, seed + 1, lambda f: _bp(f, 1.0, 12.0, 1) / np.sqrt(f))
    ph = 2.0 * np.pi * f_hz * t + 1.6 * pn
    return (np.sin(ph) + 0.25 * np.sin(2.0 * ph + 0.7) + 0.08 * np.sin(3.0 * ph + 1.9)) * (1.0 + 0.1 * am)


def thump(rng, f0: float, f1: float, dur: float, click: float) -> np.ndarray:
    """A driveline thump: a falling low tone with a short band-limited click."""
    m = int(dur * 5 * VSR)
    t = np.arange(m) / VSR
    f = f1 + (f0 - f1) * np.exp(-t / (dur * 0.5))
    y = np.sin(2.0 * np.pi * np.cumsum(f) / VSR) * np.exp(-t / dur) * (1.0 - np.exp(-t / 0.003))
    if click:
        nz = rng.standard_normal(m)
        spec = np.fft.rfft(nz)
        ff = np.maximum(np.fft.rfftfreq(m, 1.0 / VSR), 1.0)
        nz = np.fft.irfft(spec * _bp(ff, 300.0, 2200.0, 1), m)
        y += click * nz / (math.sqrt(float(np.mean(nz * nz))) + 1e-12) * np.exp(-t / 0.012)
    y[-64:] *= np.linspace(1.0, 0.0, 64)
    return y


def blowoff(rng, f0: float, f1: float, tau: float, flutter: float, flutter_hz: float, seconds: float) -> np.ndarray:
    """A diverter valve: jet noise whose band falls with the pressure, flutter of the compressor surge, a short
    low thump of the pressure wave."""
    m = int(seconds * VSR)
    t = np.arange(m) / VSR
    fc = f1 + (f0 - f1) * np.exp(-t / (tau * 0.75))
    nz = rng.standard_normal(m)
    y = np.zeros(m)
    y1 = y2 = 0.0
    for i in range(m):
        w = 2.0 * math.pi * fc[i] / VSR
        r = math.exp(-w / 2.4)
        y0 = (1.0 - r) * nz[i] + 2.0 * r * math.cos(w) * y1 - r * r * y2
        y[i] = y0
        y2, y1 = y1, y0
    y /= math.sqrt(float(np.mean(y[:int(0.1 * VSR)] ** 2))) + 1e-12
    env = (1.0 - np.exp(-t / 0.005)) * np.exp(-t / tau)
    if flutter:
        env *= 1.0 - flutter * np.exp(-t / 0.16) * (0.5 - 0.5 * np.cos(2.0 * np.pi * flutter_hz * t)) * (t > 0.03)
    y = y * env + 2.2 * np.sin(2.0 * np.pi * 92.0 * t) * np.exp(-t / 0.035) * (1.0 - np.exp(-t / 0.004))
    fade = int(0.05 * VSR)
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    return y


def build_vehicle(out: str | None, log=print) -> None:
    """Writes the natively mixed sounds of the car and their manifest entries. Every file is stored at a peak of
    0.5; "gain_db" in the manifest is what brings a level of 1.0 of the runtime laws back to the designed scale
    (the engine's own full scale)."""
    man = ml.Manifest("vehicle", out)
    man.drop_generator(GENERATOR)
    repo = out is None
    peak = 0.5

    def put(sid: str, designed, kind: str, note: str) -> None:
        """designed = the sound (or the list of its variants) in the engine's own scale for a runtime level of 1."""
        many = isinstance(designed, list)
        vs = [np.asarray(v, float) for v in (designed if many else [designed])]
        unit = max(float(np.max(np.abs(v))) for v in vs)
        names = []
        loop = None
        for i, v in enumerate(vs):
            name = f"{sid}_{'abcdef'[i]}.wav" if many else f"{sid}.wav"
            ml.write_wav16(man.file(name), v * (peak / unit))
            loop = (0, len(v)) if kind == "loop" else None
            if repo:
                ml.write_wav_import(man.file(name), loop)
            names.append(name)
        man.add(sid, names if many else names[0], kind, GENERATOR, loop=loop, bus="MEngineFx",
                gain_db=round(20.0 * math.log10(unit / peak), 2), note=note)

    # turbo: one charger (mono) and two chargers left / right, slightly detuned (stereo); reference 3 kHz
    one = turbo_tone(3000.0, 1.0, 9101)
    put("turbo_single", one, "loop", "Laderton, ein Lader; Bezug 3000 Hz")
    tl, tr = turbo_tone(2946.0, 1.0, 9111), turbo_tone(3063.0, 1.0, 9121)
    twin = np.stack([0.8 * tl + 0.2 * tr, 0.2 * tl + 0.8 * tr], axis=1)
    put("turbo_twin", twin, "loop", "Ladertöne, zwei Lader links/rechts (0,982 / 1,021); Bezug 3000 Hz")
    hiss = _vnoise(VSR, 9131, lambda f: _bp(f, 2600.0, 9500.0, 2))
    put("turbo_hiss", hiss, "loop", "Strömungsrauschen des Verdichters (Effektivwert 1 im Entwurf)")
    # driveline whine: one tone with a weak octave; the runtime plays it twice (final drive, gear mesh); reference 1 kHz
    n = VSR // 2
    t = np.arange(n) / VSR
    ph = 2.0 * np.pi * 1000.0 * t + 0.3 * _vnoise(n, 9141, lambda f: _bp(f, 4.0, 30.0, 1))
    wh = np.sin(ph) + 0.3 * np.sin(2.0 * ph + 1.0)
    put("driveline_whine", wh, "loop", "Zahneingriffston; Bezug 1000 Hz")
    # tip-in: the gulp of the opening throttle and the driveline taking up the torque
    vs = []
    for i, (f0, f1) in enumerate(((58.0, 38.0), (63.0, 41.0))):
        rng = np.random.default_rng(9151 + i)
        m = int(0.38 * VSR)
        tt = np.arange(m) / VSR
        nz = rng.standard_normal(m)
        ff = np.maximum(np.fft.rfftfreq(m, 1.0 / VSR), 1.0)
        gulp = np.fft.irfft(np.fft.rfft(nz) * _bp(ff, 280.0, 2600.0, 1) * _peak(ff, 620.0, 2.0, 6.0), m)
        gulp = gulp / (math.sqrt(float(np.mean(gulp * gulp))) + 1e-12) * (1.0 - np.exp(-tt / 0.008)) * np.exp(-tt / 0.085)
        y = 0.10 * gulp
        th = thump(rng, f0, f1, 0.055, 0.25)
        d = int(0.010 * VSR)
        k = min(len(th), m - d)
        y[d:d + k] += 0.28 * th[:k]
        y[-256:] *= np.linspace(1.0, 0.0, 256)
        vs.append(y)
    put("tipin", vs, "oneshot", "Gasannahme: Ansaugschlucken und Lastwechselschlag")
    vs = [0.22 * thump(np.random.default_rng(9161 + i), f0, f1, d, 0.35) for i, (f0, f1, d) in enumerate(((72.0, 44.0, 0.045), (66.0, 40.0, 0.05)))]
    put("shift_thump", vs, "oneshot", "Lastwechselschlag beim Schalten")
    # blow-off per style (level 1 = designed peak 0.5 as in the Arcade clips)
    styles = {"blowoff_hatch": [(5200.0, 1500.0, 0.26, 0.6, 19.0, 0.70), (4900.0, 1400.0, 0.24, 0.7, 22.0, 0.66)],
              "blowoff_soft": [(4200.0, 1500.0, 0.20, 0.0, 0.0, 0.50)],
              "blowoff_gt": [(4800.0, 1350.0, 0.30, 0.3, 17.0, 0.75)]}
    notes = {"blowoff_hatch": "Schubumluft mit Verdichterflattern (Kompakt)", "blowoff_soft": "Schubumluft, dezent (Limousine)",
             "blowoff_gt": "Schubumluft zweier Lader (Gran Turismo)"}
    for j, (sid, vs_) in enumerate(styles.items()):
        vs = [blowoff(np.random.default_rng(9171 + 10 * j + i), *p) for i, p in enumerate(vs_)]
        pk = max(float(np.max(np.abs(v))) for v in vs)
        vs = [v * (0.5 / pk) for v in vs]
        put(sid, vs if len(vs) > 1 else vs[0], "oneshot", notes[sid])
    man.save()
    total = sum(os.path.getsize(man.file(f)) for f in os.listdir(man.dir) if f.endswith(".wav"))
    log(f"vehicle: {len(man.sounds)} Klänge im Manifest, WAV zusammen {total / 1e6:.2f} MB")


# ------------------------------------------------------------------------------------------------------------------
def info(cars: list) -> None:
    for car in cars:
        prof = es.PROFILES[car]
        periods = es.rpm_points(prof["engine"], prof["ratios"])
        idle = prof["engine"]["idle_rpm"]
        frames = 0
        for P in periods:
            rpm = 120.0 * SR / P
            n_on = N_VAR_ON_LOW if rpm < ON_LOW_X * idle else N_VAR
            frames += (N_VAR + n_on + N_VAR_IN // 2) * (P + OVERLAP)
        print(f"{car}: {len(periods)} Punkte " + " ".join(f"{120.0 * SR / p:.0f}" for p in periods)
              + f" | Zyklen {frames * 4 / 1e6:.2f} MB | Bild {CHAR[car]['pan']}")


def _job(args: tuple) -> str:
    car, out_dir = args
    lines: list = []
    build_car(car, out_dir, lines.append)
    return "\n".join(lines)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Motor v3: Stereo-Zyklenbanken und Fahrzeugklänge des Profils Modern")
    ap.add_argument("--out", default=None, help="in diesen Ordner statt ins Repository schreiben (ohne .import-Dateien)")
    ap.add_argument("--car", action="append", choices=CARS, help="nur dieses Auto (mehrfach möglich)")
    ap.add_argument("--only", choices=["banks", "vehicle"], default=None, help="nur die Banken oder nur die Fahrzeugklänge")
    ap.add_argument("--jobs", type=int, default=2, help="Autos gleichzeitig (höchstens 2)")
    ap.add_argument("--info", action="store_true", help="nur Drehzahlpunkte und Größen anzeigen")
    args = ap.parse_args(argv)
    cars = args.car or CARS
    if args.info:
        info(cars)
        return 0
    t0 = time.time()
    if args.only != "vehicle":
        out_dir = os.path.join(ml.assets_dir(args.out), "engines")
        jobs = max(1, min(args.jobs, 2, len(cars)))
        if jobs > 1:
            import multiprocessing as mp
            with mp.get_context("fork").Pool(jobs) as pool:
                for text in pool.imap(_job, [(c, out_dir) for c in cars]):
                    print(text, flush=True)
        else:
            for c in cars:
                build_car(c, out_dir)
        set_car_gains(out_dir)
        register_banks(args.out, [c for c in CARS if os.path.exists(os.path.join(out_dir, f"{c}.i16"))])
    if args.only != "banks":
        build_vehicle(args.out)
    print(f"fertig nach {time.time() - t0:.0f} s -> {ml.assets_dir(args.out)}")
    if args.out is None:
        print("Danach einmal: godot --headless --path . --import (Godot ergänzt die .import-Dateien)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
