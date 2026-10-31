#!/usr/bin/env python3
"""Engine cycle bank fixtures for the engine sound runtime (format: docs/motorsound.md §1).

Small synthetic banks, so the runtime (scripts/audio/engine_bank.gd, engine_gearbox.gd, engine_audio.gd) can be
developed and tested without the real banks of tools/audio/engine_synth.py:

  engines/fixture_v4.json + .f32   valid bank: 16 kHz, four rpm points 2000-3900 (factor <= 1.25), both loads,
                                   8 variants per bank whose cycles are DELIBERATELY DIFFERENT (per-variant level
                                   and a low-frequency component with a per-variant phase), so splicing two
                                   variants without the runtime's overlap crossfade jumps at the boundary.
                                   Clips crackle x3, blowoff, shift, start; layers turbo, crackle, blowoff,
                                   limiter. 16 kHz instead of the contract's 32 kHz keeps the file small (the
                                   loader reports that as a warning, not an error).
  engines/broken_*.json            broken banks for the loader validation (they share fixture_v4.f32):
                                   broken_format (unknown format id), broken_missing_load (an rpm point without
                                   its "off" bank), broken_cycle_range (cycle beyond the data), broken_length
                                   (cycle length != round(period) + overlap), broken_no_data (data file missing)

  --demo DIR   additionally writes demo_v8.json/.f32: a full-range V8-like bank (32 kHz, 700-7200 rpm, gearbox of
               the contract example, turbo/crackle/blowoff/limiter layers, all clips) for
               tools/audio/render_engine_demo.gd. Not committed (about 2 MB); it shows the runtime behaviour
               (gears, blips, crackles, limiter), not the quality of the real synthesis.

The signal model is deliberately simple: exhaust pulses per firing event (with cycle-to-cycle jitter) through a
sum of decaying resonances, noise bursts on load. Every cycle starts at the arrival of cylinder 1's pulse.

Usage (numpy):  python3 tests/fixtures/make_engine_fixtures.py [--out tests/fixtures/engines] [--demo DIR]
"""

import argparse
import copy
import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FORMAT = "ce-engine-bank-1"


# --- signal helpers -------------------------------------------------------------------------------

def fftconv(x, h):
    n = len(x) + len(h) - 1
    nfft = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(h, nfft), nfft)[:n]


