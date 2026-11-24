#!/usr/bin/env python3
"""Motorklang v2 - reference player, demo renderer and self-checks for the engine cycle banks.

Plays a bank exactly as docs/motorsound.md section 4 describes the runtime (EngineAudio):
  * cycle-synchronous playback: the engine phase advances by rpm / (120 * sample_rate) per output sample;
    every source (the two neighbouring rpm banks x both loads) is read at phase * period of its bank
    (read step rpm / bank_rpm, linear interpolation)
  * weights: logarithmic between the rpm points, equal-power between the loads ("off" times mix.off_gain),
    mix.gain on top
  * at every cycle start each source picks a random variant (never the same twice in a row) and the first
    `overlap` samples are cross-faded from the previous variant's continuation
  * limiter: at the limiter with load, layers.limiter.cut_cycles overrun cycles follow on_cycles load cycles
plus the runtime layers for the demo: crackle and blow-off clips after lifting off, shift crack on full-load
upshifts, the start clip, and a simple turbo whistle stand-in (the real one is the runtime's).

A small gearbox/vehicle simulation (automatic gear choice from the bank's gearbox block, launch with slip,
shift = load cut + rpm jump, rev-matched braking downshifts for the sporty cars, free revving at standstill
with inertia and limiter, turbo boost with spool lag) drives a ~30 s demo per car: start, idle, three
throttle blips, full-throttle launch through the gears to ~92 % of vmax (time compressed so that every car
gets there in ~11 s), lift-off at high rpm, coasting, braking with downshifts, idle.

Usage:
  python3 tools/audio/engine_preview.py [--car C ...] [--banks assets/audio/engines] [--out DIR] [--no-demo]
Writes <out>/<car>_demo.wav/.ogg, all_cars_demo.wav/.ogg, spectrogram PNGs (ffmpeg) and prints the checks
(cycle alignment, junction smoothness, clicks, clipping, loudness, orders, on/off contrast, car contrast).
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

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
SCRATCH = "/tmp/ce_engine_demo"


# ------------------------------------------------------------------------------------------------
# Bank loading
# ------------------------------------------------------------------------------------------------

class BankSet:
    def __init__(self, path_json: str):
        with open(path_json, encoding="utf-8") as fh:
            self.meta = json.load(fh)
        base = os.path.dirname(path_json)
        self.data = np.fromfile(os.path.join(base, self.meta["data"]), dtype="<f4").astype(np.float64)
        self.sr = int(self.meta["sample_rate"])
        rpms = sorted({float(b["rpm"]) for b in self.meta["banks"]})
        self.rpms = np.array(rpms)
        self.src = {}
        for b in self.meta["banks"]:
            i = rpms.index(float(b["rpm"]))
            self.src[(i, b["load"])] = {"period": float(b["period"]), "overlap": int(b["overlap"]),
                                        "cycles": [self.data[o:o + n] for o, n in b["cycles"]],
                                        "rpm": float(b["rpm"])}
        self.clips = {k: [self.data[o:o + n] for o, n in v] for k, v in self.meta.get("clips", {}).items()}
        self.engine = self.meta["engine"]
        self.layers = self.meta.get("layers", {})
        self.gearbox = self.meta["gearbox"]
        self.mix = self.meta.get("mix", {"gain": 1.0, "off_gain": 1.0})


# ------------------------------------------------------------------------------------------------
# Player (contract section 4)
# ------------------------------------------------------------------------------------------------

class EnginePlayer:
    def __init__(self, bank: BankSet, seed: int = 7):
        self.b = bank
        self.rng = np.random.default_rng(seed)
        self.phase = 0.0
        self.var = {}
        for key, s in bank.src.items():
            nv = len(s["cycles"])
            a = int(self.rng.integers(nv))
            self.var[key] = [a, (a + 1) % nv]          # [previous, current]
        self.boundaries: list = []
        self.lim_count = 0

    def _new_cycle(self):
        for key, st in self.var.items():
            nv = len(self.b.src[key]["cycles"])
            prev = st[1]
            nxt = int(self.rng.integers(nv - 1))
            if nxt >= prev:
                nxt += 1
            st[0], st[1] = prev, nxt

    def _read(self, key, ph: np.ndarray) -> np.ndarray:
        s = self.b.src[key]
        prev_c = s["cycles"][self.var[key][0]]
        cur_c = s["cycles"][self.var[key][1]]
        pos = ph * s["period"]
        i = np.floor(pos).astype(int)
        fr = pos - i
        x = cur_c[i] * (1.0 - fr) + cur_c[np.minimum(i + 1, len(cur_c) - 1)] * fr
        ov = s["overlap"]
        m = pos < ov
        if np.any(m):
            pp = pos[m] + s["period"]
            j = np.floor(pp).astype(int)
            fj = pp - j
            last = len(prev_c) - 1
            xp = prev_c[np.minimum(j, last)] * (1.0 - fj) + prev_c[np.minimum(j + 1, last)] * fj
            w = pos[m] / ov
            x[m] = (1.0 - w) * xp + w * x[m]
        return x

    def render(self, rpm: np.ndarray, load: np.ndarray, at_limiter: np.ndarray) -> np.ndarray:
        b = self.b
        n = len(rpm)
        y = np.zeros(n)
        nb = len(b.rpms)
        lim = b.layers.get("limiter", {"cut_cycles": 2, "on_cycles": 3})
        gain = float(b.mix.get("gain", 1.0))
        off_gain = float(b.mix.get("off_gain", 1.0))
        lrpm = np.log(b.rpms)
        pos = 0
        cut = False
        while pos < n:
            chunk = min(n - pos, 16384)
            inc = rpm[pos:pos + chunk] / (120.0 * b.sr)        # cycles per sample
            cum = self.phase + np.cumsum(inc) - inc              # engine phase at each sample
            k = int(np.searchsorted(cum, 1.0))                   # first sample of the next cycle
            seg = min(k, chunk)
            ph = np.minimum(cum[:seg], 0.999999)
            r = rpm[pos:pos + seg]
            ld = np.clip(load[pos:pos + seg], 0.0, 1.0)
            if cut:
                ld = np.zeros_like(ld)
            lr = np.log(np.clip(r, b.rpms[0], b.rpms[-1]))
            i0 = np.clip(np.searchsorted(b.rpms, np.clip(r, b.rpms[0], b.rpms[-1])) - 1, 0, nb - 2)
            alpha = np.clip((lr - lrpm[i0]) / (lrpm[i0 + 1] - lrpm[i0]), 0.0, 1.0)
            w_on = np.sin(0.5 * np.pi * ld)
            w_off = np.cos(0.5 * np.pi * ld) * off_gain
            out = np.zeros(seg)
            for i in np.unique(np.concatenate([i0, i0 + 1])):
                wi = np.where(i0 == i, 1.0 - alpha, 0.0) + np.where(i0 + 1 == i, alpha, 0.0)
                if not np.any(wi > 0.0):
                    continue
                out += wi * (w_on * self._read((i, "on"), ph) + w_off * self._read((i, "off"), ph))
            y[pos:pos + seg] = gain * out
            pos += seg
            nxt = cum[k] if k < chunk else cum[-1] + inc[-1]     # phase of the next sample
            if nxt < 1.0:
                self.phase = nxt
                continue
            self.phase = nxt - 1.0
            self._new_cycle()
            self.boundaries.append(pos)
            # limiter, decided per cycle at its start: on_cycles with load, then cut_cycles overrun
            if pos < n and at_limiter[pos]:
                self.lim_count += 1
                period = lim["on_cycles"] + lim["cut_cycles"]
                cut = (self.lim_count - 1) % period >= lim["on_cycles"]
            else:
                self.lim_count = 0
                cut = False
        return y


# ------------------------------------------------------------------------------------------------
# Vehicle and gearbox simulation (drives the demo)
# ------------------------------------------------------------------------------------------------

VEH = {  # vmax, t100, t200 (config/game_config.json vehicles + accel ratings)
    "kompakt": (230.0, 4.6, 12.0), "kombi": (235.0, 7.0, 19.0), "limousine": (245.0, 5.6, 14.5),
    "sportwagen": (255.0, 3.8, 10.0), "gran_turismo": (270.0, 4.6, 12.0)}
SPORTY = {"kompakt", "sportwagen", "gran_turismo"}


def fit_accel(vmax: float, t100: float, t200: float):
    """Same fit as VehicleModel.fit_accel_curve: dv/dt = a0 (1 - v/vmax)^(1-q)."""
    def ratio(q):
        return (1 - (1 - 200 / vmax) ** q) / (1 - (1 - 100 / vmax) ** q)
    lo, hi = 0.02, 1.0
    for _ in range(64):
        mid = 0.5 * (lo + hi)
        if ratio(mid) > t200 / t100:
            lo = mid
        else:
            hi = mid
    q = 0.5 * (lo + hi)
    a0 = vmax * (1 - (1 - 100 / vmax) ** q) / (q * t100)
    return a0, q


class DriveSim:
    def __init__(self, car: str, bank: BankSet, time_scale: float):
        self.car = car
        self.e = bank.engine
        self.g = bank.gearbox
        self.layers = bank.layers
        self.k = self.g["kmh_per_1000rpm"]
        self.vmax, t100, t200 = VEH[car]
        self.a0, self.q = fit_accel(self.vmax, t100, t200)
        self.ts = time_scale
        self.idle = float(self.e["idle_rpm"])
        self.limit = float(self.e["limiter_rpm"])
        self.speed = 0.0
        self.gear = 1
        self.rpm = self.idle
        self.mode = "neutral"          # neutral (clutch open) / launch (slipping) / drive (locked)
        self.launch_t = 1e9
        self.shift = None
        self.boost = 0.0
        self.load = 0.0
        self.events: list = []
        self.dct = self.g["shift_time_s"] <= 0.13
        # free revving: seconds from idle to the limiter at full throttle, fall time constant when lifting
        self.rise_s = {"sportwagen": 0.45, "kompakt": 0.6, "gran_turismo": 0.7, "limousine": 0.7}.get(car, 1.0)
        self.fall_tau = 0.32 if car in SPORTY else 0.45

    def _accel(self, v: float, dt: float) -> float:
        if v >= self.vmax:
            return v
        u = min(v / self.vmax, 0.999999)
        t = self.vmax / (self.a0 * self.q) * (1 - (1 - u) ** self.q) + dt * self.ts
        t_top = self.vmax / (self.a0 * self.q)
        return self.vmax if t >= t_top else self.vmax * (1 - (1 - t / t_top) ** (1 / self.q))

    def _speed(self, dt: float, thr: float, brake: float, drive_share: float = 1.0) -> None:
        if thr > 0.0:
            self.speed = self._accel(self.speed, dt * thr * drive_share)
        elif brake > 0.0:
            self.speed = max(0.0, self.speed - 45.0 * brake * dt)
        else:
            self.speed = max(0.0, self.speed - 5.0 * dt)       # driving.coast_decel_kmh_s

    def step(self, t: float, dt: float, thr: float, brake: float):
        """Returns rpm, load, at_limiter for this control step."""
        g = self.g
        at_lim = False
        prev_load = self.load
        load = thr
        if self.mode == "neutral":
            self.speed = max(0.0, self.speed - 45.0 * brake * dt)
            if thr > 0.0 and t >= self.launch_t:
                self.mode = "launch"
            elif thr > 0.0:                      # blip at standstill: inertia up to the limiter
                self.rpm = min(self.limit, self.rpm + (self.limit - self.idle) / self.rise_s * thr * dt)
                at_lim = self.rpm >= self.limit - 1.0 and thr > 0.5
            else:
                fall = (self.rpm - self.idle) * dt / self.fall_tau + 900.0 * dt
                self.rpm = max(self.idle, self.rpm - fall)
        if self.mode == "launch":                # clutch slip at launch_rpm until the 1st gear catches up
            self._speed(dt, thr, brake)
            target = max(g["launch_rpm"] * thr, self.idle)
            self.rpm += (target - self.rpm) * min(1.0, dt / 0.12)
            if self.speed / self.k[0] * 1000.0 >= self.rpm * 0.97:
                self.mode, self.gear = "drive", 1
        elif self.mode == "drive":
            if self.shift is not None:
                sh = self.shift
                sh["t"] += dt
                x = min(sh["t"] / sh["dur"], 1.0)
                if sh["kind"] == "up":           # load cut (DCT) / torque reduction (automatic)
                    load = 0.0 if self.dct else 0.3 * thr
                    self._speed(dt, thr, brake, 0.85 if self.dct else 0.4)
                else:                            # downshift, rev-matching blip on the sporty cars
                    load = 0.75 if (sh["blip"] and x < 0.6) else 0.0
                    self._speed(dt, 0.0, brake)
                target = max(self.speed / self.k[sh["to"] - 1] * 1000.0, self.idle)
                self.rpm = sh["from"] + (target - sh["from"]) * (0.5 - 0.5 * math.cos(math.pi * x))
                if x >= 1.0:
                    self.gear = sh["to"]
                    self.shift = None
            else:
                self._speed(dt, thr, brake)
                self.rpm = self.speed / self.k[self.gear - 1] * 1000.0
                if self.gear == 1 and self.rpm < self.idle * 1.15 and thr <= 0.0:
                    self.mode = "neutral"        # clutch opens before stalling
                    self.rpm = max(self.rpm, self.idle)
                else:
                    up = g["upshift_rpm"][0] + (g["upshift_rpm"][1] - g["upshift_rpm"][0]) * thr
                    down = g["downshift_rpm"][0] + (g["downshift_rpm"][1] - g["downshift_rpm"][0]) * thr
                    if brake > 0.0:        # braking: sporty cars keep the engine up (rev-matched blips)
                        down = (0.45 * self.e["redline_rpm"] if self.car in SPORTY
                                else g["downshift_rpm"][0] * 1.6)
                    if thr > 0.05 and self.rpm > up and self.gear < len(self.k):   # hold the gear on overrun
                        self.shift = {"kind": "up", "from": self.rpm, "to": self.gear + 1, "t": 0.0,
                                      "dur": g["shift_time_s"]}
                        if thr > 0.8:
                            self.events.append((t, "shift", self.rpm))
                    elif self.rpm < down and self.gear > 1:
                        blip = brake > 0.0 and self.car in SPORTY
                        self.shift = {"kind": "down", "from": self.rpm, "to": self.gear - 1, "t": 0.0,
                                      "dur": g["shift_time_s"] * 1.6, "blip": blip}
                        if blip:
                            self.events.append((t, "blip", self.rpm))
                    if self.rpm >= self.limit:
                        self.rpm = self.limit
                        at_lim = thr > 0.5
        # turbo boost with spool lag
        tb = self.layers.get("turbo")
        if tb:
            target = thr * min(max((self.rpm - 0.6 * tb["boost_rpm"]) / (0.8 * tb["boost_rpm"]), 0.0), 1.0)
            tau = tb["spool_s"] if target > self.boost else 0.12
            self.boost += (target - self.boost) * min(1.0, dt / tau)
        if prev_load > 0.6 and load < 0.1 and thr <= 0.0:
            self.events.append((t, "liftoff", self.rpm, self.boost))
        self.load = load
        return self.rpm, load, at_lim


def scenario(car: str, bank: BankSet, start_len: float):
    """Control signals at 1 kHz: start clip, idle, blips, launch to ~92 % vmax, lift-off, coast, brake, idle."""
    vmax, t100, t200 = VEH[car]
    a0, q = fit_accel(vmax, t100, t200)
    t90 = vmax / (a0 * q) * (1 - (1 - 0.92) ** q)
    sim = DriveSim(car, bank, time_scale=max(1.0, t90 / 11.0))
    dt = 0.001
    t0 = start_len
    blips = [(t0 + 2.1, 0.18), (t0 + 3.0, 0.3), (t0 + 4.0, 0.62)]
    sim.launch_t = t0 + 5.6
    rpm, load, lim, speed, gear, boost = [], [], [], [], [], []
    phase = "pre"
    t = 0.0
    t_lift = t_brake = t_stop = None
    while True:
        thr, brake = 0.0, 0.0
        if t < sim.launch_t:
            for tb, d in blips:
                if tb <= t < tb + d:
                    thr = 1.0
        elif phase in ("pre", "launch"):
            phase = "launch"
            thr = 1.0
            if sim.speed >= 0.92 * vmax or t >= sim.launch_t + 13.0:
                phase = "coast"
                t_lift = t
        if phase == "coast":
            thr = 0.0
            if t >= t_lift + 2.5:
                phase = "brake"
                t_brake = t
        if phase == "brake":
            brake = 1.0
            if sim.speed <= 0.5:
                phase = "idle"
                t_stop = t
        if phase == "idle" and t >= t_stop + 2.0:
            break
        r, ld, al = sim.step(t, dt, thr, brake)
        if t < start_len:
            r, ld, al = sim.idle, 0.0, False
        rpm.append(r)
        load.append(ld)
        lim.append(al)
        speed.append(sim.speed)
        gear.append(sim.gear)
        boost.append(sim.boost)
        t += dt
    return {"rpm": np.array(rpm), "load": np.array(load), "lim": np.array(lim), "speed": np.array(speed),
            "gear": np.array(gear), "boost": np.array(boost), "events": sim.events, "dt": dt,
            "t_lift": t_lift, "t_brake": t_brake, "t_stop": t_stop, "launch": sim.launch_t}


def smooth(x: np.ndarray, tau_s: float, dt: float) -> np.ndarray:
    a = 1.0 - math.exp(-dt / tau_s)
    y = np.empty_like(x)
    acc = x[0]
    for i in range(len(x)):
        acc += (x[i] - acc) * a
        y[i] = acc
    return y


def render_demo(car: str, bank: BankSet, seed: int = 3) -> tuple:
    sr = bank.sr
    rng = np.random.default_rng(seed)
    start = bank.clips.get("start", [None])[0]
    start_len = len(start) / sr if start is not None else 0.0
    sc = scenario(car, bank, start_len)
    dt = sc["dt"]
    n = int(len(sc["rpm"]) * dt * sr)
    tc = np.arange(len(sc["rpm"])) * dt
    ta = np.arange(n) / sr
    rpm = np.interp(ta, tc, smooth(sc["rpm"], 0.012, dt))
    load = np.interp(ta, tc, smooth(sc["load"].astype(float), 0.03, dt))
    lim = np.interp(ta, tc, sc["lim"].astype(float)) > 0.5
    player = EnginePlayer(bank, seed)
    y = player.render(rpm, load, lim)
    # start clip, cross-faded into the idle bank
    if start is not None:
        ns = len(start)
        fade = int(0.15 * sr)
        w = np.ones(n)
        w[:ns - fade] = 0.0
        w[ns - fade:ns] = np.linspace(0.0, 1.0, fade)
        y *= w
        st = start.copy()
        st[ns - fade:] *= np.linspace(1.0, 0.0, fade)
        y[:ns] += st
    # one-shot layers
    layers = bank.layers
    clips = bank.clips
    out_events = []
    for ev in sc["events"]:
        t = ev[0]
        if ev[1] == "liftoff":
            cr = layers.get("crackle")
            if cr and "crackle" in clips and ev[2] >= cr["min_rpm"]:
                tt = t + 0.05
                while tt < t + cr["duration_s"]:
                    decay = 1.0 - (tt - t) / cr["duration_s"]
                    clip = clips["crackle"][int(rng.integers(len(clips["crackle"])))]
                    out_events.append((tt, clip, cr["level"] * (0.45 + 0.55 * rng.random()) * (0.4 + 0.6 * decay)))
                    tt += rng.exponential(1.0 / cr["rate_hz"])
            bo = layers.get("blowoff")
            if bo and "blowoff" in clips and ev[3] >= bo["min_boost"]:
                out_events.append((t + 0.02, clips["blowoff"][0], bo["level"] * min(ev[3], 1.0)))
        elif ev[1] == "shift" and "shift" in clips:
            out_events.append((t + 0.01, clips["shift"][int(rng.integers(len(clips["shift"])))], 0.6))
        elif ev[1] == "blip":
            cr = layers.get("crackle")
            if cr and "crackle" in clips and rng.random() < 0.7:
                out_events.append((t + 0.12, clips["crackle"][int(rng.integers(len(clips["crackle"])))],
                                   cr["level"] * 0.6))
    for t, clip, g in out_events:
        i = int(t * sr)
        m = min(len(clip), n - i)
        if m > 0:
            y[i:i + m] += clip[:m] * g
    # turbo whistle stand-in (runtime layer): narrow band around a boost-dependent frequency
    tb = layers.get("turbo")
    if tb:
        boost = np.interp(ta, tc, sc["boost"])
        f = tb["whistle_hz"][0] + (tb["whistle_hz"][1] - tb["whistle_hz"][0]) * boost ** 0.8
        ph = np.cumsum(2.0 * np.pi * f / sr)
        noise = np.convolve(rng.standard_normal(n), np.ones(24) / 24.0, mode="same")
        y += tb["level"] * boost ** 1.5 * (0.5 * np.sin(ph + 3.0 * noise) + 0.15 * np.sin(2.0 * ph))
    info = {"rpm": rpm, "load": load, "boundaries": np.array(player.boundaries), "scenario": sc,
            "events": out_events}
    return y, info


# ------------------------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------------------------

def write_wav(path: str, x: np.ndarray, sr: int) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def ffmpeg(*args) -> bool:
    exe = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
    if not os.path.exists(exe):
        return False
    r = subprocess.run([exe, "-y", "-loglevel", "error", *args], capture_output=True, text=True)
    if r.returncode != 0:
        print("ffmpeg:", r.stderr.strip()[:300])
    return r.returncode == 0


def encode_and_plot(wav: str, title: str) -> None:
    base = wav[:-4]
    ffmpeg("-i", wav, "-c:a", "libvorbis", "-q:a", "6", base + ".ogg")
    ffmpeg("-i", wav, "-lavfi", "showspectrumpic=s=1600x700:legend=1:scale=log:fscale=lin:drange=90"
           ":color=intensity", base + "_spec.png")
    ffmpeg("-i", wav, "-lavfi", "showspectrumpic=s=1600x700:legend=1:scale=log:fscale=lin:start=0:stop=1500"
           ":drange=80:color=intensity", base + "_spec_low.png")


# ------------------------------------------------------------------------------------------------
# Checks
# ------------------------------------------------------------------------------------------------

def a_weight(f):
    f = np.maximum(f, 1.0)
    ra = 12194.0 ** 2 * f ** 4 / ((f ** 2 + 20.6 ** 2) * np.sqrt((f ** 2 + 107.7 ** 2) * (f ** 2 + 737.9 ** 2))
                                  * (f ** 2 + 12194.0 ** 2))
    return ra * 10.0 ** (2.0 / 20.0)


def level_a(x: np.ndarray, sr: int) -> float:
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    w = a_weight(f) ** 2
    return 10.0 * math.log10(max(np.sum(spec * w) / max(np.sum(spec), 1e-30) * np.mean(x * x), 1e-20))


def level_k(x: np.ndarray, sr: int) -> float:
    """K-weighted level (BS.1770 weighting without gating), dBFS."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / sr), 1e-3)
    r = f / 38.0
    hp = r ** 4 / ((1.0 - r ** 2) ** 2 + (r / 0.5) ** 2)
    s = (f / 1681.0) ** 2
    w = hp * (1.0 + 10.0 ** 0.4 * s) / (1.0 + s)
    return 10.0 * math.log10(max(np.sum(spec * w) / max(np.sum(spec), 1e-30) * np.mean(x * x), 1e-20))


