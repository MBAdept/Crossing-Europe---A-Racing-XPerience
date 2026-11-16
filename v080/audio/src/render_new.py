#!/usr/bin/env python3
"""Spike 1: renders the "modern" vehicle sound for the scripted drive of out/drive_old.csv (see engine3.py)."""
from __future__ import annotations
import math, os, sys, json
import numpy as np
import alib
from alib import k_weight, short_term, integrated_lufs, write_wav, read_audio
from bankio import Bank
from engine3 import *

W = alib.WORK
CTRL = 1000                      # control rate (Hz) for smoothed parameters


def ctrl_to_audio(x: np.ndarray, n: int) -> np.ndarray:
    return np.interp(np.arange(n) / SR, np.arange(len(x)) / CTRL, x)


def main() -> None:
    car = "gran_turismo"
    tr = Trace(W + "/out/drive_old.csv")
    bank = Bank(W + "/bank3/%s.json" % car)
    eng = bank.engine
    idle, red = float(eng["idle_rpm"]), float(eng["redline_rpm"])
    layers = bank.layers
    n = int(tr.dur * SR)
    ta = np.arange(n) / SR
    tc = np.arange(int(tr.dur * CTRL)) / CTRL
    rng = np.random.default_rng(20260808)
    dtf = float(tr.t[1] - tr.t[0])

    # ---- control signals -------------------------------------------------------------------------------
    rpm_c = np.interp(tc, tr.t, tr.rpm)
    load_raw = tr.at(tr.load, tc, hold=True)
    load_c = smooth_ar(load_raw, 0.022, 0.060, CTRL)
    load_c = np.maximum(load_c, 0.2 * np.clip(1.0 - (rpm_c - idle) / (0.5 * idle), 0.0, 1.0))   # idle load share
    speed_c = np.interp(tc, tr.t, tr.speed)
    thr_c = tr.at(tr.thr, tc, hold=True)
    rpm = ctrl_to_audio(rpm_c, n) * (1.0 + 0.0012 * slow_noise(rng, n, 0.3, 2.5))
    wob = slow_noise(rng, n, 0.2, 3.0)
    load = np.clip(ctrl_to_audio(load_c, n) * (1.0 + 0.05 * wob), 0.0, 1.0)
    on_gain = 10 ** (0.6 * slow_noise(rng, n, 0.3, 5.0) / 20.0)
    speed = ctrl_to_audio(speed_c, n)

    # ---- 1. cycle bank (stereo) -------------------------------------------------------------------------
    player = CyclePlayer(bank, seed=11, cycle_jitter_db=0.5)
    cyc = player.render(rpm, load, on_gain)
    # start clip, loop fades in near its end (as EngineAudio.start)
    start = bank.clips["start"][0]
    t_loop = max(len(start) / SR - 0.3, 0.01)
    loop_gain = np.clip((ta - t_loop) / 0.25, 0.0, 1.0)
    cyc *= loop_gain[:, None]
    # ---- 2. load-dependent saturation ("bark"): more drive with load x rpm --------------------------------
    drive = 1.0 + 1.25 * ctrl_to_audio(load_c * np.clip(rpm_c / red, 0.0, 1.0), n)
    bias = 0.10 * (drive - 1.0)
    engine = (np.tanh(cyc * drive[:, None] + bias[:, None]) - np.tanh(bias)[:, None]) / (drive[:, None] ** 0.55)
    place(engine, start, 0, 1.0)

    # ---- 3. events from the trace (logic of EngineAudio._update_layers) -------------------------------------
    cr = layers.get("crackle", {})
    bo = layers.get("blowoff", {})
    events = []
    load_peak = 0.0
    armed = False
    last_up = -10.0
    crackle_left = 0.0
    crackle_amt = 0.0
    prev_thr = 0.0
    for i in range(1, len(tr.t)):
        t = float(tr.t[i])
        ld = float(tr.load[i]); r = float(tr.rpm[i])
        if tr.gear[i] > tr.gear[i - 1] > 0:
            last_up = t
            if load_peak > 0.6 and r > 0.4 * red:
                events.append((t, "shift", 0.55 + 0.35 * min(r / red, 1.0)))
            events.append((t, "thump", 0.5 + 0.5 * min(float(tr.load[i - 1]), 1.0)))
        elif tr.gear[i] < tr.gear[i - 1] and tr.gear[i] > 0:
            events.append((t, "thump", 0.45))
        load_peak = max(ld, load_peak - dtf / 0.35)
        if ld > 0.5:
            armed = True
            if ld > 0.6:
                crackle_left = 0.0
        upshift_cut = (t - last_up) < 0.2
        if armed and ld < 0.2 and load_peak > 0.6 and not upshift_cut:
            armed = False
            if cr and r >= cr["min_rpm"]:
                crackle_left = cr["duration_s"]
                crackle_amt = min(max(0.45 + 0.55 * (r - cr["min_rpm"]) / max(red - cr["min_rpm"], 1.0), 0.45), 1.0)
            if bo and tr.boost[i - 1] >= bo["min_boost"]:
                events.append((t, "blowoff", bo["level"] * min(float(tr.boost[i - 1]), 1.0)))
        if crackle_left > 0.0:
            crackle_left -= dtf
            if ld < 0.3:
                x = min(max(crackle_left / cr["duration_s"], 0.0), 1.0)
                if rng.random() < cr["rate_hz"] * (0.3 + 0.7 * x) * crackle_amt * dtf:
                    events.append((t + rng.random() * dtf, "crackle", cr["level"] * rng.uniform(0.35, 1.0) * (0.35 + 0.65 * x * crackle_amt)))
        th = float(tr.thr[i])
        if th >= 0.9 and prev_thr <= 0.35 and tr.speed[i] > 20.0 and tr.gear[i] > 0:
            events.append((t, "tipin", 1.0))
        prev_thr = th

    # clips of the modern profile that are not in the bank: tip-in, driveline thump, blow-off with flutter
    def thump_clip(f0, f1, dur, click=0.0):
        m = int(dur * 4 * SR)
        t = np.arange(m) / SR
        f = f1 + (f0 - f1) * np.exp(-t / (dur * 0.5))
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / dur) * (1.0 - np.exp(-t / 0.003))
        if click:
            y += click * shaped_noise(rng, m, lambda ff: bp(ff, 300.0, 2200.0, 1)) * np.exp(-t / 0.012)
        return y

    tip_thump = thump_clip(58.0, 38.0, 0.055, 0.25)
    m = int(0.35 * SR); t = np.arange(m) / SR
    gulp = np.stack([shaped_noise(rng, m, lambda ff: bp(ff, 280.0, 2600.0, 1) * peak(ff, 620.0, 2.0, 6.0)) for _ in range(2)], axis=1)
    gulp = (0.75 * gulp + 0.25 * gulp[:, ::-1]) * ((1.0 - np.exp(-t / 0.008)) * np.exp(-t / 0.085))[:, None]
    shift_thump = thump_clip(72.0, 44.0, 0.045, 0.35)
    # blow-off: falling noise band, flutter (compressor surge) decaying, two partly correlated channels
    m = int(0.75 * SR); t = np.arange(m) / SR
    fcb = 1350.0 + (4800.0 - 1350.0) * np.exp(-t / 0.22)
    bov = np.zeros((m, 2))
    for c in range(2):
        nz = rng.standard_normal(m)
        y = np.zeros(m); y1 = y2 = 0.0
        for i in range(m):
            w = 2.0 * math.pi * fcb[i] / SR
            rr = math.exp(-w / 2.4)
            y0 = (1.0 - rr) * nz[i] + 2.0 * rr * math.cos(w) * y1 - rr * rr * y2
            y[i] = y0; y2, y1 = y1, y0
        bov[:, c] = y / (np.sqrt(np.mean(y[:int(0.1 * SR)] ** 2)) + 1e-12)
    bov = 0.8 * bov + 0.2 * bov[:, ::-1]
    envb = (1.0 - np.exp(-t / 0.005)) * np.exp(-t / 0.30)
    envb *= 1.0 - 0.6 * np.exp(-t / 0.16) * (0.5 - 0.5 * np.cos(2.0 * np.pi * 19.0 * t)) * (t > 0.03)
    bov = bov * envb[:, None] + (2.2 * np.sin(2 * np.pi * 92.0 * t) * np.exp(-t / 0.035) * (1.0 - np.exp(-t / 0.004)))[:, None]
    bov *= 0.5 / np.max(np.abs(bov))

    clips_bus = np.zeros((n, 2))
    n_ev = {}
    for (t, kind, g) in events:
        at = int(t * SR)
        n_ev[kind] = n_ev.get(kind, 0) + 1
        if kind == "crackle":
            c = bank.clips["crackle"][int(rng.integers(len(bank.clips["crackle"])))]
            place(clips_bus, c, at, g)
        elif kind == "shift":
            c = bank.clips["shift"][int(rng.integers(len(bank.clips["shift"])))]
            place(clips_bus, c, at + int(0.01 * SR), g)
        elif kind == "blowoff":
            place(clips_bus, bov, at + int(0.02 * SR), g * 2.0)
        elif kind == "tipin":
            place(clips_bus, tip_thump, at + int(0.03 * SR), 0.28)
            place(clips_bus, gulp, at + int(0.02 * SR), 0.10)
        elif kind == "thump":
            place(clips_bus, shift_thump, at + int(0.06 * SR), 0.22 * g)

    # ---- 4. turbo: two chargers, narrow-band tones (phase noise) + flow hiss, level from boost/shaft ----------
    tb = layers.get("turbo")
    turbo = np.zeros((n, 2))
    if tb:
        boost_f = tr.boost
        shaft_f = np.zeros(len(tr.t))
        sh = 0.0
        for i in range(len(tr.t)):
            st = 0.75 * boost_f[i] + 0.25 * min(tr.rpm[i] / red, 1.0) * (0.3 + 0.7 * tr.load[i])
            sh += (st - sh) * (1.0 - math.exp(-dtf / (0.35 * tb["spool_s"] if st > sh else 0.9)))
            shaft_f[i] = sh
        shaft = np.clip(np.interp(ta, tr.t, shaft_f), 0.0, 1.0)
        boost = np.clip(np.interp(ta, tr.t, boost_f), 0.0, 1.0)
        amp = 0.036 * shaft ** 1.6 * (0.35 + 0.65 * ctrl_to_audio(load_c, n))
        for c, det in ((0, 0.982), (1, 1.021)):
            f = (1500.0 + (4300.0 - 1500.0) * shaft ** 0.8) * det * (1.0 + 0.004 * slow_noise(rng, n, 0.5, 6.0))
            ph = 2.0 * np.pi * np.cumsum(f) / SR + 1.6 * slow_noise(rng, n, 2.0, 40.0)
            tone = np.sin(ph) + 0.25 * np.sin(2.0 * ph + 0.7)
            hiss = shaped_noise(rng, n, lambda ff: bp(ff, 2600.0, 9500.0, 2))
            sig = amp * tone * (1.0 + 0.1 * slow_noise(rng, n, 1.0, 12.0)) + 0.030 * boost ** 1.5 * (0.4 + 0.6 * shaft) * hiss
            turbo[:, c] += 0.8 * sig
            turbo[:, 1 - c] += 0.2 * sig

    # ---- 5. driveline whine: final drive (road speed) and gear mesh (engine speed) ------------------------------
    v_ms = speed / 3.6
    ld_a = ctrl_to_audio(load_c, n)
    f_fd = v_ms / 2.05 * 3.2 * 12.0 * (1.0 + 0.003 * slow_noise(rng, n, 4.0, 30.0)) * (1.0 - 0.006 * (ld_a < 0.2))
    f_gm = rpm / 60.0 * 29.0
    moving = np.clip(speed / 25.0, 0.0, 1.0)
    a_fd = 0.020 * np.clip(speed / 250.0, 0.0, 1.2) ** 1.2 * (0.45 + 0.55 * ld_a) * moving
    a_gm = 0.012 * np.clip(rpm / red, 0.0, 1.0) ** 1.5 * (0.3 + 0.7 * ld_a) * moving
    ph1 = 2.0 * np.pi * np.cumsum(f_fd) / SR
    ph2 = 2.0 * np.pi * np.cumsum(f_gm) / SR
    whine = a_fd * (np.sin(ph1) + 0.3 * np.sin(2.0 * ph1)) + a_gm * (np.sin(ph2) + 0.3 * np.sin(2.0 * ph2 + 1.0))
    whine = np.stack([whine, whine], axis=1)

    # ---- early reflections of the car bus (road, guardrails) and a distant slap for the bangs ---------------
    car_dry = engine + clips_bus + turbo + whine

    def lowpass_fft(x, fc):
        X = np.fft.rfft(x, axis=0)
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        return np.fft.irfft(X / (1.0 + (f / fc) ** 2)[:, None], len(x), axis=0)

    er_src = lowpass_fft(car_dry, 4500.0)
    er = np.zeros_like(car_dry)
    for (d_ms, src_ch, dst_ch, g_db) in ((11.3, 0, 0, -15.0), (15.1, 1, 1, -15.0), (19.7, 0, 1, -19.0), (23.9, 1, 0, -19.0)):
        d = int(d_ms * 1e-3 * SR)
        er[d:, dst_ch] += er_src[:-d, src_ch] * 10 ** (g_db / 20.0)
    slap_src = lowpass_fft(clips_bus, 2500.0)
    for (d_ms, flip, g_db) in ((187.0, False, -19.0), (311.0, True, -25.0)):
        d = int(d_ms * 1e-3 * SR)
        er[d:] += (slap_src[:-d, ::-1] if flip else slap_src[:-d]) * 10 ** (g_db / 20.0)
    car = car_dry + er

    # ---- 6. tyres (left / right wheels), 7. wind (three bands, gusts) - loops with pitch and level laws -------
    def loop_noise(seconds, gain_fn, seed):
        r = np.random.default_rng(seed)
        m = int(seconds * SR)
        X = np.fft.rfft(r.standard_normal(m))
        f = np.fft.rfftfreq(m, 1.0 / SR)
        y = np.fft.irfft(X * gain_fn(np.maximum(f, 1e-3)), m)       # periodic by construction
        return y / np.sqrt(np.mean(y * y))

    def tyre_fn(f):
        return (bp(f, 320.0, 1350.0, 1) * peak(f, 218.0, 10.0, 8.0) * peak(f, 1000.0, 1.2, 3.0)
                + 0.55 * bp(f, 32.0, 105.0, 2))

    tyres = np.zeros((n, 2))
    v_rel = np.maximum(speed, 1.0) / 120.0
    for c in range(2):
        lp = loop_noise(6.0, tyre_fn, 500 + c)
        sig = varispeed(lp, v_rel ** 0.45, start=1000.0 * c)
        surf = 10 ** (1.2 * slow_noise(rng, n, 0.25, 3.0) / 20.0)
        tyres[:, c] = sig * v_rel ** 1.5 * np.clip((speed - 4.0) / 20.0, 0.0, 1.0) * surf
    tyres = 0.85 * tyres + 0.15 * tyres[:, ::-1]

    wind = np.zeros((n, 2))
    vw = np.maximum(speed, 1.0) / 200.0
    gust_common = slow_noise(rng, n, 0.15, 1.2)
    for c in range(2):
        gust = 10 ** ((1.3 * gust_common + 1.5 * slow_noise(rng, n, 0.2, 1.8)) / 20.0)
        lo = varispeed(loop_noise(7.0, lambda f: bp(f, 28.0, 190.0, 2) / np.sqrt(f / 60.0), 700 + c), vw ** 0.3)
        mid = varispeed(loop_noise(7.0, lambda f: bp(f, 260.0, 1700.0, 1), 720 + c), vw ** 0.5)
        hi = varispeed(loop_noise(7.0, lambda f: bp(f, 2600.0, 7500.0, 2), 740 + c), vw ** 0.5)
        wind[:, c] = (1.0 * lo + 0.75 * mid * gust + 0.27 * hi * gust) * vw ** 2.75 * np.clip((speed - 25.0) / 40.0, 0.0, 1.0)
    wind = 0.8 * wind + 0.2 * wind[:, ::-1]

    # ---- 8. road details: expansion joints (front, rear axle) and pass-by whooshes of roadside objects -------
    world = np.zeros((n, 2))
    t_flat = tr.phase_time("flat_out")
    t_c130 = tr.phase_time("cruise130")
    t_kick = tr.phase_time("kickdown")
    joint = thump_clip(78.0, 52.0, 0.03, 0.9)
    for tj in (t_flat[0] + 1.3, t_flat[0] + 3.4, t_c130[0] + 1.2, t_c130[0] + 3.1):
        v = float(np.interp(tj, tr.t, tr.speed)) / 3.6
        place(world, joint, int(tj * SR), 0.20)
        place(world, joint, int((tj + 2.9 / max(v, 5.0)) * SR), 0.26)
    for (tw, side, big) in ((t_flat[0] + 0.7, 1, False), (t_flat[0] + 2.3, -1, False), (t_flat[0] + 4.4, 0, True),
                            (t_flat[0] + 5.3, 1, False), (t_c130[0] + 2.2, -1, False), (t_kick[0] + 2.6, 1, False),
                            (t_kick[0] + 3.4, -1, False)):
        v = float(np.interp(tw, tr.t, tr.speed)) / 3.6
        dur = float(np.clip(14.0 / max(v, 5.0), 0.12, 0.45)) * (1.6 if big else 1.0)
        m = int(dur * SR)
        t = np.arange(m) / SR
        x = t / dur
        env = np.sin(np.pi * np.clip(x, 0, 1)) ** 2.0
        nz = shaped_noise(rng, m, lambda f: bp(f, 500.0 if not big else 120.0, 5200.0, 1))
        sw = nz * env
        if side == 0:      # bridge: both sides, engine reflection boost
            place(world, np.stack([sw, shaped_noise(rng, m, lambda f: bp(f, 120.0, 5200.0, 1)) * env], axis=1), int(tw * SR), 0.16 * (v / 60.0))
            a0 = int(tw * SR)
            seg = car_dry[a0:a0 + m] * env[:len(car_dry[a0:a0 + m]), None] * 0.5
            d = int(0.006 * SR)
            world[a0 + d:a0 + d + len(seg)] += seg[:len(world[a0 + d:a0 + d + len(seg)])]
        else:
            pan = side * (0.35 + 0.6 * x)
            ang = (pan + 1.0) * np.pi / 4.0
            st = np.stack([sw * np.cos(ang), sw * np.sin(ang)], axis=1) * math.sqrt(2.0)
            place(world, st, int(tw * SR), 0.11 * (v / 60.0))

    # ---- mix ------------------------------------------------------------------------------------------------
    G_CAR, G_TYRES, G_WIND, G_WORLD = 1.0, 0.0334, 0.055, 1.0
    road = G_TYRES * tyres + G_WIND * wind + G_WORLD * world
    full = G_CAR * car + road
    eng_only = G_CAR * car
    # level: same short-term loudness as the old recording in the full-throttle run through the gears
    old = read_audio(W + "/out/drive_old.wav", SR)
    a, b = tr.phase_time("launch")
    sl = slice(int((a + 1.0) * SR), int(b * SR))

    def seg_lufs(x):
        xk = k_weight(x[sl], SR)
        return -0.691 + 10 * np.log10(np.mean(np.sum(xk * xk, axis=1)))

    g = 10 ** ((seg_lufs(old) - seg_lufs(full)) / 20.0)
    print("Pegelabgleich Vollgasphase: alt %.2f LUFS, neu roh %.2f LUFS -> Gain %.2f dB" % (seg_lufs(old), seg_lufs(full), 20 * math.log10(g)))
    full_m = lookahead_limiter(full * g)
    eng_m = lookahead_limiter(eng_only * g)
    fade = int(0.05 * SR)
    for x in (full_m, eng_m):
        x[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    write_wav(W + "/out/drive_new_full.wav", full_m, SR)
    write_wav(W + "/out/drive_new_engine_only.wav", eng_m, SR)
    stems = {"engine_cycles": engine, "clips": clips_bus, "turbo": turbo, "driveline": whine, "reflections": er,
             "tyres": G_TYRES * tyres, "wind": G_WIND * wind, "world": G_WORLD * world}
    info = {"events": n_ev, "gain_db": 20 * math.log10(g), "stems_lufs_flat_out": {}, "stems_lufs_cruise130": {}}
    for nm, x in stems.items():
        for key, (ta_, tb_) in (("stems_lufs_flat_out", t_flat), ("stems_lufs_cruise130", t_c130)):
            s2 = slice(int(ta_ * SR), int(tb_ * SR))
            xk = k_weight(x[s2] * g, SR)
            info[key][nm] = round(float(-0.691 + 10 * np.log10(max(np.mean(np.sum(xk * xk, axis=1)), 1e-12))), 1)
    json.dump(info, open(W + "/out/drive_new_info.json", "w"), indent=1)
    print(json.dumps(info, indent=1))


if __name__ == "__main__":
    main()
