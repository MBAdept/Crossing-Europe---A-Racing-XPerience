"""AU-R measurement helpers (numpy only). Loudness and true peak via the repository's qc_lib; envelope
autocorrelation as in KRITIK-FAHRBAHN dsp.py (10 ms RMS frames, dB envelope, mean removed, normalised,
unbiased by n/(n-lag))."""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

WT = None
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2/qc_copy")
sys.dont_write_bytecode = True
import qc_lib  # noqa: E402

SR = 44100
TOB_CENTRES = [1000.0 * 10.0 ** (k / 10.0) for k in range(-17, 13)]   # 20 Hz .. 16 kHz


def load(path: str) -> np.ndarray:
    if path.endswith(".f32"):
        x = np.fromfile(path, dtype="<f4").astype(np.float64)
        return x.reshape(-1, 2)
    x, sr = qc_lib.read_audio(path)
    assert sr == SR
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return x


def lufs(x) -> float:
    return float(qc_lib.integrated_lufs(x, SR))


def lufs_plain(x) -> float:
    xk = qc_lib.k_weight(qc_lib.as_played(x), SR)
    return float(-0.691 + 10.0 * np.log10(max(float(np.mean(np.sum(xk * xk, axis=1))), 1e-14)))


def tp(x) -> float:
    return float(qc_lib.true_peak_db(x))


def sp(x) -> float:
    return float(20 * np.log10(max(float(np.max(np.abs(x))), 1e-12)))


def psd(x, nfft=16384):
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = len(x)
    if n < nfft:
        nfft = 1 << int(math.floor(math.log2(max(n, 64))))
    w = np.hanning(nfft)
    hop = nfft // 2
    acc = np.zeros(nfft // 2 + 1)
    cnt = 0
    for i in range(0, n - nfft + 1, hop):
        seg = x[i:i + nfft] * w[:, None]
        acc += (np.abs(np.fft.rfft(seg, axis=0)) ** 2).mean(axis=1)
        cnt += 1
    acc /= max(cnt, 1) * np.sum(w * w) * nfft
    acc[1:-1] *= 2.0
    return np.fft.rfftfreq(nfft, 1.0 / SR), acc


def third_octaves(x, nfft=16384):
    f, p = psd(x, nfft)
    out = []
    for c in TOB_CENTRES:
        lo, hi = c * 10 ** (-0.05), c * 10 ** 0.05
        m = (f >= lo) & (f < hi)
        out.append(10 * np.log10(max(float(p[m].sum()), 1e-20)))
    return np.array(out)


def zero_phase(x, mag_fn):
    x = np.asarray(x, np.float64)
    n = len(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    return np.fft.irfft(np.fft.rfft(x) * mag_fn(f), n)


def band(x, lo, hi):
    return zero_phase(x, lambda f: (1.0 / np.sqrt(1.0 + (lo / f) ** 8)) * (1.0 / np.sqrt(1.0 + (f / hi) ** 8)))


def env_autocorr(sig, frame_s=0.01, max_lag_s=8.0):
    k = int(frame_s * SR)
    n = len(sig) // k
    e = np.sqrt(np.mean(sig[:n * k].reshape(n, k) ** 2, axis=1) + 1e-20)
    e = 20 * np.log10(e)
    e = e - e.mean()
    lags = int(max_lag_s / frame_s)
    den = float(np.dot(e, e)) + 1e-20
    out = np.zeros(lags + 1)
    for lag in range(lags + 1):
        if n - lag < 10:
            break
        out[lag] = float(np.dot(e[:n - lag], e[lag:])) / den * n / (n - lag)
    return np.arange(lags + 1) * frame_s, out


def peaks(lags, ac, lo, hi, min_prom=0.05):
    """Local maxima of ac in [lo, hi] (prominence over the neighbours within ±0.15 s), strongest first."""
    out = []
    w = int(0.15 / (lags[1] - lags[0]))
    for i in range(1, len(ac) - 1):
        if lags[i] < lo or lags[i] > hi:
            continue
        a = max(0, i - w)
        b = min(len(ac), i + w + 1)
        if ac[i] >= ac[a:b].max() and ac[i] - min(ac[a:b].min(), ac[i]) >= min_prom:
            out.append((round(float(lags[i]), 2), round(float(ac[i]), 3)))
    out.sort(key=lambda t: -t[1])
    return out


def repetition(x, bands=((600.0, 1600.0), (2500.0, 8000.0), None)):
    """Per band (None = broadband) and per signal (mono sum, left, right): the maximum of the envelope
    autocorrelation in 0.3-3 s (as KRITIK-FAHRBAHN: best value, not only a local peak), the local peaks in 0.3-3 s
    and every local peak up to 8 s."""
    res = {}
    sigs = {"mono": x.mean(axis=1), "L": x[:, 0], "R": x[:, 1]}
    for b in bands:
        key = "broad" if b is None else f"{int(b[0])}-{int(b[1])}"
        res[key] = {}
        for sname, s in sigs.items():
            sb = s if b is None else band(s, b[0], b[1])
            lags, ac = env_autocorr(sb)
            m = (lags >= 0.3) & (lags <= 3.0)
            i = int(np.argmax(np.where(m, ac, -9)))
            res[key][sname] = {"max_0.3_3": [round(float(lags[i]), 2), round(float(ac[i]), 3)],
                               "peaks_0.3_3": peaks(lags, ac, 0.3, 3.0)[:4],
                               "peaks_3_8": peaks(lags, ac, 3.0, 8.0)[:4]}
    return res


def summary(path: str) -> dict:
    x = load(path)
    return {"seconds": round(len(x) / SR, 2), "lufs": round(lufs(x), 2), "tp": round(tp(x), 2), "sp": round(sp(x), 2)}
