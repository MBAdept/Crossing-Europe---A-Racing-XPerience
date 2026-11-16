#!/usr/bin/env python3
"""Alternatives of the race EQ and of the ducking depth (runtime config, no re-render), evaluated with the masking
model against the measured car (KRITIK-MISCHUNG). The shelf shape is fitted to the in-game transfer of the current
race EQ (measured from the music-only capture). Loudness of the music is matched to the current chain at idle, so the
alternatives differ in spectrum (and in the ducking where stated) only.
usage: eq_alt.py <K>  -> res/eq_alt.json"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402
import masking as mk  # noqa: E402
from masking_run import PIECES, MELODY, BASS, HIGH, ENGINE, load_cap, phase_slice  # noqa: E402

K = sys.argv[1]
SR = alib.SR
STATIC = 1.0 + 20 * math.log10(0.7) + 20 * math.log10(0.8)      # context race + music slider + master volume
M = json.load(open(os.path.join(K, "res", "masking.json")))
FC = alib.THIRD_EXACT
H_IDLE = np.array(M["H_static_eq_thirds_db"])
EQ_MEAS = H_IDLE - STATIC                                         # the current race EQ, measured in the game


def shelf(f, fc, g, p):
    return g / (1.0 + (np.maximum(f, 1.0) / fc) ** p)


def fit_p():
    best = (1e9, 2.0)
    for p in np.arange(1.0, 4.01, 0.05):
        model = shelf(FC, 1100.0, -3.2, p) + shelf(FC, 180.0, 2.2, p)
        sel = (FC >= 40) & (FC <= 8000)
        e = float(np.sum((model[sel] - EQ_MEAS[sel]) ** 2))
        if e < best[0]:
            best = (e, float(p))
    return best[1], math.sqrt(best[0] / np.sum((FC >= 40) & (FC <= 8000)))


P_SHAPE, RMS_ERR = fit_p()


def eq_db(f, eq):
    out = np.zeros_like(np.asarray(f, float))
    for e in eq:
        if e["shelf"] == "low":
            out = out + shelf(f, e["hz"], e["db"], P_SHAPE)
        else:
            out = out + (e["db"] - shelf(f, e["hz"], e["db"], P_SHAPE))
    return out


CONFIGS = {
    "heute": {"eq": [{"shelf": "low", "hz": 1100.0, "db": -3.2}, {"shelf": "low", "hz": 180.0, "db": 2.2}], "depth": 4.5},
    "nur_tiefen_-3_160": {"eq": [{"shelf": "low", "hz": 160.0, "db": -3.0}], "depth": 4.5},
    "ohne_eq": {"eq": [], "depth": 4.5},
    "heute_duck_2.5": {"eq": [{"shelf": "low", "hz": 1100.0, "db": -3.2}, {"shelf": "low", "hz": 180.0, "db": 2.2}], "depth": 2.5},
    "heute_duck_1.5": {"eq": [{"shelf": "low", "hz": 1100.0, "db": -3.2}, {"shelf": "low", "hz": 180.0, "db": 2.2}], "depth": 1.5},
    "tiefen_-3_160_duck_2.5": {"eq": [{"shelf": "low", "hz": 160.0, "db": -3.0}], "depth": 2.5},
}
PH = ["v80", "v130", "v130_full", "v200_full", "v250_full"]


def main():
    print(f"Form der Kuhschwanzfilter: Exponent {P_SHAPE:.2f}, Restfehler {RMS_ERR:.2f} dB gegen die Messung im Spiel")
    ducks = {k: float(v) for k, v in M["duck_db"].items()}
    hp = mk.hp_weight(180.0, 2)
    x, meta = load_cap("gt_car")
    cars = {}
    for ph in PH:
        a, b = phase_slice(meta, ph)
        seg = x[int(a * SR):int(b * SR)]
        P, S = mk.spec_frames(seg)
        Ps, Ss = mk.spec_frames(seg, hp)
        cars[ph] = {"P": P, "T": mk.threshold(P, S), "Ps": Ps, "Ts": mk.threshold(Ps, Ss)}
    out = {"shape_p": P_SHAPE, "fit_rms_db": RMS_ERR, "configs": {}}
    # music sections: A1, B1, D of every piece (file level)
    secs = []
    for piece, info in PIECES.items():
        xm = alib.read_audio(os.path.join(K, "copy/assets/audio/modern/music", piece + ".ogg"))
        bar = 4 * 60.0 / info["bpm"] * SR
        for si, sname in enumerate(info["sections"]):
            if sname not in ("A1", "B1", "D", "S", "B2"):
                continue
            a = int(round((1 + 8 * (si - 1)) * bar))
            b = int(round((1 + 8 * si) * bar))
            secs.append((piece, sname, xm[a:b].copy()))
        del xm
    for cname, cfg in CONFIGS.items():
        d_eq = eq_db(mk.F, cfg["eq"])
        Hbin_db = STATIC + d_eq
        # loudness match to "heute" at idle over all sections
        res = {"eq": cfg["eq"], "depth": cfg["depth"], "rows": {}}
        lu_now, lu_new = [], []
        cur_bin = np.interp(np.log2(np.maximum(mk.F, 1.0)), np.log2(FC), H_IDLE, left=H_IDLE[0], right=H_IDLE[-1])
        for piece, sname, seg in secs:
            for Hdb, acc in ((cur_bin, lu_now), (Hbin_db, lu_new)):
                g = np.sqrt(10 ** (Hdb / 10.0))
                acc.append(alib.integrated_lufs(alib.fft_filter(seg, lambda f, g=g: np.interp(f, mk.F, g), 0.1)))
        match = float(np.mean(lu_now) - np.mean(lu_new))
        res["context_race_db_for_equal_loudness"] = round(1.0 + match, 2)
        Hbin = 10 ** ((Hbin_db + match) / 10.0)
        agg = {ph: {"mel": [], "smr": [], "bass": [], "high": [], "car": [], "mel_spk": []} for ph in PH}
        for piece, sname, seg in secs:
            Pm, Sm = mk.spec_frames(seg, Hbin)
            Pms, Sms = mk.spec_frames(seg, Hbin * hp)
            Tm = mk.threshold(Pm, Sm)
            for ph in PH:
                dk = ducks[ph] * cfg["depth"] / 4.5
                C = cars[ph]
                mel = mk.audibility(Pm, C["T"], MELODY, dk)
                agg[ph]["mel"].append(mel["audible_energy_share"])
                agg[ph]["smr"].append(mel["median_smr_sel"])
                agg[ph]["bass"].append(mk.audibility(Pm, C["T"], BASS, dk)["audible_energy_share"])
                agg[ph]["high"].append(mk.audibility(Pm, C["T"], HIGH, dk)["audible_energy_share"])
                agg[ph]["car"].append(mk.car_under_music(C["P"], Tm, ENGINE, dk)["audible_energy_share"])
                agg[ph]["mel_spk"].append(mk.audibility(Pms, C["Ts"], MELODY, dk)["audible_energy_share"])
        for ph in PH:
            res["rows"][ph] = {k: round(float(np.mean(v)) if k != "smr" else float(np.median(v)), 3) for k, v in agg[ph].items()}
            res["rows"][ph]["duck_db"] = round(ducks[ph] * cfg["depth"] / 4.5, 2)
        out["configs"][cname] = res
        print(f"{cname:24s} Kontext race für gleiche Lautheit {res['context_race_db_for_equal_loudness']:+.2f} dB | " +
              " | ".join(f"{ph}: Mel {res['rows'][ph]['mel']:.2f} SMR {res['rows'][ph]['smr']:5.1f} Bass {res['rows'][ph]['bass']:.2f} Auto {res['rows'][ph]['car']:.2f}"
                         for ph in ("v130", "v130_full", "v250_full")), flush=True)
    json.dump(out, open(os.path.join(K, "res", "eq_alt.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
