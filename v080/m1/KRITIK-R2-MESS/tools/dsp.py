"""KRITIK-FAHRBAHN: measurement helpers (numpy only). Loudness and true peak via the repository's qc_lib (copy)."""
from __future__ import annotations

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS/qc_copy")
sys.dont_write_bytecode = True
import qc_lib  # noqa: E402

SR = 44100
# Zwicker critical bands (Bark) edges, Hz
BARK_EDGES = [20, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700, 4400,
              5300, 6400, 7700, 9500, 12000, 15500]
TOB_CENTRES = [1000.0 * 10.0 ** (k / 10.0) for k in range(-17, 13)]   # 20 Hz .. 16 kHz


def load(path: str):
    x, sr = qc_lib.read_audio(path)
    return x, sr


def mono(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, np.float64)
    return x if x.ndim == 1 else x.mean(axis=1)


def lufs(x, sr=SR) -> float:
    return float(qc_lib.integrated_lufs(x, sr))


def lufs_plain(x, sr=SR) -> float:
    """Ungated mean loudness (constant signals: equals the integrated value, but robust for short pieces)."""
    xk = qc_lib.k_weight(qc_lib.as_played(x), sr)
    return float(-0.691 + 10.0 * np.log10(max(float(np.mean(np.sum(xk * xk, axis=1))), 1e-14)))


def tp(x) -> float:
    return float(qc_lib.true_peak_db(x))


def sp(x) -> float:
    return float(qc_lib.sample_peak_db(x))


def crest_db(x) -> float:
    m = mono(x)
    return float(20 * np.log10((np.max(np.abs(m)) + 1e-12) / (np.sqrt(np.mean(m * m)) + 1e-12)))


def psd(x, sr=SR, nfft=8192):
    """Welch PSD as mean-square power per bin (one-sided, mean over channels; the bins sum to the mean square of a
    channel, so a full-scale sine reads -3 dBFS), Hann, 50 % overlap."""
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
        sp_ = np.abs(np.fft.rfft(seg, axis=0)) ** 2
        acc += sp_.mean(axis=1)
        cnt += 1
    acc /= max(cnt, 1) * np.sum(w * w) * nfft
    acc[1:-1] *= 2.0
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    return f, acc


def bands(f, p, edges):
    out = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (f >= lo) & (f < hi)
        out.append(10 * np.log10(max(float(p[m].sum()), 1e-20)))
    return np.array(out)


def third_octaves(x, sr=SR, nfft=16384):
    f, p = psd(x, sr, nfft)
    edges = [c * 10 ** (-0.05) for c in TOB_CENTRES] + [TOB_CENTRES[-1] * 10 ** 0.05]
    return np.array(TOB_CENTRES), bands(f, p, edges)


def bark(x, sr=SR, nfft=8192):
    f, p = psd(x, sr, nfft)
    return bands(f, p, BARK_EDGES)


def zero_phase(x, sr, mag_fn):
    """Applies a magnitude response mag_fn(f) without phase (loudness questions only)."""
    x = np.asarray(x, np.float64)
    squeeze = x.ndim == 1
    if squeeze:
        x = x[:, None]
    n = len(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / sr), 1e-3)
    y = np.fft.irfft(np.fft.rfft(x, axis=0) * mag_fn(f)[:, None], n, axis=0)
    return y[:, 0] if squeeze else y


def hp_mag(fc, order):
    return lambda f: 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order))


def lp_mag(fc, order):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def peak_mag(f0, q, gain_db):
    g = 10 ** (gain_db / 20.0)
    return lambda f: 1.0 + (g - 1.0) / (1.0 + ((f / f0 - f0 / f) * q) ** 2)


def hp180(x, sr=SR):
    """180 Hz high-pass, 4th order (24 dB/octave)."""
    return zero_phase(x, sr, hp_mag(180.0, 4))


def small_speaker(x, sr=SR):
    """A model of a small handheld stereo speaker (inferred, not a measured Steam Deck): 4th-order high-pass at
    200 Hz, a +3 dB presence bump at 3 kHz, 2nd-order low-pass at 14 kHz."""
    h1, h2, h3 = hp_mag(200.0, 4), peak_mag(3000.0, 1.0, 3.0), lp_mag(14000.0, 2)
    return zero_phase(x, sr, lambda f: h1(f) * h2(f) * h3(f))


def frames_env(x, sr=SR, frame_s=0.01, band=None):
    """RMS envelope in frames (optionally of a band-passed signal, zero phase)."""
    m = mono(x)
    if band is not None:
        lo, hi = band
        m = zero_phase(m, sr, lambda f: hp_mag(lo, 4)(f) * lp_mag(hi, 4)(f))
    k = int(frame_s * sr)
    n = len(m) // k
    e = np.sqrt(np.mean(m[:n * k].reshape(n, k) ** 2, axis=1) + 1e-20)
    return e


def autocorr(v, max_lag):
    v = np.asarray(v, np.float64)
    v = v - v.mean()
    n = len(v)
    out = np.zeros(max_lag + 1)
    den = float(np.dot(v, v)) + 1e-20
    for lag in range(max_lag + 1):
        out[lag] = float(np.dot(v[:n - lag], v[lag:])) / den * n / max(n - lag, 1)
    return out


