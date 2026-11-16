#!/usr/bin/env python3
"""Spike 2a: "remastered" title theme, excerpt pre-chorus 1 + chorus 1 (bars 33-48, 1:00-1:30 of the file):
same arrangement and notes as tools/audio/music_synth.py, new production (48 kHz, layered drums, sub bass,
four guitar takes, wide lead double, deeper pump, new reverbs, multiband master)."""
import copy, json, math, os, sys, time
import numpy as np
import alib
import music_synth as ms
import music2lib as m2

W = alib.WORK
OUT = W + "/out"
BAR_A, BAR_B = 32, 48


def main():
    m2.setup(48000)
    SR = ms.SR
    t0 = time.time()
    rd = ms.Render(BAR_A, BAR_B)
    n = rd.n
    stems, specs = {}, {}
    for group in ms.TRACK_ORDER:
        t1 = time.time()
        for name, x in getattr(rd, group)().items():
            if np.any(x):
                stems[name] = x
                specs[name] = copy.deepcopy(ms.MIX[name])
        print("  %-12s %5.1f s" % (group, time.time() - t1), flush=True)
    kick_times = [t - rd.t0 for t in rd.kick_times]
    # --- section automation of the original (drums/guitars a little back in the pre-chorus) ----------------
    for name in list(stems):
        a = ms.automation(name, rd)
        if a is not None:
            stems[name] = stems[name] * a[:, None]
    # --- new layers -------------------------------------------------------------------------------------------
    k2 = np.zeros((n, 2)); s2 = np.zeros((n, 2)); shk = np.zeros((n, 2))
    for t, inst, vel, var in rd.drum_events():
        if inst == "kick":
            rd.place(k2, m2.kick2(var), t, vel)
        elif inst == "snare":
            rd.place(s2, m2.snare2(var), t, vel ** 1.3)
    for b in rd.bars:
        if rd.active(b) and b.sec.startswith("chorus"):
            for st in range(16):
                r = ms.rng_of("shaker", b.key, st)
                rd.place(shk, m2.shaker(int(r.integers(0, 4))), b.t + st * ms.STEP + 0.002 * r.uniform(-1, 1),
                         (1.0 if st % 4 == 2 else 0.55) * (1.0 + 0.1 * r.uniform(-1, 1)), 0.25 if st % 2 else -0.25)
    sub = np.zeros((n, 2))
    for b in rd.bars:
        if not rd.active(b):
            continue
        for st, ln, m, vel, layers in ms.bass_bar(b):
            rd.place(sub, m2.sub_bass(int(m), round(ln * ms.STEP, 4)), b.t + st * ms.STEP, vel)
    stems.update({"kick2": k2, "snare2": s2, "shaker": shk, "sub": sub})
    # two more rhythm guitar takes (darker amp), inside the hard-panned pair
    for take, name, pan in ((2, "gtr_L2", -0.55), (3, "gtr_R2", 0.55)):
        di = np.zeros(n)
        for b in rd.bars:
            if not rd.active(b):
                continue
            for st, ln, c, mode, vel, stroke in ms.gtr_bar(b):
                r = ms.rng_of("gtr_ev", take, b.key, st)
                t = b.t + st * ms.STEP + 0.004 * r.uniform(-1.0, 1.0) + 0.003 * take
                x = ms.gtr_hit(ms.power_chord(c), ln, mode, stroke, take, int(r.integers(0, 4)))
                rd.place_mono(di, x, t, vel * (1.0 + 0.04 * r.uniform(-1, 1)))
        p = {**ms.AMP_RHYTHM, "mid_f": 640.0, "g1": 6.0, "post": ms.AMP_RHYTHM["post"] + [("peak", 1200.0, 2.0, 1.0), ("lp", 5000.0, 0.7)]}
        y = ms.amp_sim(di, p)
        a = ms.automation("gtr_L", rd)
        stems[name] = np.stack([y, y], axis=1) * (a[:, None] if a is not None else 1.0)
        specs[name] = {"bus": "inst", "lufs": -27.5, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 7000.0, 0.7)], "duck": 0.2}
    # wide double of the synth lead (two decorrelated supersaws)
    wide = np.zeros((n, 2))
    for sec, j0, lines, tr, patch, vel, track in ms.LEAD_PHRASES:
        if track != "lead_syn":
            continue
        for bar0 in rd.section_bars(sec):
            avail = rd.phrase_range(bar0 + j0, len(lines))
            if avail:
                notes = ms.phrase(lines[:avail], bar0 + j0, tr)
                for ch, pt in ((0, "super_l"), (1, "super_r")):
                    tt, y = ms.synth_lead(notes, pt, f"{sec}:{j0}:wide{ch}", vel)
                    i = int(round((tt - rd.t0) * SR))
                    if i < n and i + len(y) > 0:
                        a, b_ = max(0, -i), min(len(y), n - i)
                        wide[i + a:i + b_, ch] += y[a:b_]
    stems["lead_wide"] = wide
    # --- specs of the modern mix ------------------------------------------------------------------------------
    specs["kick"]["lufs"] = -19.3
    specs["kick2"] = {"bus": "drums", "lufs": -25.0, "eq": [("hp", 36.0, 0.7), ("peak", 52.0, 0.0, 1.0), ("peak", 300.0, -4.0, 1.2),
                                                           ("peak", 4000.0, 3.0, 1.0)]}
    specs["snare"]["lufs"] = -20.5
    specs["snare2"] = {"bus": "drums", "lufs": -19.8, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2), ("peak", 5000.0, 2.0, 0.8)],
                       "sends": {"plate": -14.0}}
    specs["shaker"] = {"bus": "drums", "lufs": -37.0, "eq": [("hp", 4000.0, 0.7)]}
    specs["hats"]["lufs"] = -30.5
    specs["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 16500.0, 0.7)]
    specs["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -2.0), ("lp", 16000.0, 0.7)]
    specs["sub"] = {"bus": "inst", "lufs": -27.0, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
    specs["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2), ("lp", 4500.0, 0.7)]
    specs["bass_pick"]["duck"] = 0.3
    specs["bass_syn"]["duck"] = 0.6
    for g in ("gtr_L", "gtr_R"):
        specs[g]["duck"] = 0.15
        specs[g]["eq"] = [("hp", 90.0, 0.7), ("peak", 3400.0, 1.0, 1.0), ("lp", 9000.0, 0.7)]
    specs["pad"]["duck"] = 0.6
    specs["pad"]["eq"] = [("hp", 160.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5200.0, 0.8)]
    specs["arp"]["duck"] = 0.4
    specs["lead_syn"]["lufs"] = -19.0
    specs["lead_wide"] = {"bus": "inst", "lufs": -24.5, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                          "sends": {"hall": -10.0, "delay": -13.0}}
    mix, levels = m2.mix2(stems, specs, kick_times, n)
    meas = slice(0, int((BAR_B - BAR_A) * ms.BAR * SR))
    y, info = m2.master2(mix, meas, -13.25)
    y = y[:int(((BAR_B - BAR_A) * ms.BAR + 1.6) * SR)].copy()
    f = int(1.5 * SR)
    y[-f:] *= np.linspace(1.0, 0.0, f)[:, None] ** 2
    alib.write_wav(OUT + "/title_remaster_excerpt.wav", y, SR, 32)
    json.dump({"levels": levels, "master": info, "seconds": round(time.time() - t0, 1)}, open(OUT + "/title_remaster_info.json", "w"), indent=1)
    print("fertig in %.0f s" % (time.time() - t0), levels)


if __name__ == "__main__":
    main()
