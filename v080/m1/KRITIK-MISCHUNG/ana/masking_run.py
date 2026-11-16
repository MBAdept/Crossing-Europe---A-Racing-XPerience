#!/usr/bin/env python3
"""Game-mix analysis of KRITIK-MISCHUNG: chain transfer of the race music (from the in-game music-only capture),
masking of the music by the car per phase and section, level sweep, small-speaker variant.
usage: masking_run.py <K dir>   -> res/masking.json + printed tables"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402
import masking as mk  # noqa: E402

SR = alib.SR
K = sys.argv[1]
COPY = os.path.join(K, "copy")
CAP = os.path.join(K, "cap")
MUSIC = os.path.join(COPY, "assets/audio/modern/music")
PHASES = ["idle", "v80", "v130", "v130_full", "v200_full", "v250_full", "lift", "v130_back"]
PIECES = {
    "linke_spur": {"bpm": 132.0, "sections": ["Einzähler", "A1", "B1", "A2", "P1", "B2", "D", "S", "P2", "B3", "A3", "T", "A1'"]},
    "nachtfahrt": {"bpm": 105.0, "sections": ["Einzähler", "A1", "B1", "A2", "C1", "B2", "D", "S", "C2", "B3", "T", "A1'"]},
    "rueckenwind": {"bpm": 150.0, "sections": ["Einzähler", "A1", "B1", "A2", "P1", "B2", "D", "S", "P2", "B3", "A3", "T", "A1'"]},
}
MELODY = range(5, 16)      # 510 Hz .. 3.15 kHz: fundamentals of the leads (D5-F6, C5-A6) and their 2nd harmonics
BASS = range(0, 4)         # < 400 Hz: kick, sub, bass
HIGH = range(16, 23)       # 3.15 .. 12 kHz: hats, shaker, air
ENGINE = range(0, 9)       # < 1.08 kHz: engine orders and their first harmonics
OFFSETS = [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]
SKIP0, SKIP1 = 2.0, 0.8


def load_cap(name: str):
    p = os.path.join(CAP, name + ".wav")
    meta = json.load(open(os.path.join(CAP, name + ".json")))
    return alib.read_audio(p), meta


def phase_slice(meta: dict, ph: str) -> tuple:
    for d in meta["phases"]:
        if d["name"] == ph:
            t0, t1 = float(d["t0"]), float(d["t1"])
            if ph == "lift":
                return t0 + 0.2, t1 - 0.2
            return t0 + SKIP0, t1 - SKIP1
    raise KeyError(ph)


def duck_of(meta: dict, ph: str) -> float:
    a, b = phase_slice(meta, ph)
    v = [r.get("duck", 0.0) for r in meta["log"] if a <= r["t"] <= b]
    return float(np.median(v)) if v else 0.0


def thirds_of(x: np.ndarray) -> np.ndarray:
    f, LL, RR, _ = alib.welch_cross(x, 8192)
    return alib.thirds(f, LL + RR)


def align(rec: np.ndarray, ref: np.ndarray, guess: int, search: int) -> int:
    """Offset o so that rec[i] ~ ref[i + o] (mono cross-correlation around guess)."""
    a = rec.mean(axis=1)
    b = ref.mean(axis=1)
    seg = a[int(1.0 * SR):int(4.0 * SR)]
    lo = max(0, int(1.0 * SR) + guess - search)
    hi = min(len(b), int(4.0 * SR) + guess + search)
    win = b[lo:hi]
    n = 1 << int(math.ceil(math.log2(len(win) + len(seg))))
    c = np.fft.irfft(np.fft.rfft(win, n) * np.conj(np.fft.rfft(seg, n)), n)[:len(win) - len(seg) + 1]
    k = int(np.argmax(c))
    return lo + k - int(1.0 * SR)


def main() -> int:
    out = {"model": "Johnston/MPEG-1 Modell 1, vereinfacht; besseres Ohr; Kalibrierung 1,0 RMS = 94 dB SPL"}
    # --- 1. chain transfer of the race music from the in-game music-only capture (Linke Spur) --------------------
    rec, mmeta = load_cap("gt_music")
    ref = alib.read_audio(os.path.join(MUSIC, "linke_spur.ogg"))
    log = mmeta["log"]
    first = next(r for r in log if r.get("pos", -1) >= 0)
    guess = int((first["pos"] - first["t"]) * SR)
    off = align(rec, ref, guess, int(1.5 * SR))
    out["align_offset_s"] = round(off / SR, 4)
    trans = {}
    for ph in PHASES:
        a, b = phase_slice(mmeta, ph)
        ia, ib = int(a * SR), int(b * SR)
        r_seg = rec[ia:ib]
        f_seg = ref[ia + off:ib + off]
        tr = alib.pdb(1.0) + 10 * np.log10(np.maximum(thirds_of(r_seg), 1e-30) / np.maximum(thirds_of(f_seg), 1e-30))
        lr = alib.integrated_lufs(r_seg) if len(r_seg) > SR else None
        lf = alib.integrated_lufs(f_seg) if len(f_seg) > SR else None
        trans[ph] = {"thirds_db": [round(v, 2) for v in tr], "duck_log": round(duck_of(mmeta, ph), 3),
                     "lufs_rec": None if lr is None else round(lr, 2), "lufs_file": None if lf is None else round(lf, 2)}
    out["transfer"] = trans
    idle = np.array(trans["idle"]["thirds_db"])
    # static gain + race EQ per third (idle: no ducking); smooth tiny deviations, extrapolate the ends flat
    H_db = idle.copy()
    fcs = alib.THIRD_EXACT
    Hbin_db = np.interp(np.log2(np.maximum(mk.F, 1.0)), np.log2(fcs), H_db, left=H_db[0], right=H_db[-1])
    Hbin = 10.0 ** (Hbin_db / 10.0)
    out["H_static_eq_thirds_db"] = [round(v, 2) for v in H_db]
    # --- 2. car maskers per phase ----------------------------------------------------------------------------------
    hp = mk.hp_weight(180.0, 2)
    cars = {}
    for cname in ("gt_car", "gt_engine", "gt_wind", "gt_tyres", "sw_car"):
        if not os.path.exists(os.path.join(CAP, cname + ".wav")):
            continue
        x, meta = load_cap(cname)
        cars[cname] = {}
        for ph in PHASES:
            a, b = phase_slice(meta, ph)
            seg = x[int(a * SR):int(b * SR)]
            P, S = mk.spec_frames(seg)
            Ps, Ss = mk.spec_frames(seg, hp)
            cars[cname][ph] = {"P": P, "T": mk.threshold(P, S), "Ps": Ps, "Ts": mk.threshold(Ps, Ss),
                               "lufs": alib.Loud(seg).ungated(), "duck": duck_of(meta, ph)}
        print(f"Auto {cname}: " + ", ".join(f"{ph} {cars[cname][ph]['lufs']:.1f}" for ph in PHASES), flush=True)
    out["car_lufs"] = {c: {ph: round(v[ph]["lufs"], 2) for ph in PHASES} for c, v in cars.items()}
    ducks = {ph: cars["gt_car"][ph]["duck"] for ph in PHASES}
    out["duck_db"] = {ph: round(v, 3) for ph, v in ducks.items()}
    # --- 3. music sections through the chain against the maskers --------------------------------------------------
    res = {}
    for piece, info in PIECES.items():
        x = alib.read_audio(os.path.join(MUSIC, piece + ".ogg"))
        bar = 4 * 60.0 / info["bpm"] * SR
        res[piece] = {}
        for si, sname in enumerate(info["sections"]):
            a = 0 if si == 0 else int(round((1 + 8 * (si - 1)) * bar))
            b = int(round(bar)) if si == 0 else int(round((1 + 8 * si) * bar))
            seg = x[a:min(b, len(x))]
            if len(seg) < 2 * mk.N:
                continue
            Pm, Sm = mk.spec_frames(seg, Hbin)
            Pms, Sms = mk.spec_frames(seg, Hbin * hp)
            Tm, Tms = mk.threshold(Pm, Sm), mk.threshold(Pms, Sms)
            lufs_ch = alib.integrated_lufs(alib.fft_filter(seg, lambda f: np.sqrt(np.interp(np.log2(np.maximum(f, 1.0)),
                                           np.log2(mk.F[1:]), Hbin[1:]))))
            sec = {"music_lufs_idle": round(lufs_ch, 2), "phases": {}}
            for ph in PHASES:
                d = ducks[ph]
                pr = {}
                for cname in cars:
                    C = cars[cname][ph]
                    row = {}
                    for dv in OFFSETS:
                        g = d + dv
                        hph = mk.audibility(Pm, C["T"], MELODY, g)
                        spk = mk.audibility(Pms, C["Ts"], MELODY, g)
                        e = {"mel_hp": round(hph["audible_energy_share"], 3), "mel_hp_smr": round(hph["median_smr_sel"], 1),
                             "mel_spk": round(spk["audible_energy_share"], 3), "mel_spk_smr": round(spk["median_smr_sel"], 1)}
                        if dv == 0.0 or cname == "gt_car":
                            bh = mk.audibility(Pm, C["T"], BASS, g)
                            hh = mk.audibility(Pm, C["T"], HIGH, g)
                            cu = mk.car_under_music(C["P"], Tm, ENGINE, g)
                            cus = mk.car_under_music(C["Ps"], Tms, ENGINE, g)
                            e.update({"bass_hp": round(bh["audible_energy_share"], 3), "high_hp": round(hh["audible_energy_share"], 3),
                                      "car_aud_hp": round(cu["audible_energy_share"], 3), "car_smr_hp": round(cu["median_smr_sel"], 1),
                                      "car_aud_spk": round(cus["audible_energy_share"], 3)})
                        if dv == 0.0:
                            e["smr_band_hp"] = [round(v, 1) for v in hph["median_smr_band"]]
                            e["smr_band_spk"] = [round(v, 1) for v in spk["median_smr_band"]]
                        row[str(dv)] = e
                    pr[cname] = row
                sec["phases"][ph] = pr
            res[piece][sname] = sec
            g = sec["phases"]["v130"]["gt_car"]["0.0"]
            g2 = sec["phases"]["v250_full"]["gt_car"]["0.0"]
            print(f"{piece:12s} {sname:9s} Musik {lufs_ch:6.1f} LUFS | 130: Melodie hörbar {g['mel_hp']:.2f} (SMR {g['mel_hp_smr']:5.1f}) "
                  f"Lautspr. {g['mel_spk']:.2f} | Auto unter Musik {g['car_aud_hp']:.2f} | 250 Vollgas: Melodie {g2['mel_hp']:.2f} "
                  f"(SMR {g2['mel_hp_smr']:5.1f}) Lautspr. {g2['mel_spk']:.2f}", flush=True)
        del x
    out["sections"] = res
    with open(os.path.join(K, "res", "masking.json"), "w") as fh:
        json.dump(out, fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