def band_energy(x: np.ndarray, sr: int, lo: float, hi: float) -> np.ndarray:
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    spec[(f < lo) | (f > hi)] = 0.0
    return np.fft.irfft(spec, n) ** 2


def check_bank(car: str, bank: BankSet) -> dict:
    """Bank checks: DC, peaks, cycle lengths, junction smoothness (variant i tail vs variant j head),
    alignment of neighbouring rpm banks (cross-correlation lag after stretching to a common period)."""
    res = {"car": car}
    peaks, dcs, mism = [], [], []
    for key, s in bank.src.items():
        P = int(round(s["period"]))
        for c in s["cycles"]:
            assert len(c) == P + s["overlap"], (car, key, len(c), P)
            peaks.append(np.max(np.abs(c)))
            dcs.append(abs(np.mean(c[:P])) / (np.sqrt(np.mean(c[:P] ** 2)) + 1e-12))
        ov = s["overlap"]
        cyc = s["cycles"]
        for i in range(len(cyc)):
            for j in range(len(cyc)):
                if i != j:
                    tail = cyc[i][P:P + ov]
                    head = cyc[j][:ov]
                    mism.append(np.sqrt(np.mean((tail - head) ** 2)) / (np.sqrt(np.mean(head ** 2)) + 1e-12))
    res["peak_max"] = float(max(peaks))
    res["dc_rel_max"] = float(max(dcs))
    res["junction_mismatch_median"] = float(np.median(mism))
    res["junction_mismatch_p95"] = float(np.percentile(mism, 95))
    # alignment: neighbouring rpm banks (same load), stretched to a common period as the runtime does.
    # Phase-coherent blending needs the correlation at zero lag to be close to the best correlation
    # (a lag of one revolution is fine for engines whose two revolutions sound alike).
    rel, lags = [], []
    nb = len(bank.rpms)
    for load in ("on", "off"):
        for i in range(nb - 1):
            a = bank.src[(i, load)]
            b2 = bank.src[(i + 1, load)]
            Pa = int(round(a["period"]))
            xa = np.mean([c[:Pa] for c in a["cycles"]], axis=0)
            Pb = int(round(b2["period"]))
            xb = np.mean([c[:Pb] for c in b2["cycles"]], axis=0)
            xb = np.interp(np.arange(Pa) * Pb / Pa, np.arange(Pb), xb)
            cc = np.fft.irfft(np.fft.rfft(xa) * np.conj(np.fft.rfft(xb)), Pa)
            rel.append(cc[0] / cc.max())
            near = np.concatenate([np.arange(0, Pa // 24 + 1), np.arange(Pa - Pa // 24, Pa)])   # +-30 deg
            best = near[np.argmax(cc[near])]
            lags.append((best if best <= Pa // 2 else best - Pa) / Pa * 720.0)
    res["align_c0_mean"] = float(np.mean(rel))
    res["align_c0_min"] = float(np.min(rel))
    res["align_lag_deg_mean_abs"] = float(np.mean(np.abs(lags)))
    return res


def check_clicks(bank: BankSet, n_cycles: int = 48) -> dict:
    """Steady playback of every bank at its own rpm with random variants vs. the variants in their natural
    order without any splice (cycle i followed by its own continuation): high-frequency (> 5 kHz) energy
    in the junction window relative to the whole signal. A click would raise the player's ratio above the
    natural one."""
    sr = bank.sr
    ratios = []
    for (i, _), s in bank.src.items():
        P = int(round(s["period"]))
        ov = s["overlap"]
        cyc = s["cycles"]
        rng = np.random.default_rng(11 + i)
        seq = []
        prev = 0
        for _ in range(n_cycles):
            nxt = int(rng.integers(len(cyc) - 1))
            nxt = nxt + 1 if nxt >= prev else nxt
            seq.append((prev, nxt))
            prev = nxt
        y = np.zeros(n_cycles * P)
        for k, (a, b2) in enumerate(seq):
            x = cyc[b2][:P].copy()
            w = np.arange(ov) / ov
            x[:ov] = (1.0 - w) * cyc[a][P:P + ov] + w * x[:ov]
            y[k * P:(k + 1) * P] = x
        nat = np.concatenate([cyc[k % len(cyc)][:P] for k in range(n_cycles)])
        ey = band_energy(y, sr, 5000.0, 15500.0)
        en = band_energy(nat, sr, 5000.0, 15500.0)
        win = np.zeros(len(y), bool)
        for k in range(2, n_cycles):
            win[k * P - 16:k * P + ov] = True
        ry = ey[win].mean() / (ey.mean() + 1e-30)
        rn = en[win].mean() / (en.mean() + 1e-30)
        # sample-step discontinuity at the junction vs typical steps
        d = np.abs(np.diff(y))
        jump = max(d[k * P - 2:k * P + 2].max() for k in range(2, n_cycles)) / (np.percentile(d, 99.9) + 1e-12)
        ratios.append((ry / max(rn, 1e-9), jump))
    r = np.array(ratios)
    return {"hf_junction_excess_max": float(r[:, 0].max()), "hf_junction_excess_median": float(np.median(r[:, 0])),
            "junction_step_vs_p999_max": float(r[:, 1].max())}


def orders_of(bank: BankSet, rpm_target: float, load: str, n: int = 24) -> np.ndarray:
    i = int(np.argmin(np.abs(np.log(bank.rpms / rpm_target))))
    s = bank.src[(i, load)]
    P = int(round(s["period"]))
    per = np.mean([c[:P] for c in s["cycles"]], axis=0)
    spec = np.abs(np.fft.rfft(per)) ** 2
    lv = 10.0 * np.log10(spec[1:n + 1] + 1e-20)
    return lv - lv.max(), bank.rpms[i]


def band_profile(x: np.ndarray, sr: int) -> np.ndarray:
    """Third-octave-ish band levels 50 Hz .. 8 kHz (dB, normalised to the total)."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    edges = 50.0 * 2.0 ** (np.arange(0, 22) / 3.0)
    out = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (f >= lo) & (f < hi)
        out.append(10.0 * math.log10(spec[m].sum() + 1e-20))
    out = np.array(out)
    return out - 10.0 * math.log10(spec.sum() + 1e-20)


def demo_checks(car: str, bank: BankSet, y: np.ndarray, info: dict) -> dict:
    sr = bank.sr
    res = {"peak": float(np.max(np.abs(y))), "clipped_samples": int(np.sum(np.abs(y) >= 1.0)),
           "dc": float(np.mean(y))}
    res["level_a_total"] = level_a(y, sr)
    sc = info["scenario"]
    # full-throttle segment (launch .. lift) and overrun segment (lift .. brake)
    a = int(sc["launch"] * sr) + sr
    b = int(sc["t_lift"] * sr)
    c = int(sc["t_brake"] * sr)
    res["level_a_full"] = level_a(y[a:b], sr)
    res["level_k_full"] = level_k(y[a:b], sr)
    res["level_a_coast"] = level_a(y[b + int(0.3 * sr):c], sr)
    idle_seg = y[int((sc["t_stop"] + 0.5) * sr):int((sc["t_stop"] + 1.9) * sr)]
    res["level_a_idle"] = level_a(idle_seg, sr)
    # clicks in the demo: sample steps at the cycle boundaries (where variants are spliced) compared with
    # the steps at the other cylinders' pulse arrivals (same kind of event, never spliced)
    hp = np.diff(y)
    bnd = info["boundaries"]
    bnd = bnd[(bnd > 4) & (bnd < len(hp) - 4)]
    ncyl = int(bank.engine["cylinders"])
    near = np.zeros(len(hp), bool)
    other = np.zeros(len(hp), bool)
    for k, k2 in zip(bnd[:-1], bnd[1:]):
        near[k - 3:k + 4] = True
        for j in range(1, ncyl):
            o = k + int(round(j * (k2 - k) / ncyl))
            other[o - 3:o + 4] = True
    res["step_boundaries_p99"] = float(np.percentile(np.abs(hp[near]), 99)) if near.any() else 0.0
    res["step_other_pulses_p99"] = float(np.percentile(np.abs(hp[other]), 99)) if other.any() else 0.0
    res["cycles"] = int(len(info["boundaries"]))
    return res


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Motorklang v2: Referenz-Player, Demos und Prüfungen")
    ap.add_argument("--car", action="append", choices=CARS)
    ap.add_argument("--banks", default=os.path.join(ROOT, "assets", "audio", "engines"))
    ap.add_argument("--out", default=SCRATCH)
    ap.add_argument("--no-demo", action="store_true", help="nur die Bank-Prüfungen")
    args = ap.parse_args(argv)
    cars = args.car or CARS
    os.makedirs(args.out, exist_ok=True)
    all_y, summaries, contrast = [], {}, {}
    sr = 32000
    for car in cars:
        bank = BankSet(os.path.join(args.banks, f"{car}.json"))
        sr = bank.sr
        cb = check_bank(car, bank)
        ck = check_clicks(bank)
        print(f"{car}: Spitze {cb['peak_max']:.2f}, DC max {cb['dc_rel_max']:.3f} (rel.), "
              f"Übergang Rest {cb['junction_mismatch_median']:.2f}/{cb['junction_mismatch_p95']:.2f} (Median/P95), "
              f"Ausrichtung Korrelation bei 0° {cb['align_c0_mean']:.2f} (min {cb['align_c0_min']:.2f}), "
              f"Versatz {cb['align_lag_deg_mean_abs']:.1f}°, "
              f"HF-Überhöhung an Übergängen {ck['hf_junction_excess_median']:.2f}/{ck['hf_junction_excess_max']:.2f}, "
              f"Sprung {ck['junction_step_vs_p999_max']:.2f}x P99.9")
        for load in ("on", "off"):
            lv, r = orders_of(bank, 0.45 * bank.engine["redline_rpm"], load)
            top = np.argsort(lv)[::-1][:6]
            print(f"   Ordnungen {load:3s} @ {r:.0f}/min: " + " ".join(f"{(k + 1) / 2:g}:{lv[k]:.0f}" for k in top))
        summaries[car] = {"bank": cb, "clicks": ck}
        if args.no_demo:
            continue
        y, info = render_demo(car, bank)
        dc = demo_checks(car, bank, y, info)
        summaries[car]["demo"] = dc
        print(f"   Demo {len(y) / sr:.1f} s: Spitze {dc['peak']:.2f} ({dc['clipped_samples']} übersteuert), "
              f"Pegel A gesamt {dc['level_a_total']:.1f} dB, Vollgas {dc['level_a_full']:.1f} (K {dc['level_k_full']:.1f}), "
              f"Schub {dc['level_a_coast']:.1f}, Leerlauf {dc['level_a_idle']:.1f}; Sprünge (P99) an "
              f"{dc['cycles']} Zyklusgrenzen {dc['step_boundaries_p99']:.4f} vs an den übrigen Zylinderimpulsen "
              f"{dc['step_other_pulses_p99']:.4f}")
        path = os.path.join(args.out, f"{car}_demo.wav")
        write_wav(path, y, sr)
        encode_and_plot(path, car)
        all_y.append(y)
        all_y.append(np.zeros(int(0.8 * sr)))
        sc = info["scenario"]
        full = y[int(sc["launch"] * sr) + sr:int(sc["t_lift"] * sr)]
        lv, _ = orders_of(bank, 0.45 * bank.engine["redline_rpm"], "on", 16)
        contrast[car] = {"bands": band_profile(full, sr), "orders": lv}
    if all_y:
        path = os.path.join(args.out, "all_cars_demo.wav")
        write_wav(path, np.concatenate(all_y), sr)
        encode_and_plot(path, "alle")
    if len(contrast) > 1:
        # how different are the cars? spectral envelope at full load (third-octave bands, dB RMS difference)
        # and rhythm (correlation of the order fingerprints, 0.5 .. 8th order, at 45 % of the redline)
        names = list(contrast)
        print("Unterschied der Autos – Spektrum Vollgas (dB RMS über Terzbänder) / Ordnungsmuster (Korrelation):")
        for a in names:
            row = []
            for b2 in names:
                d = float(np.sqrt(np.mean((contrast[a]["bands"] - contrast[b2]["bands"]) ** 2)))
                oa, ob = contrast[a]["orders"], contrast[b2]["orders"]
                c = float(np.corrcoef(np.maximum(oa, -40.0), np.maximum(ob, -40.0))[0, 1])
                row.append(f"{d:4.1f}/{c:+.2f}")
            print(f"   {a:12s} " + "  ".join(row))
            summaries[a]["contrast"] = row
    with open(os.path.join(args.out, "checks.json"), "w", encoding="utf-8") as fh:
        json.dump(summaries, fh, indent=1, default=float)
    return 0


if __name__ == "__main__":
    sys.exit(main())
