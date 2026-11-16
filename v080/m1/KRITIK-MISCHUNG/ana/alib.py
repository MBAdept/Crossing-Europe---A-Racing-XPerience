"""Independent measurement library of the review KRITIK-MISCHUNG (numpy only, no project code).

Loudness after ITU-R BS.1770-4 / EBU R 128 (digital K-weighting biquads re-derived for the sample rate, applied
through their exact frequency response on a zero-padded FFT), short-term / momentary loudness, loudness range after
EBU Tech 3342, true peak by 4x band-limited (FFT) oversampling, third-octave long-term spectra (Welch), band shares,
spectral tilt, stereo correlation and side/mid ratio per band, modulation spectrum, bar self-similarity.
"""
from __future__ import annotations

import math
import subprocess

import numpy as np

SR = 44100


# ------------------------------------------------------------------------------------------------------------------
# io
# ------------------------------------------------------------------------------------------------------------------

def read_audio(path: str, sr: int = SR) -> np.ndarray:
    """Any file -> float64 (n, 2) at sr through ffmpeg (mono is duplicated on both channels, as the game plays it)."""
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(sr), "-"],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, "<f4").astype(np.float64).reshape(-1, 2)


def write_wav16(path: str, x: np.ndarray, sr: int = SR) -> None:
    import wave
    y = np.clip(np.round(np.asarray(x) * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(y.shape[1] if y.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(y.tobytes())


def db(x: float, floor: float = -200.0) -> float:
    return float(20.0 * math.log10(x)) if x > 0 else floor


def pdb(p: float, floor: float = -200.0) -> float:
    return float(10.0 * math.log10(p)) if p > 0 else floor


# ------------------------------------------------------------------------------------------------------------------
# filters through their frequency response (exact steady state; zero padding absorbs the decaying tails)
# ------------------------------------------------------------------------------------------------------------------

def biquad_response(b, a, f, sr=SR):
    z = np.exp(-1j * 2.0 * np.pi * np.asarray(f) / sr)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def k_biquads(sr=SR):
    """The two K-weighting stages (libebur128 formulas: BS.1770 prototypes re-derived for any sample rate)."""
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / sr)
    Vh = 10.0 ** (G / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2.0 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / sr)
    b2 = [1.0, -2.0, 1.0]
    d = 1.0 + K / Q + K * K
    a2 = [1.0, 2.0 * (K * K - 1.0) / d, (1.0 - K / Q + K * K) / d]
    return (b1, a1), (b2, a2)


def fft_filter(x: np.ndarray, H_of_f, pad_s: float = 1.0, sr: int = SR) -> np.ndarray:
    """y = x filtered by the frequency response H_of_f(f) (complex), zero padded."""
    x = np.asarray(x, np.float64)
    one = x.ndim == 1
    if one:
        x = x[:, None]
    n = len(x)
    pad = int(pad_s * sr)
    m = 1 << int(math.ceil(math.log2(n + pad)))
    f = np.fft.rfftfreq(m, 1.0 / sr)
    H = H_of_f(f)
    X = np.fft.rfft(x, m, axis=0)
    y = np.fft.irfft(X * H[:, None], m, axis=0)[:n]
    return y[:, 0] if one else y


def k_weight(x: np.ndarray, sr: int = SR) -> np.ndarray:
    (b1, a1), (b2, a2) = k_biquads(sr)
    return fft_filter(x, lambda f: biquad_response(b1, a1, f, sr) * biquad_response(b2, a2, f, sr), 1.0, sr)


def butter_hp_response(fc: float, order: int, f):
    """Magnitude-only (zero phase) Butterworth high-pass |H| – for 'small speaker' variants."""
    f = np.maximum(np.asarray(f, np.float64), 1e-6)
    return 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order))


def butter_lp_response(fc: float, order: int, f):
    f = np.asarray(f, np.float64)
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def band_filter(x: np.ndarray, lo: float, hi: float, sr: int = SR) -> np.ndarray:
    """Brick-wall band (zero phase) – for band statistics only."""
    def H(f):
        return ((f >= lo) & (f < hi)).astype(np.float64)
    return fft_filter(x, H, 0.05, sr)


# ------------------------------------------------------------------------------------------------------------------
# loudness
# ------------------------------------------------------------------------------------------------------------------

