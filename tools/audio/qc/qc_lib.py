"""Measurements for the sound files of the profile "Modern" (python3 + numpy; ffmpeg only to decode Ogg Vorbis).

Used by tools/audio/qc/audio_qc.py (checks) and tools/audio/modern/modern_lib.py (the generators write the measured
values into the manifests). Everything here is deterministic.

  read_audio(path)            -> (samples float64 (frames, channels), sample rate)   WAV natively, .ogg via ffmpeg
  read_i16(path, channels)    -> raw interleaved int16 (engine banks)
  integrated_lufs(x, sr)      ITU-R BS.1770-4: K weighting, 400-ms blocks, absolute gate -70, relative gate -10 LU
  loudness_range(x, sr)       EBU Tech 3342 (3-s blocks, 10th..95th percentile above the relative gate -20 LU)
  short_term_max / momentary_max
  true_peak_db(x)             4x oversampled (polyphase windowed sinc), dBTP
  sample_peak_db, dc_offset_db, clipped_runs
  loop_seam(x, begin, end)    step across the loop point against the signal's own steps near it and in the loop
A mono file is measured as it plays in the game: the same signal on both channels.
"""
from __future__ import annotations

import hashlib
import math
import shutil
import subprocess
import wave

import numpy as np

SILENCE_DB = -120.0


def db(x) -> float:
    return float(20.0 * np.log10(max(float(np.max(np.abs(x))) if np.size(x) else 0.0, 10.0 ** (SILENCE_DB / 20.0))))


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# --- reading ------------------------------------------------------------------------------------------------------