def env_autocorr(x, sr=SR, frame_s=0.01, max_lag_s=4.0, band=None, log=True):
    e = frames_env(x, sr, frame_s, band)
    if log:
        e = 20 * np.log10(e)
    lags = int(max_lag_s / frame_s)
    return np.arange(lags + 1) * frame_s, autocorr(e, lags)


def spec_selfsim(x, sr=SR, frame_s=0.02, max_lag_s=4.0, nfft=1024):
    """Self-similarity of the spectrum frames: for every lag, the mean correlation (over time) of the mean-removed
    log Bark-band energies of frame t and frame t + lag."""
    m = mono(x)
    hop = int(frame_s * sr)
    w = np.hanning(nfft)
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    nb = len(BARK_EDGES) - 1
    idx = [((f >= lo) & (f < hi)) for lo, hi in zip(BARK_EDGES[:-1], BARK_EDGES[1:])]
    frames = []
    for i in range(0, len(m) - nfft, hop):
        s = np.abs(np.fft.rfft(m[i:i + nfft] * w)) ** 2
        frames.append([10 * np.log10(float(s[ix].sum()) + 1e-20) for ix in idx])
    S = np.array(frames)
    S = S - S.mean(axis=0, keepdims=True)
    S = S / (S.std(axis=0, keepdims=True) + 1e-9)
    lags = int(max_lag_s / frame_s)
    out = np.zeros(lags + 1)
    n = len(S)
    for lag in range(lags + 1):
        a, b = S[:n - lag], S[lag:]
        out[lag] = float(np.mean(np.sum(a * b, axis=1) / nb))
    return np.arange(lags + 1) * frame_s, out


def best_peak(lags, ac, lo_s, hi_s):
    m = (lags >= lo_s) & (lags <= hi_s)
    if not np.any(m):
        return 0.0, 0.0
    i = int(np.argmax(np.where(m, ac, -9)))
    return float(lags[i]), float(ac[i])


def modulation_depth(x, sr=SR, frame_s=0.005, band=None):
    """Envelope fluctuation: std/mean of the RMS envelope (5 ms frames) and the share of envelope power in the
    modulation bands 0.5-4, 4-16, 16-64 Hz."""
    e = frames_env(x, sr, frame_s, band)
    mean = float(e.mean()) + 1e-20
    v = e / mean - 1.0
    spec = np.abs(np.fft.rfft(v * np.hanning(len(v)))) ** 2
    fm = np.fft.rfftfreq(len(v), frame_s)
    tot = float(spec[fm > 0.25].sum()) + 1e-20
    out = {"cv": float(np.std(e) / mean)}
    for lo, hi in ((0.5, 4), (4, 16), (16, 64)):
        out[f"m{lo}-{hi}"] = float(spec[(fm >= lo) & (fm < hi)].sum()) / tot
    return out


def tonal_peaks(x, sr=SR, nfft=32768, prom_db=12.0, fmin=40.0, fmax=12000.0, top=6):
    """Narrow spectral peaks standing prom_db above the median of their ±1/3-octave neighbourhood."""
    f, p = psd(x, sr, nfft)
    L = 10 * np.log10(p + 1e-30)
    out = []
    df = f[1] - f[0]
    for i in range(2, len(f) - 2):
        if f[i] < fmin or f[i] > fmax:
            continue
        if L[i] < L[i - 1] or L[i] < L[i + 1]:
            continue
        lo = np.searchsorted(f, f[i] / 1.26)
        hi = np.searchsorted(f, f[i] * 1.26)
        if hi - lo < 8:
            continue
        med = float(np.median(L[lo:hi]))
        if L[i] - med >= prom_db:
            out.append((float(f[i]), float(L[i] - med)))
    # keep strongest, merge neighbours
    out.sort(key=lambda t: -t[1])
    keep = []
    for fr, pr in out:
        if all(abs(fr - k[0]) > 3 * df for k in keep):
            keep.append((fr, pr))
        if len(keep) >= top:
            break
    return sorted(keep)


def spectral_tilt(x, sr=SR, lo=100.0, hi=8000.0):
    """Slope (dB per octave) of a line through the third-octave levels between lo and hi."""
    c, L = third_octaves(x, sr)
    m = (c >= lo) & (c <= hi)
    oct_ = np.log2(c[m])
    a, _b = np.polyfit(oct_, L[m], 1)
    return float(a)


def centroid(x, sr=SR):
    f, p = psd(x, sr, 8192)
    return float(np.sum(f * p) / (np.sum(p) + 1e-20))


def share_below(x, fc, sr=SR):
    f, p = psd(x, sr, 8192)
    return float(p[f < fc].sum() / (p.sum() + 1e-20))


def resample_pitch(y, pitch, n_out):
    """Loop y read at pitch (linear interpolation, as Godot's resampler for pitch_scale), n_out samples."""
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def pan_gains(pan):
    th = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi * 0.25
    return math.cos(th) * math.sqrt(2.0), math.sin(th) * math.sqrt(2.0)