def _blocks(p: np.ndarray, w: int, h: int) -> np.ndarray:
    if len(p) < w:
        return np.array([float(np.mean(p))]) if len(p) else np.array([0.0])
    c = np.concatenate([[0.0], np.cumsum(p)])
    idx = np.arange(0, len(p) - w + 1, h)
    return (c[idx + w] - c[idx]) / w


def _L(p):
    return -0.691 + 10.0 * np.log10(np.maximum(p, 1e-20))


class Loud:
    """Loudness measures of one stereo signal (computed once from the K-weighted power)."""

    def __init__(self, x: np.ndarray, sr: int = SR):
        xk = k_weight(x, sr)
        self.p = np.sum(xk * xk, axis=1)          # channel weights 1, 1
        self.sr = sr

    def integrated(self, a: int = 0, b: int | None = None) -> float:
        p = self.p[a:b]
        bl = _blocks(p, int(0.4 * self.sr), int(0.1 * self.sr))
        l = _L(bl)
        keep = l > -70.0
        if not np.any(keep):
            return -70.0
        rel = float(_L(np.mean(bl[keep]))) - 10.0
        k2 = keep & (l > rel)
        return float(_L(np.mean(bl[k2])))

    def ungated(self, a: int = 0, b: int | None = None) -> float:
        return float(_L(np.mean(self.p[a:b])))

    def short_term(self, hop_s: float = 0.1, a: int = 0, b: int | None = None) -> np.ndarray:
        return _L(_blocks(self.p[a:b], int(3.0 * self.sr), int(hop_s * self.sr)))

    def momentary(self, hop_s: float = 0.1, a: int = 0, b: int | None = None) -> np.ndarray:
        return _L(_blocks(self.p[a:b], int(0.4 * self.sr), int(hop_s * self.sr)))

    def lra(self, a: int = 0, b: int | None = None) -> float:
        st = self.short_term(0.1, a, b)
        st = st[st > -70.0]
        if len(st) < 2:
            return 0.0
        rel = float(_L(np.mean(10.0 ** ((st + 0.691) / 10.0)))) - 20.0
        st = st[st > rel]
        return float(np.percentile(st, 95) - np.percentile(st, 10)) if len(st) > 1 else 0.0


def integrated_lufs(x: np.ndarray, sr: int = SR) -> float:
    return Loud(x, sr).integrated()


