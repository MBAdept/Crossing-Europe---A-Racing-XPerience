#!/usr/bin/env python3
"""Spike 2b: sketch of an in-race track in the brand's style - "Linke Spur" (working title), D minor, 132 bpm,
20 bars = 36 s: 2 bars count-in (lands on the "Go"), 8 bars A (groove, motif), 8 bars B (hook with harmony),
ending. Instruments of tools/audio/music_synth.py + the modern layers of music2lib.py. Scratch prototype."""
import copy, json, math, os, sys, time
import numpy as np
import alib
import music_synth as ms
import music2lib as m2

W = alib.WORK
OUT = W + "/out"
BPM = 132.0
BARS = 20
CH = {
    "Dm": {"root": 38, "pow": (50, 57, 62), "pad": (50, 57, 62, 65), "arp": (62, 65, 69, 74)},
    "Bb": {"root": 34, "pow": (46, 53, 58), "pad": (46, 53, 58, 62), "arp": (58, 62, 65, 70)},
    "C": {"root": 36, "pow": (48, 55, 60), "pad": (48, 55, 60, 64), "arp": (60, 64, 67, 72)},
    "F": {"root": 41, "pow": (41, 48, 53), "pad": (53, 57, 60, 65), "arp": (65, 69, 72, 77)},
    "A": {"root": 33, "pow": (45, 52, 57), "pad": (45, 52, 57, 61), "arp": (57, 61, 64, 69)},
}
CHORDS = ["Dm", "Dm"] + ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "C"] + ["Bb", "C", "Dm", "Dm", "Bb", "C", "F", "A"] + ["Dm", "Dm"]
SEC = ["in"] * 2 + ["A"] * 8 + ["B"] * 8 + ["end"] * 2
L_A = ["0:3:D5 3:3:F5 6:2:A5 8:3:G5 11:3:F5 14:2:E5",
       "0:6:F5 6:2:D5 8:8:A4",
       "0:3:D5 3:3:F5 6:2:Bb5 8:3:A5 11:3:G5 14:2:F5",
       "0:8:E5 8:2:G5 10:2:C6 12:4:G5"]
L_B = ["0:6:D5 6:2:F5 8:8:Bb5",
       "0:6:E5 6:2:G5 8:6:C6 14:2:Bb5",
       "0:8:A5 8:3:F5 11:3:G5 14:2:A5",
       "0:12:D6:v 12:2:C6 14:2:A5",
       "0:6:Bb5 6:2:A5 8:4:F5 12:4:D5",
       "0:6:C6 6:2:Bb5 8:4:G5 12:4:E5",
       "0:3:F5 3:3:A5 6:2:C6 8:8:F6:v",
       "0:8:E6 8:4:C#6 12:4:A5",
       "0:16:D6:v"]
H_B = ["0:6:G5 6:2:F5 8:4:D5 12:4:Bb4",
       "0:6:A5 6:2:G5 8:4:E5 12:4:C5",
       "0:3:D5 3:3:F5 6:2:A5 8:8:D6",
       "0:8:C#6 8:4:A5 12:4:E5",
       "0:16:A5"]


