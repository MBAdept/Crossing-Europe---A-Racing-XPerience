#!/usr/bin/env python3
"""Masking estimate music <-> car per critical band (KRITIK-MISCHUNG).

Model (simplified Johnston / MPEG-1 psychoacoustic model 1, per ear):
  frames of 4096 samples (Hann, hop 2048) per channel; power per Bark band (25 bands, Zwicker edges); masker
  tonality per band from its spectral flatness (alpha = SFM_dB / -60, clipped); masking offset
  O = alpha (14.5 + z) + (1 - alpha) 5.5 dB; Schroeder spreading function, renormalised so that a flat masker gives
  "masker - O"; threshold in quiet (Terhardt) with the calibration 1.0 RMS = 94 dB SPL (assumption: the full game mix
  at -16 LUFS is heard at about 75 dB SPL). A music band is audible when its level is above the car's threshold on at
  least one ear (better ear; binaural unmasking is not modelled - conservative for headphones).

Inputs: the car recordings at the Master (mix_speeds.gd, music muted) and the music files with the chain gain of the
race context (static gain, race EQ and the ducking per phase measured from the in-game music-only recording).
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402

SR = alib.SR
N = 4096
HOP = 2048
EDGES = np.array([0, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700,
                  4400, 5300, 6400, 7700, 9500, 12000, 15500, 20000], float)
NB = len(EDGES) - 1
ZC = np.arange(NB) + 0.5
FC = np.sqrt(np.maximum(EDGES[:-1], 20.0) * EDGES[1:])
F = np.fft.rfftfreq(N, 1.0 / SR)
BAND_OF = np.searchsorted(EDGES, F, side="right") - 1
BAND_OF[BAND_OF >= NB] = NB - 1
WIN = np.hanning(N)
NORM = 2.0 / (N * np.sum(WIN * WIN))
CAL_DB = 94.0            # 1.0 RMS (0 dB "power") = 94 dB SPL


def schroeder(dz):
    dz = np.asarray(dz, float)
    return 15.81 + 7.5 * (dz + 0.474) - 17.5 * np.sqrt(1.0 + (dz + 0.474) ** 2)


SPREAD = 10.0 ** (schroeder(ZC[:, None] - ZC[None, :]) / 10.0)    # [maskee i, masker j]
SPREAD_NORM = SPREAD.sum(axis=1)


def ath_db(f):
    k = np.maximum(f, 20.0) / 1000.0
    return 3.64 * k ** -0.8 - 6.5 * np.exp(-0.6 * (k - 3.3) ** 2) + 1e-3 * k ** 4


ATH_P = 10.0 ** ((ath_db(FC) - CAL_DB) / 10.0)        # band threshold in quiet as power re 1.0


def spec_frames(x: np.ndarray, weight: np.ndarray | None = None):
    """x (n, 2) -> band power [frames, 2, NB] and spectral flatness (dB) [frames, 2, NB]."""
    n = (len(x) - N) // HOP + 1
    if n <= 0:
        raise ValueError("zu kurz")
    idx = np.arange(N)[None, :] + HOP * np.arange(n)[:, None]
    out_p = np.zeros((n, 2, NB))
    out_s = np.zeros((n, 2, NB))
    for c in range(2):
        seg = x[:, c][idx] * WIN[None, :]
        P = np.abs(np.fft.rfft(seg, axis=1)) ** 2 * NORM
        if weight is not None:
            P = P * weight[None, :]
        for b in range(NB):
            sel = BAND_OF == b
            pb = P[:, sel]
            out_p[:, c, b] = pb.sum(axis=1)
            g = np.exp(np.mean(np.log(pb + 1e-30), axis=1))
            a = np.mean(pb, axis=1) + 1e-30
            out_s[:, c, b] = 10.0 * np.log10(np.maximum(g / a, 1e-12))
    return out_p, out_s


def threshold(P: np.ndarray, sfm_db: np.ndarray) -> np.ndarray:
    """Masked threshold (power) [frames, 2, NB] of a masker with band power P and flatness sfm_db."""
    alpha = np.clip(sfm_db / -60.0, 0.0, 1.0)
    off = alpha * (14.5 + ZC[None, None, :]) + (1.0 - alpha) * 5.5
    E = P * 10.0 ** (-off / 10.0)
    C = np.einsum("fcj,ij->fci", E, SPREAD) / SPREAD_NORM[None, None, :]
    return np.maximum(C, ATH_P[None, None, :])


def hp_weight(fc: float, order: int = 2) -> np.ndarray:
    return alib.butter_hp_response(fc, order, F) ** 2


def audibility(Pm: np.ndarray, Tc: np.ndarray, bands, gain_db: float = 0.0) -> dict:
    """Music frames Pm [fm, 2, NB] against a (stationary) car threshold Tc [fc, 2, NB] (cycled)."""
    fm = len(Pm)
    Tcc = Tc[np.arange(fm) % len(Tc)]
    g = 10.0 ** (gain_db / 10.0)
    Pmg = Pm * g
    smr = 10.0 * np.log10(np.maximum(Pmg, 1e-30) / Tcc)          # per ear
    best = np.argmax(smr, axis=1)                                   # better ear per frame/band
    smr_b = np.take_along_axis(smr, best[:, None, :], axis=1)[:, 0, :]
    pm_b = np.take_along_axis(Pmg, best[:, None, :], axis=1)[:, 0, :]
    # cells where the music is present at all (above quiet and within 40 dB of the loudest band of the frame)
    pres = (pm_b > ATH_P[None, :]) & (pm_b > pm_b.max(axis=1, keepdims=True) * 1e-4)
    sel = np.zeros(NB, bool)
    sel[list(bands)] = True
    m = pres & sel[None, :]
    w = pm_b * m
    aud = float(np.sum(w * (smr_b > 0.0)) / max(np.sum(w), 1e-30))
    cells = float(np.mean((smr_b > 0.0)[m])) if np.any(m) else float("nan")
    med = [float(np.median(smr_b[:, b])) for b in range(NB)]
    return {"audible_energy_share": aud, "audible_cells": cells, "median_smr_band": med,
            "median_smr_sel": float(np.median(smr_b[:, sel])) if np.any(sel) else float("nan")}


def car_under_music(Pc: np.ndarray, Tm: np.ndarray, bands, music_gain_db: float = 0.0) -> dict:
    """The car's audibility under the music's threshold (music frames cycled against car frames)."""
    fm = len(Tm)
    Pcc = Pc[np.arange(fm) % len(Pc)]
    smr = 10.0 * np.log10(np.maximum(Pcc, 1e-30) / (Tm * 10.0 ** (music_gain_db / 10.0)))
    smr_b = smr.max(axis=1)
    pc_b = Pcc.max(axis=1)
    sel = np.zeros(NB, bool)
    sel[list(bands)] = True
    pres = (pc_b > ATH_P[None, :]) & sel[None, :]
    w = pc_b * pres
    return {"audible_energy_share": float(np.sum(w * (smr_b > 0)) / max(np.sum(w), 1e-30)),
            "median_smr_sel": float(np.median(smr_b[:, sel])),
            "median_smr_band": [float(np.median(smr_b[:, b])) for b in range(NB)]}
