#!/usr/bin/env python3
"""QA-M2-SYSTEM: analysis of qa_race_sound.gd captures (WAV + JSON log of feed states, one-shots, events, positions).
Per file: loudness (BS.1770 via tools/audio/qc/qc_lib.py), true peak (4x), sample peak, clipped runs, digital-silence
dropouts inside sound, click candidates; per paving interval (from the feed log): band levels; for every joint one-shot
the transient against its surroundings; around every collision the true peak; the slab rhythm on concrete.
Numbers are measured on the files; how it sounds to a person is inferred.
Usage: race_sound_analyze.py <qc_lib dir> <wav> [<wav> …]
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, sys.argv[1])
import qc_lib  # noqa: E402

BANDS = [(40, 160), (160, 630), (630, 2500), (2500, 10000)]


def band_db(x, sr, lo, hi):
    if len(x) < 2048:
        return float("nan")
    mono = x.mean(axis=1)
    n = 1 << int(math.floor(math.log2(len(mono))))
    n = min(n, 1 << 18)
    seg = mono[:n] * np.hanning(n)
    spec = np.abs(np.fft.rfft(seg)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / sr)
    p = spec[(f >= lo) & (f < hi)].sum() / (np.hanning(n) ** 2).sum()
    return 10 * math.log10(p + 1e-20)


def dropouts(x, rate):
    mono = np.abs(x).max(axis=1)
    silent = mono < 1.0 / 32768.0
    runs = []
    i, n = 0, len(silent)
    min_len = int(0.002 * rate)
    while i < n:
        if silent[i]:
            j = i
            while j < n and silent[j]:
                j += 1
            if j - i >= min_len and i > rate // 2 and j < n - rate // 2:
                pre = np.sqrt(np.mean(x[max(0, i - rate // 20):i] ** 2))
                post = np.sqrt(np.mean(x[j:j + rate // 20] ** 2))
                if pre > 1e-3 and post > 1e-3:
                    runs.append((round(i / rate, 3), round((j - i) / rate * 1000.0, 1)))
            i = j
        else:
            i += 1
    return runs


def clicks(x, rate):
    d = np.abs(np.diff(x, axis=0)).max(axis=1)
    blk = int(0.01 * rate)
    nb = len(d) // blk
    if nb < 60:
        return []
    m = d[: nb * blk].reshape(nb, blk).max(axis=1)
    out = []
    half = 25
    for b in range(max(half, int(2.0 * rate / blk)), nb - half):
        neigh = np.concatenate([m[b - half:b - 1], m[b + 2:b + half]])
        ref = np.median(neigh)
        if m[b] > 0.05 and m[b] > 4.0 * max(ref, 1e-4):
            out.append((round(b * blk / rate, 3), round(float(m[b]), 3), round(float(ref), 4)))
    return out


def envelope(x, sr, hp=300.0, win_ms=5.0):
    """High-passed (1st order) rectified envelope in 5-ms blocks."""
    mono = x.mean(axis=1)
    a = math.exp(-2 * math.pi * hp / sr)
    y = np.empty_like(mono)
    prev_x = 0.0
    prev_y = 0.0
    # vectorised first-order high-pass via lfilter-equivalent recursion is slow in pure python: use difference
    y = np.diff(mono, prepend=mono[:1])
    blk = int(sr * win_ms / 1000.0)
    nb = len(y) // blk
    e = np.sqrt((y[: nb * blk].reshape(nb, blk) ** 2).mean(axis=1))
    return e, blk / sr


def main():
    report = {}
    for wav in sys.argv[2:]:
        x, sr = qc_lib.read_wav(wav)
        info = json.load(open(wav[:-4] + ".json"))
        log = info.get("log", [])
        dur = len(x) / sr
        r = {"seconds": round(dur, 2), "profile": info.get("profile"), "master_volume": info.get("master_volume"),
             "finished": info.get("finished")}
        r["true_peak_dbtp"] = round(qc_lib.true_peak_db(x), 2)
        r["sample_peak_dbfs"] = round(qc_lib.sample_peak_db(x), 2)
        r["clipped_runs"] = qc_lib.clipped_runs(x)
        r["integrated_lufs"] = round(qc_lib.integrated_lufs(x, sr), 2) if dur > 3 else None
        st = qc_lib.short_term(x, sr) if dur > 4 else np.array([])
        r["short_term_max_lufs"] = round(float(np.max(st)), 2) if len(st) else None
        r["dropouts"] = dropouts(x, sr)
        ck = clicks(x, sr)
        r["click_candidates"] = ck[:15]
        r["n_click_candidates"] = len(ck)
        # positions
        pos = [e for e in log if e["kind"] == "pos"]
        if pos:
            r["km_from_to"] = [pos[0]["km"], pos[-1]["km"]]
            sp = [p["speed"] for p in pos if p["speed"] >= 0]
            r["speed_min_max"] = [min(sp), max(sp)] if sp else None
            if len(pos) > 4:
                dk = pos[-1]["km"] - pos[0]["km"]
                dt = pos[-1]["t"] - pos[0]["t"]
                r["km_per_s"] = round(dk / max(dt, 1e-3), 4)
        # paving intervals
        feeds = [e for e in log if e["kind"] == "feed"]
        ivs = []
        for i, fe in enumerate(feeds):
            t0 = fe["t"]
            t1 = feeds[i + 1]["t"] if i + 1 < len(feeds) else dur
            ivs.append({"paving": fe["state"]["paving"], "deck": fe["state"]["deck"], "zone": fe["state"]["zone"],
                        "surf": fe["state"]["surface_l"] + "/" + fe["state"]["surface_r"], "km": fe["km"],
                        "t0": round(t0, 2), "t1": round(t1, 2)})
        for iv in ivs:
            a = int((iv["t0"] + 0.4) * sr)
            b = int((iv["t1"] - 0.1) * sr)
            if b - a > int(0.5 * sr):
                seg = x[a:b]
                iv["bands_db"] = [round(band_db(seg, sr, lo, hi), 1) for lo, hi in BANDS]
                iv["rms_db"] = round(20 * math.log10(np.sqrt(np.mean(seg ** 2)) + 1e-12), 1)
                spd = [p["speed"] for p in pos if iv["t0"] <= p["t"] <= iv["t1"]]
                iv["speed"] = round(float(np.mean(spd)), 1) if spd else None
        r["intervals"] = ivs
        # one-shots and events
        plays = [e for e in log if e["kind"] == "play"]
        events = [e for e in log if e["kind"] == "event"]
        r["plays"] = {}
        for p in plays:
            r["plays"][p["name"]] = p["n"]
        r["events"] = {}
        for e in events:
            r["events"][e["name"]] = e["n"]
        env, hop = envelope(x, sr)
        jt = []
        for p in plays:
            if "joint" in p["name"] or "fuge" in p["name"]:
                i = int(p["t"] / hop)
                lo, hi = max(0, i - 40), min(len(env), i + 40)       # ±200 ms around the log time
                ref_lo, ref_hi = max(0, i - 200), min(len(env), i + 200)
                if hi > lo and ref_hi > ref_lo:
                    pk = float(env[lo:hi].max())
                    ref = float(np.median(env[ref_lo:ref_hi]))
                    jt.append({"t": p["t"], "km": p["km"], "name": p["name"],
                               "peak_over_median_db": round(20 * math.log10(pk / max(ref, 1e-9)), 1)})
        r["joint_transients"] = jt
        col = []
        for e in events:
            if e["name"] in ("collision", "rail_hit"):
                a = max(0, int((e["t"] - 1.0) * sr))
                b = min(len(x), int((e["t"] + 3.0) * sr))
                col.append({"t": e["t"], "name": e["name"], "km": e["km"],
                            "true_peak_dbtp": round(qc_lib.true_peak_db(x[a:b]), 2),
                            "sample_peak_dbfs": round(qc_lib.sample_peak_db(x[a:b]), 2)})
        r["impacts"] = col
        # slab rhythm on concrete: spectrum of the envelope, strongest line 0.5..40 Hz
        rh = []
        for iv in ivs:
            if iv["paving"] == "concrete" and iv["t1"] - iv["t0"] > 4.0:
                i0, i1 = int((iv["t0"] + 0.5) / hop), int((iv["t1"] - 0.2) / hop)
                e = env[i0:i1] - env[i0:i1].mean()
                if len(e) > 256:
                    sp = np.abs(np.fft.rfft(e * np.hanning(len(e))))
                    fr = np.fft.rfftfreq(len(e), hop)
                    m = (fr > 0.5) & (fr < 40)
                    k = np.argmax(sp[m])
                    peak = float(sp[m][k])
                    med = float(np.median(sp[m]))
                    rh.append({"t0": iv["t0"], "t1": iv["t1"], "speed": iv.get("speed"), "line_hz": round(float(fr[m][k]), 2),
                               "line_over_median_db": round(20 * math.log10(peak / max(med, 1e-12)), 1)})
        r["slab_rhythm"] = rh
        report[os.path.basename(wav)] = r
        print("==", os.path.basename(wav), "| %.1f s | TP %.2f dBTP | SP %.2f dBFS | clipped %d | I %s LUFS | S-max %s | drop %d | clicks %d" % (
            dur, r["true_peak_dbtp"], r["sample_peak_dbfs"], r["clipped_runs"], r["integrated_lufs"], r["short_term_max_lufs"],
            len(r["dropouts"]), len(ck)))
        if pos:
            print("   km %s  speed %s  km/s %s" % (r.get("km_from_to"), r.get("speed_min_max"), r.get("km_per_s")))
        for iv in ivs:
            print("   %6.2f-%6.2f s km %7.3f  %-8s %-6s %-7s %-20s speed %s  rms %s  bands %s" % (
                iv["t0"], iv["t1"], iv["km"], iv["paving"], iv["deck"], iv["zone"], iv["surf"], iv.get("speed"),
                iv.get("rms_db"), iv.get("bands_db")))
        print("   plays", r["plays"])
        print("   events", r["events"])
        for j in jt:
            print("   joint", j)
        for c in col:
            print("   impact", c)
        for s in rh:
            print("   slabs", s)
        if r["dropouts"]:
            print("   dropouts", r["dropouts"][:10])
        if ck:
            print("   click candidates", ck[:8])
    out = os.path.join(os.path.dirname(sys.argv[2]), "race_sound_report.json")
    old = json.load(open(out)) if os.path.exists(out) else {}
    old.update(report)
    json.dump(old, open(out, "w"), indent=1)


main()
