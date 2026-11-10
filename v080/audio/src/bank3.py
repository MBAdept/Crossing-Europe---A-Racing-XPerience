#!/usr/bin/env python3
"""v0.8.0 audio study, spike 1: "modern" engine bank (48 kHz, stereo, retuned components) built with the
physical model of tools/audio/engine_synth.py (imported, not modified). Scratch prototype - not part of the repo.

Stereo: one listener position (mono compatible), per-tailpipe constant-power panning from the pipe's lateral
position (the two banks of a V8/boxer leave through different pipes -> different pulse trains left/right) and
independent flow-noise realisations per channel (rasp, jet, whoosh, hiss); intake pulses and mechanics stay centred.
"""
from __future__ import annotations
import json, math, os, sys, time
import numpy as np
import alib
import engine_synth as es

SR = 48000
es.SR = SR
es.SR_INT = SR * es.OS
es.IR_N = 32768
OVERLAP = 192
N_VAR = 8
PAN_WIDTH = 0.62          # pan of a source at |x| >= PAN_REF_X
PAN_REF_X = 0.9
# "modern" retune of the component levels (dB on top of the calibrated profile levels) and steepening
MODERN_DB = {"rasp": 4.0, "jet": 6.0, "intake": 5.0, "whoosh": 5.0, "mech": 2.0, "inj": 0.0, "comb": 0.0, "hiss": 3.0,
             "knock": 0.0}
NL_SCALE = 1.5

_CH = {"pan": 0}
_orig_listener_path = es.listener_path


def _listener_path_stereo(f, pos, shadow=None):
    g, r1 = _orig_listener_path(f, pos, shadow)
    ch = _CH["pan"]
    if ch != 0:
        pan = float(np.clip(pos[0] / PAN_REF_X, -1.0, 1.0)) * PAN_WIDTH
        a = (pan + 1.0) * math.pi / 4.0
        g = g * (math.sqrt(2.0) * (math.cos(a) if ch < 0 else math.sin(a)))
    return g, r1


es.listener_path = _listener_path_stereo


class Chan:
    def __init__(self, ch: int):
        self.ch = ch

    def __enter__(self):
        self.prev = _CH["pan"]
        _CH["pan"] = self.ch

    def __exit__(self, *a):
        _CH["pan"] = self.prev


def make_models(car: str, modern: bool = True):
    with Chan(0):
        mc = es.CarModel(car)
        if modern:
            mc.op = dict(mc.op, nl=mc.op["nl"] * NL_SCALE)
        mc.calibrate()
    models = {}
    for ch in (-1, 1):
        with Chan(ch):
            m = es.CarModel(car)
            if modern:
                m.op = dict(m.op, nl=m.op["nl"] * NL_SCALE)
            k = dict(mc.cal["k"])
            if modern:
                for c, d in MODERN_DB.items():
                    if c in k:
                        k[c] *= 10.0 ** (d / 20.0)
            m.cal = dict(mc.cal, k=k)
            models[ch] = m
    return mc, models


def render_steady_stereo(mc, models, period: int, load: str, n_var: int = N_VAR, overlap: int = OVERLAP):
    car = mc.car
    rpm = 120.0 * SR / period
    opp = mc.operating_point(rpm, load)
    with Chan(0):
        D = mc.exhaust_tf(opp["T_hdr"])["D"]
    n_warm = int(math.ceil(0.30 * SR / period)) + 1
    n_total = n_warm + n_var + 1
    n_len = n_total * period + overlap + 16
    out = []
    for ch in (-1, 1):
        m = models[ch]
        with Chan(ch):
            rng_ev = np.random.default_rng(es.seed_of(car, period, load))
            ev = m.steady_events(opp, n_total, D, rng_ev)
            rng_n = np.random.default_rng(es.seed_of(car, period, load, "noise", ch))
            parts = m.render_components(ev, opp, n_len, rng_n)
            out.append(m.mix(parts))
    return {"rpm": rpm, "period": period, "load": load, "y": np.stack(out, axis=1), "n_warm": n_warm, "D": D}