def read_wav(path: str) -> tuple[np.ndarray, int]:
    """PCM 16/24 bit or 32-bit float WAV -> float64 (frames, channels)."""
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError(f"{path}: keine WAV-Datei")
    pos = 12
    fmt = None
    data = None
    while pos + 8 <= len(raw):
        cid = raw[pos:pos + 4]
        size = int.from_bytes(raw[pos + 4:pos + 8], "little")
        body = raw[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            fmt = body
        elif cid == b"data":
            data = body
        pos += 8 + size + (size & 1)
    if fmt is None or data is None:
        raise ValueError(f"{path}: fmt- oder data-Block fehlt")
    tag = int.from_bytes(fmt[0:2], "little")
    ch = int.from_bytes(fmt[2:4], "little")
    sr = int.from_bytes(fmt[4:8], "little")
    bits = int.from_bytes(fmt[14:16], "little")
    if tag == 1 and bits == 16:
        x = np.frombuffer(data, "<i2").astype(np.float64) / 32768.0
    elif tag == 1 and bits == 24:
        b = np.frombuffer(data, np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / float(1 << 23)
    elif tag == 3 and bits == 32:
        x = np.frombuffer(data, "<f4").astype(np.float64)
    else:
        raise ValueError(f"{path}: WAV-Format {tag}/{bits} Bit wird nicht gelesen")
    return x.reshape(-1, ch), sr


def wav_info(path: str) -> dict:
    """{channels, sample_rate, bits, frames} of a PCM WAV (header only)."""
    with wave.open(path, "rb") as w:
        return {"channels": w.getnchannels(), "sample_rate": w.getframerate(), "bits": w.getsampwidth() * 8,
                "frames": w.getnframes()}


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg fehlt (Ogg Vorbis lesen/schreiben)")
    return exe


def probe(path: str) -> dict:
    """{channels, sample_rate} of a compressed file (ffprobe)."""
    exe = shutil.which("ffprobe")
    if not exe:
        raise SystemExit("ffprobe fehlt")
    r = subprocess.run([exe, "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate,channels",
                        "-of", "csv=p=0", path], capture_output=True, check=True, text=True)
    sr, ch = r.stdout.strip().split(",")[:2]
    return {"sample_rate": int(sr), "channels": int(ch)}


def read_audio(path: str) -> tuple[np.ndarray, int]:
    """Samples as float64 (frames, channels) at the file's own rate."""
    if path.lower().endswith(".wav"):
        return read_wav(path)
    info = probe(path)
    r = subprocess.run([ffmpeg(), "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", str(info["channels"]),
                        "-ar", str(info["sample_rate"]), "-"], capture_output=True, check=True)
    x = np.frombuffer(r.stdout, "<f4").astype(np.float64).reshape(-1, info["channels"])
    return x, info["sample_rate"]


def read_i16(path: str, channels: int) -> np.ndarray:
    """Raw interleaved little-endian int16 -> float64 (frames, channels)."""
    raw = np.fromfile(path, "<i2")
    if len(raw) % channels:
        raise ValueError(f"{path}: {len(raw)} Werte passen nicht zu {channels} Kanälen")
    return raw.astype(np.float64).reshape(-1, channels) / 32768.0


def as_played(x: np.ndarray) -> np.ndarray:
    """Mono -> the same signal on both channels (how the game plays it)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    return np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x


# --- loudness (ITU-R BS.1770-4 / EBU R 128) -----------------------------------------------------------------------

def k_weight(x: np.ndarray, sr: int) -> np.ndarray:
    """K weighting in the frequency domain from the analog prototypes of BS.1770 (valid at any sample rate): a high
    shelf (+4 dB above about 1.7 kHz) and the RLB high-pass (38 Hz)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = len(x)
    if n == 0:
        return x
    f = np.fft.rfftfreq(n, 1.0 / sr)
    s = 1j * f
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = s / f0
    vh = 10.0 ** (gain / 20.0)
    vb = vh ** 0.4996667741545416
    h1 = (vh * k * k + vb * k / q + 1.0) / (k * k + k / q + 1.0)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = s / f0
    h2 = (k * k) / (k * k + k / q + 1.0)
    return np.fft.irfft(np.fft.rfft(x, axis=0) * (h1 * h2)[:, None], n, axis=0)


def _block_power(xk: np.ndarray, sr: int, win_s: float, hop_s: float) -> np.ndarray:
    w = int(round(win_s * sr))
    h = max(int(round(hop_s * sr)), 1)
    p = np.sum(xk * xk, axis=1)
    if len(p) < w:
        return np.array([float(np.mean(p))]) if len(p) else np.array([0.0])
    c = np.concatenate([[0.0], np.cumsum(p)])
    idx = np.arange(0, len(p) - w + 1, h)
    return (c[idx + w] - c[idx]) / w


def _lufs(p) -> np.ndarray:
    return -0.691 + 10.0 * np.log10(np.maximum(p, 1e-14))


def integrated_lufs(x: np.ndarray, sr: int) -> float:
    """Integrated loudness of the file as played (mono on both channels). -70 for silence."""
    xk = k_weight(as_played(x), sr)
    p = _block_power(xk, sr, 0.4, 0.1)
    l = _lufs(p)
    keep = l > -70.0
    if not np.any(keep):
        return -70.0
    rel = float(_lufs(np.mean(p[keep]))) - 10.0
    keep2 = keep & (l > rel)
    return float(_lufs(np.mean(p[keep2]))) if np.any(keep2) else -70.0


def short_term(x: np.ndarray, sr: int, win_s: float = 3.0, hop_s: float = 0.1) -> np.ndarray:
    return _lufs(_block_power(k_weight(as_played(x), sr), sr, win_s, hop_s))


def short_term_max(x: np.ndarray, sr: int) -> float:
    return float(np.max(short_term(x, sr, 3.0, 0.1)))


def momentary_max(x: np.ndarray, sr: int) -> float:
    return float(np.max(short_term(x, sr, 0.4, 0.1)))


def loudness_range(x: np.ndarray, sr: int) -> float:
    st = short_term(x, sr, 3.0, 1.0)
    st = st[st > -70.0]
    if len(st) < 2:
        return 0.0
    rel = float(_lufs(np.mean(10.0 ** ((st + 0.691) / 10.0)))) - 20.0
    st = st[st > rel]
    if len(st) < 2:
        return 0.0
    return float(np.percentile(st, 95) - np.percentile(st, 10))


# --- peaks --------------------------------------------------------------------------------------------------------

_TP_TAPS = 12      # taps per side and phase


def _tp_filter(os_: int) -> np.ndarray:
    m = _TP_TAPS * os_
    n = np.arange(-m, m + 1)
    h = np.sinc(n / os_) * np.kaiser(2 * m + 1, 8.0)
    for p in range(os_):                      # unity gain per phase
        h[p::os_] /= np.sum(h[p::os_])
    return h


def true_peak_db(x: np.ndarray, os_: int = 4) -> float:
    """True peak in dBTP: the largest value of the signal oversampled os_ times."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    if len(x) == 0:
        return SILENCE_DB
    h = _tp_filter(os_)
    pk = float(np.max(np.abs(x)))
    for c in range(x.shape[1]):
        for p in range(os_):
            pk = max(pk, float(np.max(np.abs(np.convolve(x[:, c], h[p::os_])))))
    return float(20.0 * math.log10(max(pk, 10.0 ** (SILENCE_DB / 20.0))))


def sample_peak_db(x: np.ndarray) -> float:
    return db(x)


def dc_offset_db(x: np.ndarray) -> float:
    """Largest mean of a channel in dBFS (-120 = none)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    if len(x) == 0:
        return SILENCE_DB
    return db(np.mean(x, axis=0))


def clipped_runs(x: np.ndarray, level: float = 0.999, run: int = 3) -> int:
    """Number of runs of at least `run` consecutive samples at or above `level` (a clipped peak)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    total = 0
    for c in range(x.shape[1]):
        hot = (np.abs(x[:, c]) >= level).astype(np.int8)
        if not hot.any():
            continue
        edges = np.diff(np.concatenate([[0], hot, [0]]))
        starts = np.flatnonzero(edges == 1)
        ends = np.flatnonzero(edges == -1)
        total += int(np.sum((ends - starts) >= run))
    return total


# --- loops --------------------------------------------------------------------------------------------------------

def loop_seam(x: np.ndarray, begin: int, end: int, near_s: float = 0.1, sr: int = 44100) -> dict:
    """The loop [begin, end): the step from the last frame back to the first, and its second difference (a kink),
    against the largest values the signal itself has – within near_s on both sides of the seam ("ratio",
    "kink_ratio") and anywhere in the loop ("loop_ratio", "loop_kink_ratio"). A seam is a click when it is rougher
    than its surroundings and rougher than everything else in the loop (a downbeat on the loop point is as sharp as
    the other beats, not sharper)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = end - begin
    if n < 8 or begin < 0 or end > len(x):
        return {"step": 0.0, "ratio": 0.0, "kink_ratio": 0.0, "loop_ratio": 0.0, "loop_kink_ratio": 0.0}
    w = max(min(int(near_s * sr), n // 2), 4)
    body = x[begin:end]
    ring = np.concatenate([body[-w:], body[:w]])             # ... last frames | first frames ...
    d1 = np.abs(np.diff(ring, axis=0))
    d2 = np.abs(np.diff(ring, 2, axis=0))
    step = float(np.max(d1[w - 1]))
    kink = float(max(np.max(d2[w - 2]), np.max(d2[w - 1])))
    near1 = float(np.max(np.delete(d1, w - 1, axis=0)))
    near2 = float(np.max(np.delete(d2, [w - 2, w - 1], axis=0)))
    all1 = float(np.max(np.abs(np.diff(body, axis=0))))
    all2 = float(np.max(np.abs(np.diff(body, 2, axis=0))))
    floor = 2.0 / 32768.0                                    # below two quantisation steps nothing is a click
    return {"step": step, "ratio": step / max(near1, floor), "kink_ratio": kink / max(near2, floor),
            "loop_ratio": step / max(all1, floor), "loop_kink_ratio": kink / max(all2, floor)}


def measure(x: np.ndarray, sr: int) -> dict:
    """The standard set of measurements of one file."""
    return {
        "lufs": round(integrated_lufs(x, sr), 2),
        "lra": round(loudness_range(x, sr), 2),
        "short_term_max": round(short_term_max(x, sr), 2),
        "momentary_max": round(momentary_max(x, sr), 2),
        "true_peak_db": round(true_peak_db(x), 2),
        "sample_peak_db": round(sample_peak_db(x), 2),
        "dc_db": round(dc_offset_db(x), 1),
        "clipped_runs": clipped_runs(x),
    }