def lowpass(x, sr, cutoff, taps=129):
    """Windowed-sinc FIR low-pass (zero phase)."""
    fc = min(cutoff / sr, 0.49)
    n = np.arange(taps) - (taps - 1) / 2
    h = 2 * fc * np.sinc(2 * fc * n) * np.hanning(taps)
    h /= h.sum()
    return fftconv(x, h)[(taps - 1) // 2:(taps - 1) // 2 + len(x)]


def bandpass(x, sr, lo, hi):
    return lowpass(x, sr, hi) - lowpass(x, sr, lo)


def normalize(x, peak):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def exhaust_ir(sr, res, length_s=0.08):
    t = np.arange(int(length_s * sr)) / sr
    ir = np.zeros_like(t)
    for f0, tau, g in res:
        if f0 < 0.45 * sr:
            ir += g * np.exp(-t / tau) * np.sin(2 * np.pi * f0 * t)
    return ir


def render_engine(rpm, load, sr, n_cycles, eng, rng):
    """Steady-state engine signal of n_cycles working cycles. Firing events at eng['firing'] (fractions of the
    cycle; the first one = cylinder 1 at the cycle start), level per event eng['amps'], per-event exhaust delay
    eng['delay_ms'] (e.g. two banks of a V8). Returns (signal, period in samples)."""
    period = 120.0 * sr / rpm
    n = int(math.ceil(period * n_cycles)) + 512
    exc = np.zeros(n + 8)
    on = load == "on"
    level = 1.0 if on else eng["off_level"]
    rpm_n = rpm / eng["limiter"]
    for c in range(n_cycles):
        cycle_amp = 1.0 + rng.normal(0.0, eng["jitter"])
        for k, (frac, amp) in enumerate(zip(eng["firing"], eng["amps"])):
            t = (c + frac) * period + eng["delay_ms"][k] * 0.001 * sr
            if k > 0:
                t += rng.normal(0.0, eng["timing_jitter"] * period / len(eng["firing"]))
            i = int(math.floor(t))
            fr = t - i
            a = amp * cycle_amp * level * (1.0 + rng.normal(0.0, 0.06)) * (0.75 + 0.5 * rpm_n)
            exc[i] += a * (1.0 - fr)
            exc[i + 1] += a * fr
    exc = exc[:n]
    res = [(f0 * (1.0 + 0.12 * rpm_n), tau, g * (1.0 + (eng["bright"] * rpm_n if on else 0.0)))
           for f0, tau, g in eng["res"]]
    sig = fftconv(exc, exhaust_ir(sr, res))[:n]
    if on:
        env = fftconv(np.abs(exc), np.exp(-np.arange(int(0.004 * sr)) / (0.0012 * sr)))[:n]
        sig += eng["noise"] * lowpass(rng.normal(0.0, 1.0, n), sr, 0.4 * sr) * env
    sig -= np.mean(sig)
    return sig, period


# --- clips ----------------------------------------------------------------------------------------

def clip_crackle(sr, rng, i, length=0.05):
    n = int(length * sr)
    t = np.arange(n) / sr
    crack = bandpass(rng.normal(0.0, 1.0, n), sr, 900.0 + 400.0 * i, 0.42 * sr) * np.exp(-t / (0.004 + 0.0015 * i))
    thump = np.sin(2 * np.pi * (85.0 + 35.0 * i) * t) * np.exp(-t / 0.014)
    x = crack + 0.6 * thump
    x *= np.minimum(1.0, t / 0.0005)
    return normalize(x, 0.8)


def clip_blowoff(sr, rng, length=0.25):
    n = int(length * sr)
    t = np.arange(n) / sr
    x = bandpass(rng.normal(0.0, 1.0, n), sr, 1500.0, min(6000.0, 0.45 * sr))
    env = np.minimum(1.0, t / 0.008) * np.exp(-t / (0.3 * length)) * (1.0 + 0.3 * np.sin(2 * np.pi * 38.0 * t))
    return normalize(x * env, 0.6)


def clip_shift(sr, rng, length=0.05):
    n = int(length * sr)
    t = np.arange(n) / sr
    x = bandpass(rng.normal(0.0, 1.0, n), sr, 400.0, 0.4 * sr) * np.exp(-t / 0.006)
    x += 0.9 * np.sin(2 * np.pi * 70.0 * t) * np.exp(-t / 0.018)
    return normalize(x, 0.8)


def clip_start(sr, rng, eng, length=0.5):
    """Starter cranking (whine + compression strokes), then the engine catches and flares above idle."""
    n = int(length * sr)
    t = np.arange(n) / sr
    crank_end = 0.45 * length
    whine = 0.25 * np.sin(2 * np.pi * 210.0 * t + 3.0 * np.sin(2 * np.pi * 9.0 * t))
    strokes = 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * 9.0 * t)) ** 4
    crank = (whine + strokes * bandpass(rng.normal(0.0, 1.0, n), sr, 100.0, 1500.0)) * (t < crank_end)
    exc = np.zeros(n + 2)
    tt = crank_end
    rpm = 350.0
    while tt < length:
        i = int(tt * sr)
        exc[i] += 1.0 + rng.normal(0.0, 0.1)
        rpm = min(rpm * 1.18, eng["idle"] * 1.45)
        tt += 120.0 / rpm / len(eng["firing"])
    run = fftconv(exc[:n], exhaust_ir(sr, eng["res"]))[:n]
    x = normalize(crank, 0.35) + normalize(run, 0.7)
    x *= np.minimum(1.0, (length - t) / 0.03)
    return normalize(x, 0.75)


# --- bank -----------------------------------------------------------------------------------------