def true_peak_db(x: np.ndarray, os_: int = 4, chunk: int = 1 << 17, ov: int = 2048) -> float:
    """4x band-limited oversampling (FFT zero-stuffing per overlapping chunk; the signal is padded with zeros so that
    its own start and end are the only edges, as for a reconstruction filter)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    pk = float(np.max(np.abs(x)))
    x = np.pad(x, ((ov, ov), (0, 0)))
    n = len(x)
    s = ov
    while s < n - ov:
        a = s - ov
        b = min(n, s + chunk + ov)
        seg = x[a:b]
        m = len(seg)
        if m % 2:
            seg = np.pad(seg, ((0, 1), (0, 0)))
            m += 1
        X = np.fft.rfft(seg, axis=0)
        X[-1] *= 0.5
        Y = np.zeros((m * os_ // 2 + 1, seg.shape[1]), complex)
        Y[:len(X)] = X
        y = np.fft.irfft(Y, m * os_, axis=0) * os_
        lo = ov * os_
        hi = lo + min(chunk, n - ov - s) * os_
        pk = max(pk, float(np.max(np.abs(y[lo:hi]))))
        s += chunk
    return db(pk)


# ------------------------------------------------------------------------------------------------------------------
# spectra
# ------------------------------------------------------------------------------------------------------------------

THIRD_CENTERS = np.array([25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250,
                          1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000], float)
THIRD_EXACT = 1000.0 * 2.0 ** (np.round(3.0 * np.log2(THIRD_CENTERS / 1000.0)) / 3.0)


def welch_cross(x: np.ndarray, nfft: int = 32768, hop: int | None = None, sr: int = SR):
    """Welch auto and cross spectra of a stereo signal: f, S_LL, S_RR, S_LR (complex), averaged (power per bin)."""
    hop = hop or nfft // 2
    w = np.hanning(nfft)
    n = len(x)
    if n < nfft:
        x = np.pad(x, ((0, nfft - n), (0, 0)))
        n = nfft
    starts = np.arange(0, n - nfft + 1, hop)
    LL = np.zeros(nfft // 2 + 1)
    RR = np.zeros(nfft // 2 + 1)
    LR = np.zeros(nfft // 2 + 1, complex)
    for i in range(0, len(starts), 64):
        st = starts[i:i + 64]
        seg = np.stack([x[s:s + nfft] for s in st]) * w[None, :, None]
        X = np.fft.rfft(seg, axis=1)
        L, R = X[:, :, 0], X[:, :, 1]
        LL += np.sum(np.abs(L) ** 2, axis=0)
        RR += np.sum(np.abs(R) ** 2, axis=0)
        LR += np.sum(L * np.conj(R), axis=0)
    k = len(starts) * np.sum(w * w)
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    return f, LL / k, RR / k, LR / k


def band_sum(f, S, lo, hi):
    sel = (f >= lo) & (f < hi)
    return float(np.sum(S[sel]))


def thirds(f, S):
    """Power per third-octave band (exact base-2 edges)."""
    out = []
    for fc in THIRD_EXACT:
        lo, hi = fc * 2.0 ** (-1.0 / 6.0), fc * 2.0 ** (1.0 / 6.0)
        out.append(band_sum(f, S, lo, hi))
    return np.array(out)


def tilt_db_per_oct(levels_db: np.ndarray, lo: float = 100.0, hi: float = 10000.0) -> float:
    sel = (THIRD_CENTERS >= lo) & (THIRD_CENTERS <= hi)
    xx = np.log2(THIRD_EXACT[sel])
    yy = levels_db[sel]
    return float(np.polyfit(xx, yy, 1)[0])


# ------------------------------------------------------------------------------------------------------------------
# modulation, onsets, bars
# ------------------------------------------------------------------------------------------------------------------

def envelope(x_mono: np.ndarray, frame: int = 220) -> np.ndarray:
    """RMS envelope in frames of `frame` samples (5 ms at 44.1 kHz)."""
    n = len(x_mono) // frame
    return np.sqrt(np.mean(x_mono[:n * frame].reshape(n, frame) ** 2, axis=1) + 1e-20)


def _band_var(env: np.ndarray, fr: float, lo: float, hi: float) -> float:
    """Variance of the normalised envelope (env / mean - 1) in the modulation band [lo, hi) Hz."""
    e = env / (np.mean(env) + 1e-20) - 1.0
    E = np.fft.rfft(e)
    f = np.fft.rfftfreq(len(e), 1.0 / fr)
    sel = (f >= lo) & (f < hi)
    return float(2.0 * np.sum(np.abs(E[sel]) ** 2) / len(e) ** 2)


def modulation_index(env: np.ndarray, fr: float, f_mod: float, bw_rel: float = 0.06) -> float:
    """Depth m of the envelope modulation at f_mod (a sinusoidal AM with depth m gives m)."""
    return float(math.sqrt(2.0 * _band_var(env, fr, f_mod * (1 - bw_rel), f_mod * (1 + bw_rel))))


def mod_spectrum(env: np.ndarray, fr: float, centers=(0.5, 1, 2, 4, 8, 16)) -> dict:
    """Modulation depth per octave band of modulation frequency (sqrt(2 var))."""
    return {c: float(math.sqrt(2.0 * _band_var(env, fr, c / math.sqrt(2), c * math.sqrt(2)))) for c in centers}


def chroma_bar(x_mono: np.ndarray, sr: int = SR) -> np.ndarray:
    """12-bin pitch-class energy of a segment (STFT 8192, 70 Hz .. 2 kHz, peaks only)."""
    n, hop = 8192, 4096
    if len(x_mono) < n:
        return np.zeros(12)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    sel = (f >= 70.0) & (f <= 2000.0)
    pcs = (np.round(12.0 * np.log2(np.maximum(f, 1.0) / 440.0)) + 9).astype(int) % 12
    w = np.hanning(n)
    starts = np.arange(0, len(x_mono) - n, hop)
    seg = np.stack([x_mono[s:s + n] * w for s in starts])
    mag = np.abs(np.fft.rfft(seg, axis=1)) ** 2
    acc = np.bincount(pcs[sel], weights=np.sum(mag[:, sel], axis=0), minlength=12)
    return acc / (np.linalg.norm(acc) + 1e-20)