def stereo_clip(fn, models, *args):
    """Runs a clip generator of engine_synth per channel with a trim that is the same for both channels."""
    raw = []
    orig = es._trim_clip
    es._trim_clip = lambda y, floor_db=-50.0, max_s=0.0: y
    try:
        for ch in (-1, 1):
            with Chan(ch):
                raw.append(fn(models[ch], *args))
    finally:
        es._trim_clip = orig
    clips = []
    for l, r in zip(raw[0], raw[1]) if isinstance(raw[0], list) else [(raw[0], raw[1])]:
        st = np.stack([l, r], axis=1)
        env = np.max(np.abs(st), axis=1)
        first = max(int(np.argmax(env > env.max() * 0.01)) - int(0.002 * SR), 0)
        last = len(env) - int(np.argmax(env[::-1] > env.max() * 10.0 ** (-50.0 / 20.0)))
        st = st[first:last].copy()
        fade = max(16, min(len(st) // 4, int(0.02 * SR)))
        st[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
        st[:16] *= np.linspace(0.0, 1.0, 16)[:, None]
        clips.append(st)
    return clips


def lev_a(y: np.ndarray) -> float:
    return 10.0 * math.log10(0.5 * (10 ** (es.level_a_db(y[:, 0]) / 10.0) + 10 ** (es.level_a_db(y[:, 1]) / 10.0)))


def build(car: str, out_dir: str, modern: bool = True, log=print) -> dict:
    t0 = time.time()
    prof = es.PROFILES[car]
    mc, models = make_models(car, modern)
    periods = es.rpm_points(prof["engine"], prof["ratios"])
    banks = []
    for P in periods:
        for load in ("off", "on"):
            res = render_steady_stereo(mc, models, P, load)
            y = res["y"]
            a = res["n_warm"] * P
            cycles = []
            for i in range(N_VAR):
                c = y[a + i * P:a + i * P + P + OVERLAP].copy()
                c -= np.mean(c[:P], axis=0)
                cycles.append(c)
            banks.append({"rpm": res["rpm"], "period": P, "load": load, "cycles": cycles,
                          "lev": lev_a(y[a:a + N_VAR * P]), "delay_ms": res["D"] * 1000.0})
    mix = dict(prof["mix"])
    es.shape_levels(banks, mc.ref_rpm, mix)
    on_ref = min((b for b in banks if b["load"] == "on"), key=lambda b: abs(math.log(b["rpm"] / mc.ref_rpm)))
    scale = 0.708 / max(np.max(np.abs(c)) for c in on_ref["cycles"]) / on_ref["gain"]
    peak_all = max(np.max(np.abs(c)) * b["gain"] * scale for b in banks for c in b["cycles"])
    if peak_all > 0.97:
        log(f"  Spitze {peak_all:.2f} > 0.97 -> {20 * math.log10(0.97 / peak_all):.1f} dB")
        scale *= 0.97 / peak_all
    clips = {}
    cs = prof["clips"]
    if cs.get("crackle"):
        cl = stereo_clip(lambda m, s: es.crackle_clips(m, s, 12), models, cs["crackle"])
        pk = max(np.max(np.abs(c)) for c in cl)
        clips["crackle"] = [c * 0.75 / pk for c in cl]
    if cs.get("shift"):
        cl = stereo_clip(es.shift_clips, models, cs["shift"])
        pk = max(np.max(np.abs(c)) for c in cl)
        clips["shift"] = [c * 0.7 / pk for c in cl]
    if cs.get("start"):
        idle = np.concatenate([c[:banks[0]["period"]] for c in banks[0]["cycles"]]) * banks[0]["gain"] * scale
        st = stereo_clip(es.start_clip, models)[0]
        # the generic trim cut the lead-in; fine for the demo
        st *= np.sqrt(np.mean(idle ** 2)) / np.sqrt(np.mean(st[-int(0.3 * SR):] ** 2))
        if np.max(np.abs(st)) > 0.97:
            st *= 0.97 / np.max(np.abs(st))
        clips["start"] = [st]
    data, pos, jbanks = [], 0, []
    for b in banks:
        g = b["gain"] * scale
        cyc = []
        for c in b["cycles"]:
            x = (c * g).astype(np.float32)
            data.append(x)
            cyc.append([pos, len(x)])
            pos += len(x)
        jbanks.append({"rpm": round(b["rpm"], 3), "load": b["load"], "period": float(b["period"]),
                       "overlap": OVERLAP, "cycles": cyc, "level_db": round(b["lev"] + 20.0 * math.log10(g), 1)})
    jclips = {}
    for name, lst in clips.items():
        jclips[name] = []
        for c in lst:
            x = np.asarray(c, np.float32)
            data.append(x)
            jclips[name].append([pos, len(x)])
            pos += len(x)
    blob = np.concatenate(data, axis=0).astype("<f4")
    meta = {"format": "ce-engine-bank-2-spike", "car": car, "sample_rate": SR, "channels": 2, "data": f"{car}.f32",
            "engine": prof["engine"], "gearbox": prof["gearbox"], "banks": jbanks, "clips": jclips,
            "layers": prof["layers"], "mix": {"gain": 1.0, "off_gain": 1.0},
            "synth": {"modern": modern, "modern_db": MODERN_DB if modern else {}, "nl_scale": NL_SCALE if modern else 1.0,
                      "pan_width": PAN_WIDTH}}
    os.makedirs(out_dir, exist_ok=True)
    blob.tofile(os.path.join(out_dir, f"{car}.f32"))
    (np.clip(blob, -1, 1) * 32767.0).round().astype("<i2").tofile(os.path.join(out_dir, f"{car}.s16"))
    with open(os.path.join(out_dir, f"{car}.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh)
    log(f"{car}: {len(periods)} Drehzahlpunkte, {len(jbanks)} Banken x {N_VAR} Varianten, Clips "
        f"{', '.join(f'{k}:{len(v)}' for k, v in jclips.items())}; f32 {blob.nbytes / 1e6:.2f} MB, "
        f"s16 {blob.nbytes / 2e6:.2f} MB; {time.time() - t0:.0f} s")
    return meta


if __name__ == "__main__":
    car = sys.argv[1] if len(sys.argv) > 1 else "gran_turismo"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(alib.WORK, "bank3")
    build(car, out)
