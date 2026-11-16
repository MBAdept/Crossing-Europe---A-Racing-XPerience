#!/usr/bin/env python3
"""KRITIK-R2-MESS: is the "nachher" half of the user's preview the sound of the current head? The scripted drive
(drive_ab.gd of AU-R2) re-recorded here on the object head (and on AU-C1 / AU-R as controls) against the halves of
fahrt_kiel_hamburg_vorher_nachher.mp3: per stretch (concrete 175 km/h, steel deck 120 km/h, Hamburg cobbles 50 km/h)
loudness (ungated) and third-octave spectrum; differences between recordings. Script times -> audio times with the
factor recording length / script length of each recording (as build_r2.py did).
usage: ana_drivecmp.py <mp3> <out.json> name=<wav>[:<json>] ...   (names vorher/nachher are taken from the mp3)"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

SR = 44100
AU = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2/final"


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def stretches(meta):
    """script-time windows of the three stretches from the phases and surface changes of a drive json."""
    sf = meta["surfaces"]
    ph = {p["name"]: float(p["t"]) for p in meta["phases"]}
    conc = next(float(s["t"]) for s in sf if s["surfaces"] == "concrete/concrete")
    deck_on = next(float(s["t"]) for s in sf if s["surfaces"] == "deck/deck")
    deck_off = next(float(s["t"]) for s in sf if float(s["t"]) > deck_on and s["surfaces"] != "deck/deck")
    cob_on = next((float(s["t"]) for s in sf if s["surfaces"] == "cobbles/cobbles"), ph["pflaster"])
    cob_off = next((float(s["t"]) for s in sf if float(s["t"]) > cob_on and s["surfaces"] != "cobbles/cobbles"),
                   ph["ende"])
    return {"beton175": (conc + 0.6, ph["bruecke"] - 0.3), "deck120": (deck_on + 0.5, deck_off - 0.3),
            "pflaster50": (cob_on + 0.5, min(cob_off - 0.3, cob_on + 6.5))}


def feats(x):
    c, L = dsp.third_octaves(x)
    return {"lufs": round(dsp.lufs_plain(x), 2), "third": [round(float(v), 2) for v in L], "tp": round(dsp.tp(x), 2)}


def main():
    mp3, out = sys.argv[1], sys.argv[2]
    x = decode(mp3)
    rec = {}
    # halves of the preview with the drive jsons of AU-R2 (kept in its scratch)
    old = json.load(open(os.path.join(AU, "drive_old.json")))
    new = json.load(open(os.path.join(AU, "drive_new.json")))
    n_old = int(46.6 * SR)
    # vorher = first len(old) samples; the gap is 2.0 s; nachher starts at len(vorher) + 2 s
    sil = np.max(np.abs(x), axis=1) < 1e-4
    # first long silence
    i = n_old - int(1.0 * SR)
    while i < len(x) and not sil[i]:
        i += 1
    v_len = i
    rec["vorher"] = (x[:v_len], old)
    rec["nachher"] = (x[v_len + int(2.0 * SR):], new)
    for item in sys.argv[3:]:
        name, p = item.split("=", 1)
        wav, _, js = p.partition(":")
        xx, _ = dsp.load(wav)
        meta = json.load(open(js or os.path.splitext(wav)[0] + ".json"))
        rec[name] = (xx, meta)
    res = {"recordings": {}}
    for name, (xx, meta) in rec.items():
        k = (len(xx) / SR) / float(meta["seconds"])
        st = stretches(meta)
        r = {"len_s": round(len(xx) / SR, 2), "k": round(k, 4), "stretches": {}}
        for sn, (a, b) in st.items():
            seg = xx[int(a * k * SR):int(b * k * SR)]
            r["stretches"][sn] = {"audio_s": [round(a * k, 2), round(b * k, 2)], **feats(seg)}
        res["recordings"][name] = r
        print(f"{name:8s} Länge {len(xx) / SR:6.2f} s, k {k:.4f}: " + "; ".join(
            f"{sn} {v['audio_s']} {v['lufs']:.2f} LUFS TP {v['tp']:.2f}" for sn, v in r["stretches"].items()))
    cen = np.array(dsp.TOB_CENTRES)
    pairs = [("nachher", n) for n in rec if n not in ("vorher", "nachher")] + \
            [("vorher", n) for n in rec if n not in ("vorher", "nachher")] + [("vorher", "nachher")]
    res["diff"] = {}
    for a, b in pairs:
        for sn in ("beton175", "deck120", "pflaster50"):
            A, B = res["recordings"][a]["stretches"][sn], res["recordings"][b]["stretches"][sn]
            ta, tb = np.array(A["third"]), np.array(B["third"])
            m = (cen >= 25) & (cen <= 12500)
            m &= (ta > ta[m].max() - 30) | (tb > tb[m].max() - 30)
            dd = tb - ta
            j = int(np.argmax(np.where(m, np.abs(dd), -1)))
            rms = float(np.sqrt(np.mean(dd[m] ** 2)))
            res["diff"][f"{a}->{b}|{sn}"] = {"dlu": round(B["lufs"] - A["lufs"], 2), "max_third": round(float(dd[j]), 2),
                                             "at": round(float(cen[j])), "rms_third": round(rms, 2)}
            print(f"  {a:8s} -> {b:8s} {sn:10s}: {B['lufs'] - A['lufs']:+.2f} LU, größte Terz {dd[j]:+.2f} dB @ {cen[j]:.0f} Hz, "
                  f"RMS der Terzen {rms:.2f} dB")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