def main():
    m2.setup(48000, BPM)
    SR = ms.SR
    BAR, STEP = ms.BAR, ms.STEP
    t0 = time.time()
    n = int((BARS * BAR + 3.2) * SR)

    def place(buf, x, t, gain=1.0, pan=0.0):
        i = int(round(t * SR))
        if i >= n or i + len(x) <= 0:
            return
        a, b = max(0, -i), min(len(x), n - i)
        if buf.ndim == 1:
            buf[i + a:i + b] += x[a:b] * gain
        elif x.ndim == 1:
            gl, gr = ms.pan_gains(pan)
            buf[i + a:i + b, 0] += x[a:b] * (gain * gl)
            buf[i + a:i + b, 1] += x[a:b] * (gain * gr)
        else:
            buf[i + a:i + b, 0] += x[a:b, 0] * (gain * min(1.0, 1.0 - pan))
            buf[i + a:i + b, 1] += x[a:b, 1] * (gain * min(1.0, 1.0 + pan))

    st = {k: np.zeros((n, 2)) for k in ("kick", "kick2", "snare", "snare2", "clap", "toms", "hats", "shaker", "crash", "bass_pick",
                                         "bass_syn", "sub", "pad", "arp", "lead_syn", "lead_wide", "harm_syn", "fx")}
    kick_times = []
    # ---- drums ------------------------------------------------------------------------------------------------
    for bi in range(BARS):
        sec = SEC[bi]
        tb = bi * BAR
        ev = []
        if sec == "in":
            ev += [(s, "hat_c", 0.45 + 0.02 * s) for s in range(0, 16, 2)]
            if bi == 1:
                ev += [(s, "kick", 0.9) for s in (0, 4)]
                ev += [(s, "snare", 0.35 + 0.08 * (s - 8)) for s in range(8, 16)]
                ev += [(12, "tom_h", 0.8), (13, "tom_h", 0.85), (14, "tom_m", 0.9), (15, "tom_f", 1.0)]
        elif sec in ("A", "B"):
            ev += [(s, "kick", 1.0 if s in (0, 8) else 0.93) for s in (0, 4, 8, 12)]
            ev += [(4, "snare", 1.0), (12, "snare", 1.0)]
            if sec == "B":
                ev += [(4, "clap", 0.75), (12, "clap", 0.75)]
                ev += [(s, "hat_o", 0.55) for s in (2, 6, 10, 14)]
                ev += [(s, "hat_c", 0.5) for s in (0, 4, 8, 12)]
            else:
                ev += [(s, "hat_c", 0.7 if s % 4 == 2 else 0.48) for s in range(0, 16, 2)]
            ev += [(s, "shaker", (0.9 if s % 4 == 2 else 0.5)) for s in range(16)]
            if bi in (5, 13):
                ev += [(14, "kick", 0.8)]
            if bi == 9:        # fill into B
                ev = [e for e in ev if not (e[1] in ("hat_c", "shaker") and e[0] >= 12)]
                ev += [(12, "tom_h", 0.85), (13, "tom_h", 0.9), (14, "tom_m", 0.95), (15, "tom_f", 1.0), (10, "snare", 0.6)]
            if bi == 17:       # roll into the ending
                ev = [e for e in ev if not (e[1] in ("hat_c", "hat_o", "shaker", "clap") and e[0] >= 8)]
                ev += [(s, "snare", 0.4 + 0.07 * (s - 8)) for s in (8, 9, 10, 11, 13)] + [(14, "tom_m", 0.95), (15, "tom_f", 1.0)]
            if bi in (2, 10):
                ev += [(0, "crash", 0.9)]
        else:
            if bi == 18:
                ev += [(0, "kick", 1.0), (0, "crash", 1.0), (0, "snare", 0.9)]
        for s, inst, vel in ev:
            r = ms.rng_of("race_drum", bi, s, inst)
            t = tb + s * STEP + 0.002 * r.uniform(-1.0, 1.0) * (0.3 if inst == "kick" else 1.0)
            var = int(r.integers(0, 4))
            v = vel * (1.0 + 0.05 * r.uniform(-1, 1))
            if inst == "kick":
                place(st["kick"], ms.kick(var), t, v)
                place(st["kick2"], m2.kick2(var), t, v)
                kick_times.append(t)
            elif inst == "snare":
                place(st["snare"], ms.snare(var), t, v ** 1.3)
                place(st["snare2"], m2.snare2(var), t, v ** 1.3)
            elif inst == "clap":
                place(st["clap"], ms.clap(var), t, v)
            elif inst.startswith("tom"):
                place(st["toms"], ms.tom(inst, var), t, v ** 1.2, {"tom_h": -0.35, "tom_m": 0.0, "tom_f": 0.35}[inst])
            elif inst == "hat_c":
                place(st["hats"], ms.hat(False, var), t, v, 0.3)
            elif inst == "hat_o":
                place(st["hats"], ms.hat(True, var), t, v, 0.3)
            elif inst == "shaker":
                place(st["shaker"], m2.shaker(var), t, v, 0.25 if s % 2 else -0.25)
            elif inst == "crash":
                place(st["crash"], ms.crash(var % 2), t, v, -0.35 if bi == 10 else 0.35)
    # ---- bass: rolling eighths with octave pops, picked bass + synth bass + sub ------------------------------------
    for bi in range(2, 18):
        c = CH[CHORDS[bi]]
        for s in range(0, 16, 2):
            m = c["root"] + (12 if s in (6, 14) else 0)
            if bi in (9, 17) and s == 14:
                m = CH[CHORDS[bi + 1]]["root"] - 1 if CHORDS[bi + 1] != CHORDS[bi] else m      # leading tone into the next root
            r = ms.rng_of("race_bass", bi, s)
            t = bi * BAR + s * STEP + 0.0015 * r.uniform(-1, 1)
            vel = 1.0 if s % 4 == 0 else 0.86
            place(st["bass_pick"], ms.bass_pick(m, 2.0, int(r.integers(0, 3))), t, vel)
            place(st["bass_syn"], ms.bass_syn(m, 1.7, int(r.integers(0, 3)), 300.0 if SEC[bi] == "B" else 240.0), t, vel)
            place(st["sub"], m2.sub_bass(c["root"], round(1.8 * STEP, 4)), t, vel)
    c = CH["Dm"]
    place(st["bass_pick"], ms.bass_pick(c["root"], 24.0, 0), 18 * BAR, 1.0)
    place(st["bass_syn"], ms.bass_syn(c["root"], 24.0, 0, 200.0, 500.0, 0.004), 18 * BAR, 1.0)
    place(st["sub"], m2.sub_bass(c["root"], round(20 * STEP, 4)), 18 * BAR, 1.0)
    # ---- guitars: palm-muted eighths with open accents (A), open chords in 3-3-2 (B); four takes ---------------------
    gtr = {}
    for take, name in ((0, "gtr_L"), (1, "gtr_R"), (2, "gtr_L2"), (3, "gtr_R2")):
        di = np.zeros(n)
        for bi in range(2, 19):
            sec = SEC[bi]
            c = CH[CHORDS[bi]]
            if sec == "A":
                if take >= 2:
                    continue
                evs = [(s, 2.0, "half" if s in (0, 6, 12) else "mute", 1.0 if s in (0, 6, 12) else 0.8) for s in range(0, 16, 2)]
            elif sec == "B":
                evs = [(0, 6.0, "open", 1.0), (6, 6.0, "open", 0.95), (12, 2.0, "open", 0.9), (14, 2.0, "half", 0.85)]
            else:
                evs = [(0, 28.0, "open", 1.0)]
            for s, ln, mode, vel in evs:
                r = ms.rng_of("race_gtr", take, bi, s)
                t = bi * BAR + s * STEP + 0.004 * r.uniform(-1.0, 1.0) + 0.003 * take
                notes = c["pow"] if mode != "mute" else c["pow"][:2]
                x = ms.gtr_hit(notes, ln, mode, 1 if s % 4 == 0 else -1, take, int(r.integers(0, 4)))
                place(di, x, t, vel * (1.0 + 0.04 * r.uniform(-1, 1)))
        p = dict(ms.AMP_RHYTHM)
        if take == 1:
            p = {**p, "mid_f": 820.0, "g1": 7.5, "post": p["post"] + [("peak", 2600.0, 1.0, 1.5)]}
        elif take >= 2:
            p = {**p, "mid_f": 640.0, "g1": 6.0, "post": p["post"] + [("peak", 1200.0, 2.0, 1.0), ("lp", 5000.0, 0.7)]}
        y = ms.amp_sim(di, p)
        gtr[name] = np.stack([y, y], axis=1)
    # ---- pad, arp ------------------------------------------------------------------------------------------------
    for bi in range(0, 18):
        c = CH[CHORDS[bi]]
        place(st["pad"], ms.pad_chord(c["pad"], round(BAR * 0.98, 4), 0), bi * BAR, 0.6 if SEC[bi] == "in" else (0.85 if SEC[bi] == "A" else 1.0))
        order = (0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3)
        for s in range(16):
            if SEC[bi] == "in":
                bright = min(7, int(1 + (bi * 16 + s) / 32.0 * 5))
            else:
                bright = 4 if SEC[bi] == "A" else 6
            m = c["arp"][order[s]] + (12 if (SEC[bi] == "B" and s % 8 >= 4) else 0)
            place(st["arp"], ms.arp_note(int(m), bright, s % 2), bi * BAR + s * STEP, 0.8 if s % 4 else 1.0, 0.28 if s % 2 else -0.28)
    place(st["pad"], ms.pad_chord(CH["Dm"]["pad"], round(BAR * 1.6, 4), 0), 18 * BAR, 1.0)
    # ---- leads ---------------------------------------------------------------------------------------------------
    def lead(lines, bar0, patch, key, vel, buf, ch=None):
        notes = ms.phrase(lines, bar0)
        tt, y = ms.synth_lead(notes, patch, key, vel)
        if ch is None:
            place(buf, y, tt, 1.0, 0.0)
        else:
            i = int(round(tt * SR))
            a, b = max(0, -i), min(len(y), n - i)
            buf[i + a:i + b, ch] += y[a:b]

    lead(L_A, 6, "lead", "race:A", 0.9, st["lead_syn"])
    lead(L_B, 10, "lead", "race:B", 1.0, st["lead_syn"])
    for ch, pt in ((0, "super_l"), (1, "super_r")):
        lead(L_B, 10, pt, "race:Bw%d" % ch, 1.0, st["lead_wide"], ch)
    lead(H_B, 14, "soft", "race:H", 0.9, st["harm_syn"])
    # lead guitar doubles the hook an octave lower (rock flavour)
    notes = ms.phrase(L_B, 10, -12)
    tt, di = ms.lead_guitar_di(notes, "race:gtr")
    dbuf = np.zeros(n)
    place(dbuf, di, tt, 1.0)
    lg = ms.amp_sim(dbuf, ms.AMP_LEAD)
    # ---- fx ----------------------------------------------------------------------------------------------------------
    ris = ms.riser(2)
    place(st["fx"], ris, 2 * BAR - len(ris) / SR, 0.7)
    for b0 in (2, 10, 18):
        rev = ms.reverse_crash(2.0)
        place(st["fx"], rev, b0 * BAR - len(rev) / SR, 0.7)
    place(st["fx"], ms.impact(), 2 * BAR, 0.9)
    place(st["fx"], ms.impact(), 18 * BAR, 1.0)
    print("  Spuren gerendert in %.0f s" % (time.time() - t0), flush=True)

    stems = dict(st)
    stems.update(gtr)
    stems["lead_gtr"] = np.stack([lg, lg], axis=1)
    specs = {k: copy.deepcopy(ms.MIX[k]) for k in ("kick", "snare", "clap", "toms", "hats", "crash", "bass_pick", "bass_syn", "gtr_L", "gtr_R",
                                                    "lead_gtr", "lead_syn", "harm_syn", "pad", "arp", "fx")}
    specs["kick"]["lufs"] = -19.3
    specs["kick2"] = {"bus": "drums", "lufs": -25.0, "eq": [("hp", 36.0, 0.7), ("peak", 300.0, -4.0, 1.2), ("peak", 4000.0, 3.0, 1.0)]}
    specs["snare"]["lufs"] = -20.5
    specs["snare2"] = {"bus": "drums", "lufs": -19.8, "eq": [("hp", 110.0, 0.7), ("peak", 200.0, 2.0, 1.2), ("peak", 5000.0, 2.0, 0.8)],
                       "sends": {"plate": -14.0}}
    specs["shaker"] = {"bus": "drums", "lufs": -36.0, "eq": [("hp", 4000.0, 0.7)]}
    specs["hats"]["lufs"] = -30.5
    specs["hats"]["eq"] = [("hp", 450.0, 0.7), ("lp", 16500.0, 0.7)]
    specs["crash"]["eq"] = [("hp", 400.0, 0.7), ("hs", 8000.0, -2.0), ("lp", 16000.0, 0.7)]
    specs["sub"] = {"bus": "inst", "lufs": -27.0, "eq": [("lp", 105.0, 0.7), ("hp", 28.0, 0.7)], "duck": 0.8}
    specs["bass_pick"]["eq"] = [("hp", 45.0, 0.8), ("peak", 250.0, -1.5, 1.0), ("peak", 950.0, 3.0, 1.2), ("lp", 4500.0, 0.7)]
    specs["bass_pick"]["duck"] = 0.3
    specs["bass_pick"]["lufs"] = -20.5
    specs["bass_syn"]["duck"] = 0.65
    specs["bass_syn"]["lufs"] = -20.5
    for g in ("gtr_L", "gtr_R"):
        specs[g]["duck"] = 0.15
        specs[g]["eq"] = [("hp", 90.0, 0.7), ("peak", 3400.0, 1.0, 1.0), ("lp", 9000.0, 0.7)]
    for g, pan in (("gtr_L2", -0.55), ("gtr_R2", 0.55)):
        specs[g] = {"bus": "inst", "lufs": -27.5, "pan": pan, "eq": [("hp", 95.0, 0.7), ("lp", 7000.0, 0.7)], "duck": 0.2}
    specs["pad"]["duck"] = 0.6
    specs["pad"]["eq"] = [("hp", 160.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 5200.0, 0.8)]
    specs["arp"]["duck"] = 0.4
    specs["arp"]["lufs"] = -25.5
    specs["lead_syn"]["lufs"] = -19.5
    specs["lead_wide"] = {"bus": "inst", "lufs": -24.5, "eq": [("hp", 220.0, 0.7), ("hs", 6000.0, 2.0)], "duck": 0.15,
                          "sends": {"hall": -10.0, "delay": -13.0}}
    specs["lead_gtr"]["lufs"] = -24.0
    mix, levels = m2.mix2(stems, specs, kick_times, n)
    meas = slice(int(2 * BAR * SR), int(18 * BAR * SR))
    y, info = m2.master2(mix, meas, -14.0)
    end = int((BARS * BAR + 1.2) * SR)
    y = y[:end].copy()
    f = int(2.0 * SR)
    y[-f:] *= np.linspace(1.0, 0.0, f)[:, None] ** 2
    alib.write_wav(OUT + "/race_track_sketch.wav", y, SR, 32)
    json.dump({"bpm": BPM, "bar_s": BAR, "bars": BARS, "levels": levels, "master": info, "seconds": round(time.time() - t0, 1),
               "downbeat_s": 2 * BAR}, open(OUT + "/race_track_info.json", "w"), indent=1)
    print("fertig in %.0f s" % (time.time() - t0), levels)


if __name__ == "__main__":
    main()