def make_bank(name, sr, eng, rpms, n_var, overlap, seed, different, gearbox, layers, mix, clip_len):
    """Returns (meta dict, float32 data)."""
    rng = np.random.default_rng(seed)
    warm = 3
    rendered = {}
    for rpm in rpms:
        for load in ("off", "on"):
            rendered[(rpm, load)] = render_engine(rpm, load, sr, warm + n_var + 2, eng, rng)
    mid = rpms[len(rpms) // 2]
    sig_mid, p_mid = rendered[(mid, "on")]
    peak_mid = np.max(np.abs(sig_mid[int(warm * p_mid):]))
    peak_all = max(np.max(np.abs(s[int(warm * p):])) for s, p in rendered.values())
    norm = min(0.708 / peak_mid, 0.85 / peak_all)
    scales = (1.2, 0.7, 1.1, 0.8, 1.15, 0.75, 1.05, 0.85)
    chunks = []
    offset = 0
    banks = []
    for rpm in rpms:
        for load in ("off", "on"):
            sig, period = rendered[(rpm, load)]
            sig = sig * norm
            length = int(round(period)) + overlap
            cycles = []
            for k in range(n_var):
                start = int(round((warm + k) * period))
                cyc = sig[start:start + length].copy()
                if different:
                    lf = 0.12 * np.sin(2.0 * np.pi * 2.0 * np.arange(length) / period + 2.0 * np.pi * k / n_var)
                    cyc = cyc * scales[k % len(scales)] + lf
                chunks.append(cyc.astype(np.float32))
                cycles.append([offset, length])
                offset += length
            banks.append({"rpm": rpm, "load": load, "period": round(period, 3), "overlap": overlap,
                          "cycles": cycles})
    clips = {}
    clip_rng = np.random.default_rng(seed + 1)
    clip_sets = {
        "crackle": [clip_crackle(sr, clip_rng, i, clip_len["crackle"]) for i in range(3)],
        "blowoff": [clip_blowoff(sr, clip_rng, clip_len["blowoff"])],
        "shift": [clip_shift(sr, clip_rng, clip_len["shift"])],
        "start": [clip_start(sr, clip_rng, eng, clip_len["start"])],
    }
    for cname, sounds in clip_sets.items():
        clips[cname] = []
        for snd in sounds:
            chunks.append(snd.astype(np.float32))
            clips[cname].append([offset, len(snd)])
            offset += len(snd)
    data = np.concatenate(chunks).astype("<f4")
    peak = float(np.max(np.abs(data)))
    if peak > 0.98:
        data *= np.float32(0.98 / peak)
    meta = {
        "format": FORMAT,
        "car": name,
        "sample_rate": sr,
        "data": name + ".f32",
        "engine": eng["meta"],
        "gearbox": gearbox,
        "banks": banks,
        "clips": clips,
        "layers": layers,
        "mix": mix,
    }
    return meta, data


def write_bank(out_dir, meta, data):
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, meta["car"] + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write("\n")
    data.astype("<f4").tofile(os.path.join(out_dir, meta["data"]))
    print("%s: %d banks, %d samples (%.0f KB) at %d Hz" % (meta["car"], len(meta["banks"]), len(data),
                                                         len(data) * 4 / 1024.0, meta["sample_rate"]))


def write_json(out_dir, name, meta):
    with open(os.path.join(out_dir, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write("\n")


# --- engines --------------------------------------------------------------------------------------

R4 = {
    "meta": {"label": "Testmotor 2,0 l R4 Turbo", "cylinders": 4, "layout": "inline", "fuel": "petrol",
             "aspiration": "turbo", "idle_rpm": 2000, "redline_rpm": 3700, "limiter_rpm": 3900},
    "idle": 2000.0, "limiter": 3900.0,
    "firing": [0.0, 0.25, 0.5, 0.75], "amps": [1.0, 0.82, 0.93, 0.78], "delay_ms": [0.0, 0.0, 0.0, 0.0],
    "jitter": 0.05, "timing_jitter": 0.01, "off_level": 0.4, "bright": 0.8, "noise": 0.25,
    "res": [(95.0, 0.03, 1.0), (240.0, 0.012, 0.6), (610.0, 0.006, 0.4), (1450.0, 0.003, 0.25)],
}

V8 = {
    "meta": {"label": "Demo 4,0 l V8 Biturbo (synthetisch)", "cylinders": 8, "layout": "v_crossplane",
             "fuel": "petrol", "aspiration": "turbo", "idle_rpm": 700, "redline_rpm": 7000, "limiter_rpm": 7200},
    "idle": 700.0, "limiter": 7200.0,
    # firing order 1-8-4-3-6-5-7-2; banks L R L L R L R R -> uneven pulse trains per bank (burble)
    "firing": [i / 8.0 for i in range(8)],
    "amps": [1.0, 0.7, 0.95, 0.9, 0.68, 0.97, 0.72, 0.66],
    "delay_ms": [0.0, 0.7, 0.0, 0.0, 0.7, 0.0, 0.7, 0.7],
    "jitter": 0.06, "timing_jitter": 0.015, "off_level": 0.35, "bright": 1.2, "noise": 0.3,
    "res": [(70.0, 0.04, 1.0), (165.0, 0.018, 0.7), (420.0, 0.008, 0.45), (1100.0, 0.004, 0.3),
            (2600.0, 0.0015, 0.15)],
}

LAYERS = {
    "turbo": {"whistle_hz": [1800, 5200], "level": 0.10, "spool_s": 0.55, "boost_rpm": 2200},
    "crackle": {"min_rpm": 3200, "rate_hz": 7.0, "duration_s": 1.4, "level": 0.6},
    "blowoff": {"min_boost": 0.55, "level": 0.5},
    "limiter": {"cut_cycles": 2, "on_cycles": 3},
}


def fixture_v4():
    gearbox = {"kmh_per_1000rpm": [12.0, 19.0, 27.0, 35.0, 44.0, 54.0, 63.0], "final_note": "Testgetriebe",
               "upshift_rpm": [2600, 3700], "downshift_rpm": [2150, 2700], "shift_time_s": 0.15,
               "launch_rpm": 2800}
    layers = copy.deepcopy(LAYERS)
    layers["turbo"]["boost_rpm"] = 2400
    layers["crackle"]["min_rpm"] = 2600
    return make_bank("fixture_v4", 16000, R4, [2000, 2500, 3125, 3900], 8, 32, 41, True, gearbox, layers,
                     {"gain": 1.0, "off_gain": 0.5},
                     {"crackle": 0.04, "blowoff": 0.2, "shift": 0.04, "start": 0.4})


def demo_v8():
    gearbox = {"kmh_per_1000rpm": [9.0, 14.5, 21.0, 28.5, 35.5, 43.0, 52.0], "final_note": "Beispiel aus dem Vertrag",
               "upshift_rpm": [3000, 6800], "downshift_rpm": [1300, 4200], "shift_time_s": 0.18,
               "launch_rpm": 2600}
    rpms = [700, 860, 1060, 1300, 1600, 1970, 2420, 2980, 3660, 4500, 5530, 6400, 7200]
    return make_bank("demo_v8", 32000, V8, rpms, 8, 96, 7, False, gearbox, copy.deepcopy(LAYERS),
                     {"gain": 1.0, "off_gain": 0.42},
                     {"crackle": 0.07, "blowoff": 0.35, "shift": 0.06, "start": 1.1})


def broken_variants(meta):
    """Copies of the valid fixture, each with exactly one defect (they share fixture_v4.f32)."""
    out = {}
    m = copy.deepcopy(meta)
    m["format"] = "ce-engine-bank-0"
    out["broken_format"] = m
    m = copy.deepcopy(meta)
    m["banks"] = [b for b in m["banks"] if not (b["rpm"] == 2500 and b["load"] == "off")]
    out["broken_missing_load"] = m
    m = copy.deepcopy(meta)
    m["banks"][3]["cycles"][5] = [10 ** 7, m["banks"][3]["cycles"][5][1]]
    out["broken_cycle_range"] = m
    m = copy.deepcopy(meta)
    m["banks"][2]["cycles"][1] = [m["banks"][2]["cycles"][1][0], m["banks"][2]["cycles"][1][1] - 9]
    out["broken_length"] = m
    m = copy.deepcopy(meta)
    m["data"] = "fehlt.f32"
    out["broken_no_data"] = m
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(HERE, "engines"))
    ap.add_argument("--demo", default="", help="also write the full-range demo bank into this directory")
    args = ap.parse_args()
    meta, data = fixture_v4()
    write_bank(args.out, meta, data)
    for name, m in broken_variants(meta).items():
        write_json(args.out, name, m)
    if args.demo:
        meta, data = demo_v8()
        write_bank(args.demo, meta, data)


if __name__ == "__main__":
    main()
