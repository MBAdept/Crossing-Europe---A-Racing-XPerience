#!/usr/bin/env python3
"""Titelmelodie - offline synthesis of the title theme (synthwave rock / outrun, 128 bpm, E minor, 3:22.5).

Contract: docs/ui.md, section "Audio" -> "Titelmelodie". Writes assets/audio/music/title_theme.ogg (Vorbis q5,
44.1 kHz stereo) and its import settings (loop = true, loop_offset = 15.0 s): the 8-bar intro plays once, the
100-bar body after it loops. The body's last two bars (turnaround D - B with stabs and a tom fill) are the same
events as the intro's last two bars, so what sounds into the loop start (reverb and delay tails, notes ringing
over the bar line, compressor and limiter state) is the same on every pass: the loop seam is part of the music.
The intro is 15.0 s exactly (a whole number of samples), so Godot's seek to loop_offset is sample-exact.

Arrangement (1 bar = 1.875 s; SECTIONS): intro (bell melody, pad, filtered arpeggio, riser, turnaround) - theme
(the hook on lead guitar) - verse 1 - pre-chorus - chorus (hook on synth lead) - verse 2 - pre-chorus - chorus 2
(+ harmony) - bridge (breakdown, FM bells) - guitar solo - final chorus a whole tone up (F# minor, hook with
harmony and octave guitar) - outro hit and turnaround back to the theme.

Instruments (all synthesised here, numpy only):
  drums    kick (pitch-swept sine, beater click, saturation), snare with 80s gated room, clap, three toms (gated),
           hi-hats (808-style metal: six square waves + noise), crash, reverse crash, risers, impacts
  bass     picked bass (plucked-string model with inharmonicity) doubled by a synth bass (additive saw through a
           4-pole ladder filter with envelope)
  guitars  rhythm guitars: power chords from plucked-string models (strum, pick noise, palm mutes), double-tracked
           (two independent takes panned left/right) through an amp model: pre-EQ, two asymmetric tanh stages at
           4x oversampling, tone stack and a 4x12 cabinet (minimum-phase FIR); lead guitar with bends, vibrato,
           slides through a hotter amp, delay and plate
  synths   pad (detuned saw wavetables, chorus), arpeggiator (plucky ladder saw, ping-pong delay), brass stabs,
           FM bells, synth lead (two detuned saws + sub square, portamento, delayed vibrato) and harmony voice
Mix: per-track EQ (minimum-phase FIRs from analog prototypes), gain staging by K-weighted loudness targets
(MIX), sidechain ducking from the kick, sends to plate and hall reverbs (synthetic stereo impulse responses with
frequency-dependent decay) and a dotted-eighth ping-pong delay, parallel drum compression, master EQ, glue
compressor, low end in mono, lookahead true-peak limiter; integrated loudness -14 LUFS (ITU-R BS.1770-4 with
gating), true peak <= -1 dBTP. Everything is seeded (crc32 of names), the Vorbis encode runs bit-exact.

Usage (python3 + numpy, ffmpeg for the Vorbis encode; deterministic, a few minutes):
  python3 tools/audio/music_synth.py                  # render -> assets/audio/music/title_theme.ogg (+ .import)
  python3 tools/audio/music_synth.py --wav DIR        # also keep master (float WAV) and stems for analysis
  python3 tools/audio/music_synth.py --bars 8:16      # render only these bars (sketch, nothing is written)
  python3 tools/audio/music_synth.py --info           # section map, no rendering
Checks, spectrogram, loudness over time, loop seam and previews: tools/audio/music_preview.py.
"""
from __future__ import annotations

import argparse
import functools
import json
import math
import os
import shutil
import subprocess
import sys
import time
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
OUT_NAME = "title_theme.ogg"

SR = 44100
BPM = 128.0
BEAT = 60.0 / BPM               # 0.46875 s
BAR = 4.0 * BEAT                # 1.875 s
STEP = BAR / 16.0               # sixteenth note
TARGET_LUFS = -14.0
CEILING_DBTP = -1.0
OGG_QUALITY = 5                 # libvorbis -q:a (~160 kbit/s)
TAIL_S = 2.5                    # rendered after the last bar (reverb tails of the seam check)

# ------------------------------------------------------------------------------------------------
# Arrangement: id, label (German, docs and overview), bars, chords (one per bar), transposition of the hook
# ------------------------------------------------------------------------------------------------

SECTIONS = [
    ("intro", "Intro", 8, "Em Em C C Am Am D B", 0),
    ("theme", "Thema", 8, "Em C G D Em C G D", 0),
    ("verse1", "Strophe 1", 16, "Em Em C D Em Em C D Em Em C D Em Em C D", 0),
    ("pre1", "Pre-Chorus 1", 8, "Am Am C C D D B B", 0),
    ("chorus1", "Refrain 1", 8, "Em C G D Em C G D", 0),
    ("verse2", "Strophe 2", 8, "Em Em C D Em Em C D", 0),
    ("pre2", "Pre-Chorus 2", 8, "Am Am C C D D B B", 0),
    ("chorus2", "Refrain 2", 8, "Em C G D Em C G D", 0),
    ("bridge", "Bridge", 8, "C G D Em C G D D", 0),
    ("solo", "Gitarrensolo", 8, "Em C G D Em C D E", 0),
    ("final", "Schlussrefrain (+1 Ton)", 16, "F#m D A E F#m D A E F#m D A E F#m D A E", 2),
    ("outro", "Ausklang", 4, "F#m F#m D B", 0),
]
INTRO_BARS = SECTIONS[0][2]
BODY_BARS = sum(s[2] for s in SECTIONS[1:])
EXTRA_BARS = 4                  # rendered after the body: the loop's continuation (theme bars 1-4), for the seam
LOOP_OFFSET_S = INTRO_BARS * BAR
N_FILE = int(round((INTRO_BARS + BODY_BARS) * BAR * SR))
N_LOOP_START = int(round(LOOP_OFFSET_S * SR))
N_RENDER = int(round((INTRO_BARS + BODY_BARS + EXTRA_BARS) * BAR * SR + TAIL_S * SR))
TURNAROUND = {"intro": 6, "outro": 2}   # first bar of the shared two-bar turnaround in these sections

CHORDS = {"Em": (4, 3), "C": (0, 4), "G": (7, 4), "D": (2, 4), "Am": (9, 3), "B": (11, 4), "E": (4, 4),
          "F#m": (6, 3), "A": (9, 4)}          # root pitch class, third (3 minor, 4 major)
NOTE_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
           "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


class Bar:
    """One bar of the render timeline. key = seed key of its patterns: the turnaround bars of intro and outro
    share ("turn", n), the bars rendered after the body share the theme's keys - identical events."""
    __slots__ = ("i", "t", "sec", "label", "j", "n", "chord", "nxt", "key", "tr")

    def __repr__(self) -> str:
        return f"Bar({self.i} {self.sec}[{self.j}] {self.chord})"


def timeline(extra: bool = True) -> list:
    secs = list(SECTIONS)
    if extra:
        th = next(s for s in SECTIONS if s[0] == "theme")
        secs.append(("theme", th[1], EXTRA_BARS, " ".join(th[3].split()[:EXTRA_BARS]), th[4]))
    bars = []
    for sid, label, n, chords, tr in secs:
        ch = chords.split()
        assert len(ch) == n, (sid, len(ch), n)
        for j in range(n):
            b = Bar()
            b.i, b.t, b.sec, b.label, b.j, b.n, b.chord, b.tr = len(bars), len(bars) * BAR, sid, label, j, n, ch[j], tr
            turn = TURNAROUND.get(sid)
            b.key = ("turn", j - turn) if turn is not None and j >= turn else (sid, j)
            bars.append(b)
    for a, b in zip(bars, bars[1:]):
        a.nxt = b.chord
    bars[-1].nxt = "Em"
    return bars


def section_map() -> list:
    out, bar = [], 0
    for sid, label, n, chords, tr in SECTIONS:
        key = "Fis-Moll" if tr else ("Fis-Moll → E-Moll" if sid == "outro" else "E-Moll")
        out.append({"id": sid, "label": label, "bar": bar + 1, "bars": n, "start_s": round(bar * BAR, 3),
                    "end_s": round((bar + n) * BAR, 3), "chords": chords, "key": key})
        bar += n
    return out


# ------------------------------------------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------------------------------------------

def seed_of(*parts) -> int:
    return zlib.crc32("|".join(str(p) for p in parts).encode()) & 0x7FFFFFFF


def rng_of(*parts) -> np.random.Generator:
    return np.random.default_rng(seed_of(*parts))


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, float) - 69.0) / 12.0)


def note_midi(name: str) -> int:
    pc = name[:-1]
    return 12 * (int(name[-1]) + 1) + NOTE_PC[pc]


def db(x: float) -> float:
    return 20.0 * math.log10(max(float(x), 1e-12))


def undb(d: float) -> float:
    return 10.0 ** (d / 20.0)


def fft_size(n: int) -> int:
    """Smallest 2^a * 3^b >= n (fast for numpy's pocketfft)."""
    best = 1 << max(0, (n - 1).bit_length())
    p3 = 1
    while p3 < best:
        p2 = p3
        while p2 < n:
            p2 *= 2
        best = min(best, p2)
        p3 *= 3
    return best


def frozen(x: np.ndarray) -> np.ndarray:
    x.flags.writeable = False
    return x


def fade_tail(x: np.ndarray, sec: float) -> np.ndarray:
    m = min(len(x), int(sec * SR))
    if m > 1:
        w = 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, m))
        x[-m:] *= w if x.ndim == 1 else w[:, None]
    return x


def pan_gains(pan: float) -> tuple:
    """Equal-power pan law, unity at the centre (pan -1 = left .. +1 = right)."""
    a = (np.clip(pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return math.cos(a) * math.sqrt(2.0), math.sin(a) * math.sqrt(2.0)


# ------------------------------------------------------------------------------------------------
# Filters: analog prototypes -> magnitude -> minimum-phase FIR, FFT convolution, oversampling
# ------------------------------------------------------------------------------------------------

def convolve(x: np.ndarray, h: np.ndarray, block: int = 1 << 17) -> np.ndarray:
    """Linear convolution along axis 0 (overlap-add), truncated to len(x). x (n,) or (n, c); h (m,) or (m, c)
    (per channel; a mono x with a stereo h gives a stereo result)."""
    x = np.asarray(x, np.float64)
    h = np.asarray(h, np.float64)
    if x.ndim == 1 and h.ndim == 2:
        x = np.repeat(x[:, None], h.shape[1], axis=1)
    n, m = x.shape[0], h.shape[0]
    nfft = fft_size(block + m - 1)
    H = np.fft.rfft(h, nfft, axis=0)
    if x.ndim == 2 and H.ndim == 1:
        H = H[:, None]
    out = np.zeros(x.shape)
    for s in range(0, n, block):
        seg = x[s:s + block]
        if not np.any(seg):
            continue
        y = np.fft.irfft(np.fft.rfft(seg, nfft, axis=0) * H, nfft, axis=0)
        e = min(n, s + seg.shape[0] + m - 1)
        out[s:e] += y[:e - s]
    return out


def _s(f, fc):
    return 1j * np.asarray(f, float) / fc


def eq_response(f, bands) -> np.ndarray:
    """Complex response of a chain of analog sections: ("hp"|"lp", fc, q), ("hp1"|"lp1", fc), ("peak", f0, dB, q),
    ("ls"|"hs", f0, dB[, q]), ("ladder", fc, res)."""
    H = np.ones(len(f), complex)
    for b in bands:
        kind = b[0]
        if kind in ("hp", "lp"):
            q = b[2] if len(b) > 2 else 0.7071
            s = _s(f, b[1])
            d = s * s + s / q + 1.0
            H *= (s * s / d) if kind == "hp" else (1.0 / d)
        elif kind == "hp1":
            s = _s(f, b[1])
            H *= s / (1.0 + s)
        elif kind == "lp1":
            H *= 1.0 / (1.0 + _s(f, b[1]))
        elif kind == "peak":
            A = 10.0 ** (b[2] / 40.0)
            s = _s(f, b[1])
            H *= (s * s + s * A / b[3] + 1.0) / (s * s + s / (A * b[3]) + 1.0)
        elif kind in ("ls", "hs"):
            A = 10.0 ** (b[2] / 40.0)
            q = b[3] if len(b) > 3 else 0.7071
            s = _s(f, b[1])
            r = math.sqrt(A) / q
            if kind == "ls":
                H *= A * (s * s + r * s + A) / (A * s * s + r * s + 1.0)
            else:
                H *= A * (A * s * s + r * s + 1.0) / (s * s + r * s + A)
        elif kind == "ladder":
            H *= ladder(f, b[1], b[2])
        else:
            raise ValueError(kind)
    return H


def ladder(f, fc, res):
    """4-pole transistor ladder low-pass (Moog), resonance 0..1 (self-oscillation at 1), unity at DC."""
    s = _s(f, fc)
    k = 4.0 * res
    return (1.0 + k) / ((1.0 + s) ** 4 + k)


def minphase(mag: np.ndarray, nfft: int) -> np.ndarray:
    """Minimum-phase impulse response with the given magnitude (rfft grid of nfft), real cepstrum method."""
    c = np.fft.irfft(np.log(np.maximum(mag, 1e-5)), nfft)
    c[1:nfft // 2] *= 2.0
    c[nfft // 2 + 1:] = 0.0
    return np.fft.irfft(np.exp(np.fft.rfft(c, nfft)), nfft)


@functools.lru_cache(maxsize=None)
def _eq_fir(bands: tuple, nfft: int, length: int, sr: int) -> np.ndarray:
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    h = minphase(np.abs(eq_response(f, bands)), nfft)[:length].copy()
    m = length // 4
    h[-m:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    return frozen(h)


def eq_fir(bands, nfft: int = 16384, length: int = 8192, sr: int = SR) -> np.ndarray:
    return _eq_fir(tuple(tuple(b) for b in bands), nfft, length, sr)


def apply_eq(x: np.ndarray, bands, length: int = 8192) -> np.ndarray:
    if not bands:
        return x
    return convolve(x, eq_fir(bands, max(16384, 2 * length), length))


def spectral(x: np.ndarray, gain_fn) -> np.ndarray:
    """Zero-phase filter of a short signal in the frequency domain: gain_fn(freqs) -> gain."""
    n = fft_size(len(x) + 2048)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x, n, axis=0) * (gain_fn(f) if x.ndim == 1 else gain_fn(f)[:, None]), n,
                        axis=0)[:len(x)]


def band_noise(rng, n: int, lo: float, hi: float, slope_db: float = 0.0) -> np.ndarray:
    """Gaussian noise band-limited to [lo, hi] (2nd-order edges), tilt in dB/octave, unit RMS."""
    x = rng.standard_normal(n)
    nn = fft_size(n)
    f = np.maximum(np.fft.rfftfreq(nn, 1.0 / SR), 1.0)
    g = np.abs(eq_response(f, [("hp", lo, 0.7071), ("lp", hi, 0.7071)])) * (f / 1000.0) ** (slope_db / 6.02)
    y = np.fft.irfft(np.fft.rfft(x, nn) * g, nn)[:n]
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


OS = 4                          # oversampling of the guitar amps and the true-peak detector


@functools.lru_cache(maxsize=None)
def os_kernel(factor: int = OS, half_taps: int = 32) -> np.ndarray:
    """Linear-phase Kaiser low-pass at the high rate (cut-off 20.5 kHz of the base rate), unity DC gain."""
    n = 2 * factor * half_taps + 1
    m = np.arange(n) - (n - 1) / 2
    fc = 20500.0 / (SR * factor)
    h = 2.0 * fc * np.sinc(2.0 * fc * m) * np.kaiser(n, 9.0)
    return frozen(h / h.sum())


def upsample(x: np.ndarray, factor: int = OS) -> np.ndarray:
    """Band-limited interpolation by `factor` (polyphase FIR via FFT); output aligned with the input."""
    h = os_kernel(factor)
    d = (len(h) - 1) // 2
    out = np.zeros(len(x) * factor)
    pad = np.concatenate([x, np.zeros(len(h) // factor + 2)])
    for p in range(factor):
        sub = h[p::factor] * factor
        y = convolve(pad, sub)
        out[p::factor] = y[:len(x)]
    # polyphase output phase p at index i*factor + p corresponds to the high-rate filter output at i*factor + p;
    # compensate the filter delay d (high-rate samples)
    return np.concatenate([out[d:], np.zeros(d)])


def downsample(u: np.ndarray, factor: int = OS) -> np.ndarray:
    h = os_kernel(factor)
    d = (len(h) - 1) // 2
    y = convolve(np.concatenate([u, np.zeros(d)]), h)
    return y[d::factor][:len(u) // factor]


# ------------------------------------------------------------------------------------------------
# Loudness (ITU-R BS.1770-4) and true peak
# ------------------------------------------------------------------------------------------------

def _kw_biquads(sr: float):
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / sr)
    Vh = 10.0 ** (G / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2.0 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / sr)
    d = 1.0 + K / Q + K * K
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2.0 * (K * K - 1.0) / d, (1.0 - K / Q + K * K) / d]
    return (b1, a1), (b2, a2)


def k_weight(x: np.ndarray) -> np.ndarray:
    """K-weighted signal (both BS.1770 biquads, exact response applied in the frequency domain)."""
    n = fft_size(len(x) + 8192)
    w = 2.0 * np.pi * np.fft.rfftfreq(n)
    z = np.exp(-1j * w)
    H = np.ones(len(w), complex)
    for b, a in _kw_biquads(SR):
        H *= (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)
    X = np.fft.rfft(x, n, axis=0)
    return np.fft.irfft(X * (H if x.ndim == 1 else H[:, None]), n, axis=0)[:len(x)]


def block_power(xk: np.ndarray, win_s: float, hop_s: float) -> tuple:
    """Mean square per window (sum over channels) of a K-weighted signal; returns (centre times, power)."""
    p = xk * xk if xk.ndim == 1 else np.sum(xk * xk, axis=1)
    c = np.concatenate([[0.0], np.cumsum(p)])
    w, h = int(round(win_s * SR)), int(round(hop_s * SR))
    if len(p) < w:
        return np.array([len(p) / 2 / SR]), np.array([c[-1] / max(len(p), 1)])
    starts = np.arange(0, len(p) - w + 1, h)
    return (starts + w / 2) / SR, (c[starts + w] - c[starts]) / w


def integrated_lufs(x: np.ndarray, xk: np.ndarray | None = None) -> float:
    xk = k_weight(x) if xk is None else xk
    _, z = block_power(xk, 0.4, 0.1)
    lk = -0.691 + 10.0 * np.log10(np.maximum(z, 1e-20))
    z1 = z[lk > -70.0]
    if len(z1) == 0:
        return -200.0
    rel = -0.691 + 10.0 * math.log10(float(np.mean(z1))) - 10.0
    z2 = z[lk > max(rel, -70.0)]
    return -0.691 + 10.0 * math.log10(float(np.mean(z2)))


def loudness_curve(x: np.ndarray, win_s: float = 3.0, hop_s: float = 0.25, xk=None) -> tuple:
    """Short-term (3 s) or momentary (0.4 s) loudness over time: (times, LUFS)."""
    xk = k_weight(x) if xk is None else xk
    t, z = block_power(xk, win_s, hop_s)
    return t, -0.691 + 10.0 * np.log10(np.maximum(z, 1e-20))


def true_peak_env(x: np.ndarray, chunk: int = 1 << 20) -> np.ndarray:
    """Per-sample maximum of |x| over the 4x oversampled signal and all channels (BS.1770 true peak)."""
    xs = x if x.ndim == 2 else x[:, None]
    out = np.zeros(len(xs))
    margin = 256
    for s in range(0, len(xs), chunk):
        a, b = max(0, s - margin), min(len(xs), s + chunk + margin)
        m = np.zeros(b - a)
        for c in range(xs.shape[1]):
            u = upsample(xs[a:b, c])
            m = np.maximum(m, np.abs(u).reshape(-1, OS).max(axis=1))
        out[s:min(len(xs), s + chunk)] = m[s - a:s - a + min(chunk, len(xs) - s)]
    return out


def true_peak_db(x: np.ndarray) -> float:
    return db(float(np.max(true_peak_env(x))))


# ------------------------------------------------------------------------------------------------
# Dynamics and effects
# ------------------------------------------------------------------------------------------------

def compressor_gain(sc: np.ndarray, thr_db: float, ratio: float, attack: float, release: float,
                    knee_db: float = 6.0, block: int = 63) -> np.ndarray:
    """Feed-forward compressor (RMS detector per block, soft knee, attack/release on the gain reduction);
    returns the per-sample linear gain. sc may be stereo (linked). The block (63 samples) divides the intro and the
    loop length, so the detector grid is the same on every pass of the loop (identical gain at the seam)."""
    p = sc * sc if sc.ndim == 1 else np.mean(sc * sc, axis=1)
    n = len(p)
    nb = (n + block - 1) // block
    pp = np.zeros(nb * block)
    pp[:n] = p
    lvl = 10.0 * np.log10(np.maximum(pp.reshape(nb, block).mean(axis=1), 1e-14))
    over = lvl - thr_db
    gr = np.where(over <= -knee_db / 2, 0.0,
                  np.where(over >= knee_db / 2, over * (1.0 / ratio - 1.0),
                           (1.0 / ratio - 1.0) * (over + knee_db / 2) ** 2 / (2.0 * knee_db)))
    a_att = math.exp(-block / (attack * SR))
    a_rel = math.exp(-block / (release * SR))
    out = np.empty(nb)
    g = 0.0
    for i, v in enumerate(gr.tolist()):
        g = (a_att * g + (1.0 - a_att) * v) if v < g else (a_rel * g + (1.0 - a_rel) * v)
        out[i] = g
    centres = (np.arange(nb) + 0.5) * block
    return 10.0 ** (np.interp(np.arange(n), centres, out) / 20.0)


def _running_min(x: np.ndarray, w: int) -> np.ndarray:
    """min(x[i - w .. i + w]) for every i (van Herk / Gil-Werman, vectorised)."""
    k = 2 * w + 1
    n = len(x)
    pad = np.concatenate([np.full(w, np.inf), x, np.full(w + k, np.inf)])
    nb = (len(pad) + k - 1) // k
    pad = np.concatenate([pad, np.full(nb * k - len(pad), np.inf)]).reshape(nb, k)
    pre = np.minimum.accumulate(pad, axis=1).ravel()
    suf = np.minimum.accumulate(pad[:, ::-1], axis=1)[:, ::-1].ravel()
    i = np.arange(n)
    return np.minimum(suf[i], pre[i + k - 1])


def limiter(x: np.ndarray, ceiling_db: float, lookahead_s: float = 0.0015, release_db_s: float = 45.0) -> tuple:
    """Lookahead true-peak limiter: needed gain from the 4x oversampled peaks, running minimum over +-lookahead,
    moving average over the same window (attack ramp, never above the needed gain), release linear in dB.
    Returns (output, gain reduction in dB per sample)."""
    env = true_peak_env(x)
    need = np.minimum(0.0, ceiling_db - 20.0 * np.log10(np.maximum(env, 1e-9)))
    w = max(1, int(lookahead_s * SR))
    held = _running_min(need, w)
    c = np.concatenate([[0.0], np.cumsum(np.concatenate([np.zeros(w), held, np.zeros(w)]))])
    avg = (c[2 * w + 1:] - c[:-(2 * w + 1)]) / (2 * w + 1)
    avg = np.minimum(avg[:len(x)], held)
    r = release_db_s / SR
    idx = np.arange(len(x))
    g = r * idx + np.minimum.accumulate(avg - r * idx)
    g = np.minimum(g, 0.0)
    y = x * (10.0 ** (g / 20.0))[:, None]
    return y, g


def duck_env(times, n: int, depth: float, attack: float = 0.004, hold: float = 0.012,
             release: float = 0.15) -> np.ndarray:
    """Sidechain gain from kick times: 1 - depth * envelope (attack ramp, hold, exponential release)."""
    imp = np.zeros(n)
    for t in times:
        i = int(round(t * SR))
        if 0 <= i < n:
            imp[i] = 1.0
    m = int((attack + hold + 6.0 * release) * SR)
    tt = np.arange(m) / SR
    shape = np.where(tt < attack, tt / attack, np.where(tt < attack + hold, 1.0,
                                                        np.exp(-(tt - attack - hold) / release)))
    env = np.minimum(convolve(imp, shape), 1.0)
    return 1.0 - depth * env


def chorus(x: np.ndarray, base_ms: float = 9.0, depth_ms: float = 2.2, mix: float = 0.5,
           cycles_per_bar: float = 1.0) -> np.ndarray:
    """Stereo chorus: modulated delay per channel (LFO in quadrature, synced to the bar so that it is identical at
    the loop start and the loop end)."""
    n = len(x)
    xs = x if x.ndim == 2 else np.repeat(x[:, None], 2, axis=1)
    t = np.arange(n) / SR
    out = np.empty((n, 2))
    idx = np.arange(n, dtype=np.float64)
    for ch, ph in ((0, 0.0), (1, np.pi / 2)):
        d = (base_ms + depth_ms * np.sin(2.0 * np.pi * cycles_per_bar / BAR * t + ph)) * SR / 1000.0
        wet = np.interp(idx - d, idx, xs[:, ch], left=0.0)
        out[:, ch] = xs[:, ch] * (1.0 - mix) + wet * mix
    return out


@functools.lru_cache(maxsize=None)
def reverb_ir(name: str, length: float, predelay: float, rt_lo: float, rt_hi: float, damp_hz: float,
              er: float = 0.25) -> np.ndarray:
    """Synthetic stereo reverb impulse response: decorrelated noise per channel split into octave bands, each
    with its own exponential decay (RT60 from rt_lo at 125 Hz to rt_hi at 8 kHz, plus air damping above damp_hz),
    a short density build-up, sparse early reflections; unit energy per channel."""
    rng = rng_of("reverb", name)
    n = int(length * SR)
    t = np.arange(n) / SR
    nf = fft_size(n)
    f = np.maximum(np.fft.rfftfreq(nf, 1.0 / SR), 1.0)
    centres = 125.0 * 2.0 ** np.arange(8)                 # 125 Hz .. 16 kHz
    lf = np.log2(f / 125.0)
    weights = []
    for i, _ in enumerate(centres):
        w = np.clip(1.0 - np.abs(lf - i), 0.0, 1.0)
        if i == 0:
            w = np.where(lf < 0, 1.0, w)
        if i == len(centres) - 1:
            w = np.where(lf > i, 1.0, w)
        weights.append(np.sin(w * np.pi / 2) ** 2)
    tot = np.sum(weights, axis=0)
    rts = np.interp(np.arange(len(centres)), [0, 6], [rt_lo, rt_hi])
    damp = 1.0 / np.sqrt(1.0 + (f / damp_hz) ** 4)
    out = np.zeros((n, 2))
    pd = int(predelay * SR)
    for ch in range(2):
        spec = np.fft.rfft(rng.standard_normal(n), nf) * damp
        y = np.zeros(n)
        for wgt, rt in zip(weights, rts):
            y += np.fft.irfft(spec * wgt / tot, nf)[:n] * np.exp(-6.9078 * t / rt)
        y *= 1.0 - np.exp(-t / 0.012)
        for _ in range(7):                                  # early reflections (both channels differ)
            d = int(rng.uniform(0.006, 0.055) * SR)
            g = er * rng.uniform(0.4, 1.0) * (1.0 if rng.random() < 0.5 else -1.0)
            y[d:d + 64] += g * np.hanning(64) * np.sqrt(np.sum(y * y) / 2000.0)
        y = np.concatenate([np.zeros(pd), y])[:n]
        out[:, ch] = y / np.sqrt(np.sum(y * y))
    return frozen(out)


@functools.lru_cache(maxsize=None)
def pingpong_ir(delay_s: float, feedback: float, taps: int, lp: float, hp: float) -> np.ndarray:
    """Ping-pong delay as impulse response: echo k (left, right, left, ...) at k * delay with feedback^(k-1),
    every echo filtered once more (fractional delays exact in the frequency domain)."""
    n = int(delay_s * (taps + 1) * SR) + 2048
    nf = fft_size(n)
    f = np.fft.rfftfreq(nf, 1.0 / SR)
    F = np.abs(eq_response(f, [("lp", lp, 0.6), ("hp1", hp)]))
    w = 2.0 * np.pi * f
    HL = np.zeros(len(f), complex)
    HR = np.zeros(len(f), complex)
    for k in range(1, taps + 1):
        G = feedback ** (k - 1) * F ** k * np.exp(-1j * w * k * delay_s)
        if k % 2:
            HL += G
        else:
            HR += G
    return frozen(np.stack([np.fft.irfft(HL, nf)[:n], np.fft.irfft(HR, nf)[:n]], axis=1))


# ------------------------------------------------------------------------------------------------
# Oscillators: mip-mapped wavetables and additive partials
# ------------------------------------------------------------------------------------------------

TABLE = 8192
HARMS = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384]


@functools.lru_cache(maxsize=None)
def wavetables(kind: str) -> list:
    out = []
    for H in HARMS:
        spec = np.zeros(TABLE // 2 + 1, complex)
        k = np.arange(1, H + 1)
        if kind == "saw":
            a = 1.0 / k
        elif kind == "square":
            a = np.where(k % 2 == 1, 1.0 / k, 0.0)
        elif kind == "tri":
            a = np.where(k % 2 == 1, (-1.0) ** ((k - 1) // 2) / (k * k), 0.0)
        else:
            raise ValueError(kind)
        spec[1:H + 1] = -1j * a * TABLE / 2.0
        tab = np.fft.irfft(spec, TABLE)
        out.append((H, np.concatenate([tab, tab[:1]])))
    return out


def osc(kind: str, freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Band-limited oscillator; freq scalar or per-sample array (Hz)."""
    fa = np.broadcast_to(np.asarray(freq, float), (n,))
    fmax = float(np.max(fa))
    hmax = max(1, int(0.46 * SR / max(fmax, 1.0)))
    tab = None
    for H, tb in wavetables(kind):
        if H <= hmax:
            tab = tb
    ph = phase0 + np.cumsum(fa) / SR
    pos = (ph - np.floor(ph)) * TABLE
    i0 = pos.astype(np.int64)
    fr = pos - i0
    return tab[i0] * (1.0 - fr) + tab[i0 + 1] * fr


def additive(freqs: np.ndarray, amps, n: int, phases: np.ndarray, decays=None, chunk: int = 8192,
             freq_mod=None, coarse: int = 32) -> np.ndarray:
    """Sum of partials: amps (K,) or callable(t (m,)) -> complex/real (K, m) gains (evaluated every `coarse`
    samples and interpolated linearly - filter envelopes are smooth); decays (K,) time constants (s) or None;
    freq_mod (n,) relative frequency factor (vibrato/bends) or None."""
    y = np.zeros(n)
    fk = np.asarray(freqs, float)[:, None]
    ph = np.asarray(phases, float)[:, None]
    if freq_mod is not None:
        theta = 2.0 * np.pi * np.cumsum(freq_mod) / SR          # phase of a 1 Hz partial
    if callable(amps):
        tc = np.arange(0, n + coarse, coarse) / SR
        ac = amps(tc)                                            # (K, m) on the coarse grid
    for s in range(0, n, chunk):
        e = min(n, s + chunk)
        idx = np.arange(s, e)
        t = idx / SR
        arg = (fk * theta[None, s:e] if freq_mod is not None else 2.0 * np.pi * fk * t[None, :]) + ph
        if callable(amps):
            q = idx // coarse
            fr = (idx % coarse) / coarse
            a = ac[:, q] * (1.0 - fr) + ac[:, q + 1] * fr
        else:
            a = np.asarray(amps, float)[:, None]
        if decays is not None:
            a = a * np.exp(-t[None, :] / np.asarray(decays, float)[:, None])
        if np.iscomplexobj(a):
            y[s:e] = np.sum(a.real * np.cos(arg) - a.imag * np.sin(arg), axis=0)
        else:
            y[s:e] = np.sum(a * np.sin(arg), axis=0)
    return y


def gate_env(gate: np.ndarray, attack: float, release: float) -> np.ndarray:
    """One-pole attack/release follower of a 0/1 gate, computed per constant segment (vectorised)."""
    n = len(gate)
    out = np.empty(n)
    edges = np.flatnonzero(np.diff(gate)) + 1
    starts = np.concatenate([[0], edges])
    ends = np.concatenate([edges, [n]])
    g = 0.0
    for a, b in zip(starts, ends):
        tt = np.arange(1, b - a + 1) / SR
        if gate[a] > 0.5:
            seg = 1.0 - (1.0 - g) * np.exp(-tt / attack)
        else:
            seg = g * np.exp(-tt / release)
        out[a:b] = seg
        g = float(seg[-1])
    return out


# ------------------------------------------------------------------------------------------------
# Drums
# ------------------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=None)
def kick(var: int) -> np.ndarray:
    rng = rng_of("kick", var)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 60.0 + 70.0 * np.exp(-t / 0.02) + 220.0 * np.exp(-t / 0.0035)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR + 0.1 * rng.uniform(-1, 1))
    body *= (0.78 * np.exp(-t / 0.2) + 0.22 * np.exp(-t / 0.045)) * (1.0 - np.exp(-t / 0.0006))
    click = band_noise(rng, n, 1800.0, 9000.0) * np.exp(-t / 0.0016) * 0.16
    beater = np.sin(2.0 * np.pi * 3300.0 * t) * np.exp(-t / 0.002) * 0.12
    x = np.tanh(1.7 * (body + click + beater)) / np.tanh(1.7)
    return frozen(fade_tail(x, 0.06))


def _gated_room(rng, dry: np.ndarray, open_s: float, level: float, lo: float = 280.0, hi: float = 7000.0,
                decay: float = 0.3) -> np.ndarray:
    """80s gated reverb: dense room response of the hit, cut by a gate after open_s (stereo, decorrelated)."""
    n = len(dry)
    m = int(0.6 * SR)
    tt = np.arange(m) / SR
    t = np.arange(n) / SR
    gate = np.where(t < open_s, 1.0 - 0.25 * t / open_s, 0.75 * np.exp(-(t - open_s) / 0.012))
    out = np.zeros((n, 2))
    for ch in range(2):
        ir = band_noise(rng, m, lo, hi, -1.5) * np.exp(-tt / decay) * (1.0 - np.exp(-tt / 0.005))
        out[:, ch] = convolve(dry, ir)[:n] * gate
    r_dry = np.sqrt(np.mean(dry[: int(0.08 * SR)] ** 2)) + 1e-9
    r_wet = np.sqrt(np.mean(out[: int(open_s * SR)] ** 2)) + 1e-9
    return out * (level * r_dry / r_wet)


@functools.lru_cache(maxsize=None)
def snare(var: int) -> np.ndarray:
    rng = rng_of("snare", var)
    n = int(0.62 * SR)
    t = np.arange(n) / SR
    f1 = 186.0 * (1.0 + 0.16 * np.exp(-t / 0.012))
    f2 = 332.0 * (1.0 + 0.08 * np.exp(-t / 0.01))
    body = (0.9 * np.sin(2.0 * np.pi * np.cumsum(f1) / SR) * np.exp(-t / 0.07)
            + 0.45 * np.sin(2.0 * np.pi * np.cumsum(f2) / SR + 1.0) * np.exp(-t / 0.04))
    wires = band_noise(rng, n, 1700.0, 10000.0, -1.0) * np.exp(-t / 0.115) * 0.6
    crack = band_noise(rng, n, 2800.0, 12000.0) * np.exp(-t / 0.005) * 0.55
    dry = (body + wires + crack) * (1.0 - np.exp(-t / 0.0004))
    dry = np.tanh(1.3 * dry)
    out = dry[:, None] + _gated_room(rng, dry, 0.25, 0.55)
    return frozen(fade_tail(out / np.max(np.abs(out)), 0.03))


@functools.lru_cache(maxsize=None)
def clap(var: int) -> np.ndarray:
    rng = rng_of("clap", var)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for k, d in enumerate((0.0, 0.0095, 0.0185, 0.029)):
        tt = t - d - rng.uniform(0, 0.0015)
        env += np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / (0.004 if k < 3 else 0.075)), 0.0)
    out = np.zeros((n, 2))
    for ch in range(2):
        out[:, ch] = band_noise(rng, n, 900.0, 6000.0) * env
    out = spectral(out, lambda f: np.abs(eq_response(f, [("peak", 1500.0, 5.0, 1.2)])))
    return frozen(fade_tail(out / np.max(np.abs(out)), 0.03))


TOMS = {"tom_h": 164.8, "tom_m": 123.5, "tom_f": 82.4}          # E3, B2, E2: tonic and dominant of the key


@functools.lru_cache(maxsize=None)
def tom(which: str, var: int) -> np.ndarray:
    rng = rng_of("tom", which, var)
    f0 = TOMS[which]
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.3 * np.exp(-t / 0.045))
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.32) + 0.25 * np.sin(1.59 * ph + 0.7) * np.exp(-t / 0.12)
    stick = band_noise(rng, n, 1200.0, 8000.0) * np.exp(-t / 0.004) * 0.35
    dry = np.tanh(1.4 * (body + stick) * (1.0 - np.exp(-t / 0.0006)))
    out = dry[:, None] + _gated_room(rng, dry, 0.32, 0.45, 200.0, 5000.0, 0.35)
    return frozen(fade_tail(out / np.max(np.abs(out)), 0.04))


@functools.lru_cache(maxsize=None)
def _metal(var: int, n: int) -> np.ndarray:
    rng = rng_of("metal", var)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f in np.array([205.3, 304.4, 369.6, 522.7, 540.0, 800.0]) * 1.55:
        k = np.arange(1, int(20000.0 / f) + 1, 2)
        y += np.sum(np.sin(2.0 * np.pi * f * k[:, None] * t[None, :] + rng.uniform(0, 6.3)) / k[:, None], axis=0)
    return y


@functools.lru_cache(maxsize=None)
def hat(open_: bool, var: int) -> np.ndarray:
    rng = rng_of("hat", open_, var)
    n = int((0.24 if open_ else 0.12) * SR)
    t = np.arange(n) / SR
    metal = spectral(_metal(var % 3, n), lambda f: np.abs(eq_response(f, [("hp", 6500.0, 0.8), ("hp", 6500.0, 0.8),
                                                                         ("peak", 9500.0, 4.0, 1.0)])))
    metal /= np.sqrt(np.mean(metal ** 2)) + 1e-9
    noise = band_noise(rng, n, 7500.0, 17000.0)
    x = 0.55 * metal + 0.6 * noise
    tau = 0.26 if open_ else 0.026
    x *= np.exp(-t / tau) * (1.0 - np.exp(-t / 0.0003))
    if open_:                                   # choked by the next closed hat
        x = fade_tail(x, 0.03)
    return frozen(fade_tail(x / np.max(np.abs(x)), 0.01))


@functools.lru_cache(maxsize=None)
def crash(var: int) -> np.ndarray:
    rng = rng_of("crash", var)
    n = int(3.6 * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for ch in range(2):
        k = 70
        fk = np.exp(rng.uniform(np.log(420.0), np.log(15000.0), k))
        ak = (fk / 1000.0) ** -0.15 * rng.uniform(0.3, 1.0, k)
        tau = 1.25 * (fk / 1000.0) ** -0.22 * rng.uniform(0.6, 1.3, k)
        partials = additive(fk, ak, n, rng.uniform(0, 2 * np.pi, k), tau)
        partials /= np.sqrt(np.mean(partials[:SR // 4] ** 2)) + 1e-9
        hiss = band_noise(rng, n, 3000.0, 17000.0) * np.exp(-t / 0.95)
        burst = band_noise(rng, n, 1500.0, 15000.0) * np.exp(-t / 0.025)
        out[:, ch] = (0.5 * partials * 0.5 + 0.6 * hiss + 0.9 * burst) * (1.0 - np.exp(-t / 0.0008))
    out = spectral(out, lambda f: np.abs(eq_response(f, [("hp", 380.0, 0.7), ("hp", 380.0, 0.7)])))
    return frozen(fade_tail(out / np.max(np.abs(out)), 0.4))


@functools.lru_cache(maxsize=None)
def reverse_crash(beats: float) -> np.ndarray:
    n = int(beats * BEAT * SR)
    c = np.array(crash(7)[:n][::-1])
    t = np.arange(n) / n
    c *= (t ** 2.2)[:, None]
    return frozen(fade_tail(c, 0.004))


def _stft_noise(rng, n: int, shape_fn, frame: int = 2048, hop: int = 512) -> np.ndarray:
    """Noise with a time-varying spectrum: random-phase frames shaped by shape_fn(t_frame, freqs), overlap-add."""
    f = np.fft.rfftfreq(frame, 1.0 / SR)
    win = np.hanning(frame)
    y = np.zeros(n + frame)
    norm = np.zeros(n + frame)
    for s in range(0, n, hop):
        mag = shape_fn(s / SR, f)
        spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(f)))
        y[s:s + frame] += np.fft.irfft(spec, frame) * win
        norm[s:s + frame] += win * win
    return y[:n] / np.maximum(norm[:n], 1e-3)


@functools.lru_cache(maxsize=None)
def riser(bars: int) -> np.ndarray:
    """Noise sweep (band centre 300 Hz -> 9 kHz, level rising) ending exactly at the downbeat."""
    rng = rng_of("riser", bars)
    dur = bars * BAR
    n = int(dur * SR)

    def shape(t, f):
        u = min(t / dur, 1.0)
        fc = 300.0 * (9000.0 / 300.0) ** (u ** 1.4)
        g = np.exp(-0.5 * (np.log2(np.maximum(f, 20.0) / fc) / 0.9) ** 2)
        return g * (10.0 ** ((-26.0 + 26.0 * u ** 1.6) / 20.0))

    out = np.stack([_stft_noise(rng, n, shape), _stft_noise(rng, n, shape)], axis=1)
    out /= np.max(np.abs(out))
    return frozen(fade_tail(out, 0.015))


@functools.lru_cache(maxsize=None)
def impact() -> np.ndarray:
    rng = rng_of("impact")
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    f = 30.0 + 42.0 * np.exp(-t / 0.22)
    sub = np.sin(2.0 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.75) * (1.0 - np.exp(-t / 0.003))
    boom = band_noise(rng, n, 25.0, 220.0) * np.exp(-t / 0.4) * 0.5
    out = np.stack([sub + boom, sub + band_noise(rng, n, 25.0, 220.0) * np.exp(-t / 0.4) * 0.5], axis=1)
    return frozen(fade_tail(out / np.max(np.abs(out)), 0.3))


# ------------------------------------------------------------------------------------------------
# Bass
# ------------------------------------------------------------------------------------------------

def _string(rng, f0: float, n: int, t60: float, damp1: float, damp2: float, p: float, q: float, kmax: int,
            fmax: float, inharm: float, twang: float = 0.004) -> np.ndarray:
    """Plucked string: partials with inharmonicity, pluck/pickup position combs, frequency-dependent decay,
    initial sharp pitch (tension) settling within 30 ms."""
    K = max(1, min(kmax, int(fmax / f0)))
    k = np.arange(1, K + 1)
    fk = k * f0 * np.sqrt(1.0 + inharm * k * k)
    ak = np.abs(np.sin(np.pi * k * p)) * np.abs(np.sin(np.pi * k * q)) ** 0.5 / k ** 0.8
    tau = t60 / (1.0 + damp1 * k + damp2 * k * k) / 6.9078
    t = np.arange(n) / SR
    mod = 1.0 + twang * np.exp(-t / 0.03)
    return additive(fk, ak, n, rng.uniform(0, 2 * np.pi, K), tau, freq_mod=mod)


@functools.lru_cache(maxsize=None)
def bass_pick(midi: int, steps: float, var: int) -> np.ndarray:
    rng = rng_of("bass_pick", midi, steps, var)
    dur = steps * STEP
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    y = _string(rng, float(mtof(midi)), n, 2.8, 0.03, 0.002, 0.21 + 0.02 * rng.uniform(-1, 1), 0.18, 70, 4500.0,
                7e-5, 0.003)
    y = y / (np.max(np.abs(y[: int(0.05 * SR)])) + 1e-9)
    y = y * (1.0 - np.exp(-t / 0.0012)) + band_noise(rng, n, 700.0, 4000.0) * np.exp(-t / 0.004) * 0.06
    y *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.016))
    return frozen(fade_tail(y, 0.01))


@functools.lru_cache(maxsize=None)
def bass_syn(midi: int, steps: float, var: int, cut: float = 260.0, env: float = 1100.0,
             attack: float = 0.002) -> np.ndarray:
    rng = rng_of("bass_syn", midi, steps, var)
    f0 = float(mtof(midi))
    dur = steps * STEP
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    K = max(1, min(90, int(9000.0 / f0)))
    k = np.arange(1, K + 1)
    fk = k * f0

    def amps(tt):
        fc = cut + env * np.exp(-tt / 0.08)
        return (1.0 / k)[:, None] * ladder(fk[:, None], fc[None, :], 0.12)

    y = additive(fk, amps, n, np.zeros(K))
    a = (1.0 - np.exp(-t / attack)) * (0.78 + 0.22 * np.exp(-t / 0.12))
    a *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.02))
    y = y * a
    return frozen(fade_tail(y / 3.0, 0.01))


# ------------------------------------------------------------------------------------------------
# Guitars
# ------------------------------------------------------------------------------------------------

GTR_MODES = {   # t60 (s), damping of higher partials (linear, quadratic), strum spread (s), end mute (s)
    "open": (4.0, 0.025, 0.0018, 0.007, 0.022),
    "half": (1.1, 0.12, 0.008, 0.005, 0.016),
    "mute": (0.22, 0.32, 0.04, 0.0035, 0.008),
}


@functools.lru_cache(maxsize=None)
def gtr_hit(notes: tuple, steps: float, mode: str, stroke: int, take: int, var: int) -> np.ndarray:
    """DI signal of one strum (power chord) - plucked strings with strum delays and pick noise."""
    rng = rng_of("gtr", notes, steps, mode, stroke, take, var)
    t60, d1, d2, spread, mute = GTR_MODES[mode]
    dur = steps * STEP
    n = int((dur + 0.05) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    order = notes if stroke > 0 else notes[::-1]
    p = 0.12 + 0.02 * take + 0.01 * rng.uniform(-1, 1)
    for i, m in enumerate(order):
        d = int(i * spread * rng.uniform(0.7, 1.3) * SR)
        f0 = float(mtof(m)) * 2.0 ** (rng.normal(0.0, 3.0) / 1200.0)
        s = _string(rng, f0, n - d, t60, d1, d2, p, 0.09 + 0.02 * take, 60, 7000.0,
                    1.2e-4 if m < 50 else 6e-5, 0.005 if mode == "open" else 0.003)
        s = s / (np.max(np.abs(s[: int(0.03 * SR)])) + 1e-9)
        tt = t[: n - d]
        s = s * (1.0 - np.exp(-tt / 0.0007)) + band_noise(rng, n - d, 1200.0, 6000.0) * np.exp(-tt / 0.003) * 0.12
        y[d:] += s * (0.9 if i else 1.0)
    y *= np.where(t < dur, 1.0, np.exp(-(t - dur) / mute))
    return frozen(fade_tail(y / len(notes), 0.006))


AMP_RHYTHM = {"hp": 90.0, "mid_f": 760.0, "mid_db": 6.0, "pre_lp": 5200.0, "g1": 7.0, "bias": 0.25, "g2": 9.0,
              "post": [("hp", 85.0, 0.8), ("peak", 115.0, 3.0, 1.2), ("peak", 420.0, -2.0, 1.0),
                       ("peak", 1900.0, 2.5, 1.2), ("peak", 3300.0, 3.0, 1.6), ("lp", 5600.0, 0.9),
                       ("lp", 6500.0, 0.6), ("peak", 4600.0, -2.5, 3.0)]}
AMP_LEAD = {"hp": 160.0, "mid_f": 900.0, "mid_db": 8.0, "pre_lp": 4800.0, "g1": 9.0, "bias": 0.3, "g2": 12.0,
            "post": [("hp", 140.0, 0.7), ("peak", 800.0, 1.5, 0.9), ("peak", 2400.0, 3.0, 1.4),
                     ("lp", 5200.0, 0.9), ("lp", 6200.0, 0.6), ("peak", 3800.0, -2.0, 3.0)]}


def amp_sim(di: np.ndarray, p: dict, chunk: int = 1 << 18, margin: int = 8192) -> np.ndarray:
    """Guitar amp: pre-EQ (tight low end, mid hump, fizz cut) -> 4x oversampled asymmetric tanh stage -> DC block
    -> interstage low-pass -> second tanh stage -> tone stack and 4x12 cabinet (minimum-phase FIR)."""
    x = apply_eq(di, [("hp", p["hp"], 0.7), ("peak", p["mid_f"], p["mid_db"], 0.8), ("lp", p["pre_lp"], 0.7)])
    out = np.zeros(len(x))
    inter = eq_fir([("lp", 9500.0, 0.7)], 16384, 512, SR * OS)
    w = int(0.012 * SR * OS)
    g1, g2, bias = p["g1"], p["g2"], p["bias"]
    for s in range(0, len(x), chunk):
        a, b = max(0, s - margin), min(len(x), s + chunk + margin)
        seg = x[a:b]
        if np.max(np.abs(seg)) < 1e-7:
            continue
        u = upsample(seg)
        u = np.tanh(g1 * u + bias) - math.tanh(bias)
        c = np.concatenate([[0.0], np.cumsum(u)])
        lo = np.clip(np.arange(len(u)) - w // 2, 0, len(u))
        hi = np.clip(np.arange(len(u)) + w // 2, 0, len(u))
        u = u - (c[hi] - c[lo]) / np.maximum(hi - lo, 1)
        u = convolve(u, inter)
        u = np.tanh(g2 * u)
        d = downsample(u)
        e = min(len(x), s + chunk)
        out[s:e] = d[s - a:s - a + (e - s)]
    return apply_eq(out, p["post"], 4096) * 0.5


@functools.lru_cache(maxsize=None)
def gtr_root(chord: str) -> int:
    pc = CHORDS[chord][0]
    return 40 + (pc - 4) % 12          # E2 .. D#3


def power_chord(chord: str) -> tuple:
    r = gtr_root(chord)
    return (r, r + 7, r + 12)


# ------------------------------------------------------------------------------------------------
# Synths
# ------------------------------------------------------------------------------------------------

def upper_triad(chord: str, lo: int = 62) -> list:
    pc, third = CHORDS[chord]
    pcs = {pc % 12, (pc + third) % 12, (pc + 7) % 12}
    return [m for m in range(lo, lo + 12) if m % 12 in pcs]


def bass_root(chord: str) -> int:
    return 28 + (CHORDS[chord][0] - 4) % 12          # E1 .. D#2


def pad_notes(chord: str) -> tuple:
    return tuple([48 + (CHORDS[chord][0] - 0) % 12] + upper_triad(chord))


@functools.lru_cache(maxsize=None)
def pad_chord(notes: tuple, dur: float, var: int) -> np.ndarray:
    rng = rng_of("pad", notes, dur, var)
    rel = 1.1
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    att = 0.32
    env = np.where(t < att, 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / att, 1.0)), 1.0)
    env *= np.where(t < dur, 1.0, np.exp(-(t - dur) / (rel / 4.0)))
    out = np.zeros((n, 2))
    for i, m in enumerate(notes):
        f0 = float(mtof(m))
        for v, (det, pan) in enumerate(((-9.0, -0.75), (0.0, 0.0), (9.0, 0.75))):
            fr = f0 * 2.0 ** ((det + rng.uniform(-2.0, 2.0)) / 1200.0)
            y = osc("saw", fr, n, rng.random())
            gl, gr = pan_gains(pan * (1 if i % 2 else -1))
            out[:, 0] += y * gl
            out[:, 1] += y * gr
        if i == 0:
            y = osc("square", f0 / 2.0, n, rng.random()) * 0.35
            out += y[:, None]
    out *= env[:, None] / (3.0 * len(notes))
    return frozen(fade_tail(out, 0.05))


ARP_CUTS = [260.0, 360.0, 500.0, 700.0, 980.0, 1350.0, 1800.0, 2300.0]


@functools.lru_cache(maxsize=None)
def arp_note(midi: int, bright: int, var: int) -> np.ndarray:
    rng = rng_of("arp", midi, bright, var)
    f0 = float(mtof(midi)) * 2.0 ** (rng.normal(0, 2.0) / 1200.0)
    dur = STEP * 0.85
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    K = max(1, int(12000.0 / f0))
    k = np.arange(1, K + 1)
    base = ARP_CUTS[bright]
    wave = 1.0 / k * np.where(k % 2 == 1, 1.0, 0.55)           # between saw and square

    def amps(tt):
        fc = base * (1.0 + 3.5 * np.exp(-tt / 0.045))
        return wave[:, None] * ladder((k * f0)[:, None], fc[None, :], 0.42)

    y = additive(k * f0, amps, n, np.zeros(K))
    a = (1.0 - np.exp(-t / 0.0015)) * np.exp(-t / 0.2) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.05))
    return frozen(fade_tail(y * a, 0.02))


@functools.lru_cache(maxsize=None)
def brass(notes: tuple, steps: float, var: int) -> np.ndarray:
    rng = rng_of("brass", notes, steps, var)
    dur = steps * STEP
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for i, m in enumerate(notes):
        for v, det in enumerate((-7.0, 7.0)):
            f0 = float(mtof(m)) * 2.0 ** ((det + rng.uniform(-1.5, 1.5)) / 1200.0)
            K = max(1, int(9000.0 / f0))
            k = np.arange(1, K + 1)

            def amps(tt, k=k, f0=f0):
                fc = 450.0 + 3000.0 * (1.0 - np.exp(-tt / 0.03)) * (0.45 + 0.55 * np.exp(-tt / 0.25))
                return (1.0 / k)[:, None] * ladder((k * f0)[:, None], fc[None, :], 0.15)

            y = additive(k * f0, amps, n, rng.uniform(0, 2 * np.pi, K))
            gl, gr = pan_gains(0.35 if v else -0.35)
            out[:, 0] += y * gl
            out[:, 1] += y * gr
    a = (1.0 - np.exp(-t / 0.01)) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.06))
    out *= a[:, None] / (2.0 * len(notes))
    return frozen(fade_tail(out, 0.03))


@functools.lru_cache(maxsize=None)
def bell(midi: int, steps: float, var: int) -> np.ndarray:
    """Two-operator FM bell (ratio 3.5, decaying index) layered with an FM electric-piano tone."""
    f = float(mtof(midi))
    dur = steps * STEP
    n = int((dur + 2.2) * SR)
    t = np.arange(n) / SR
    bell_ = np.sin(2 * np.pi * f * t + (2.0 * np.exp(-t / 0.22) + 0.35) * np.sin(2 * np.pi * 3.5 * f * t))
    ep = np.sin(2 * np.pi * f * t + 1.3 * np.exp(-t / 0.5) * np.sin(2 * np.pi * f * t))
    y = (0.55 * bell_ * np.exp(-t / 1.1) + 0.6 * ep * np.exp(-t / 1.6)) * (1.0 - np.exp(-t / 0.0015))
    y *= np.where(t < dur + 0.8, 1.0, np.exp(-(t - dur - 0.8) / 0.25))
    return frozen(fade_tail(y, 0.05))


LEAD_PATCHES = {
    # oscillators (wave, detune cents, octave, level), low-pass, glide (s), vibrato depth (semitones), attack,
    # release, brightness envelope amount
    "lead": {"osc": [("saw", -7.0, 0, 0.5), ("saw", 7.0, 0, 0.5), ("square", 0.0, -12, 0.3)], "cut": 4200.0,
             "glide": 0.022, "vib": 0.17, "att": 0.005, "rel": 0.09, "bright": 0.55},
    "soft": {"osc": [("square", -4.0, 0, 0.45), ("tri", 4.0, 0, 0.8), ("saw", 0.0, 0, 0.2)], "cut": 2400.0,
             "glide": 0.05, "vib": 0.13, "att": 0.015, "rel": 0.16, "bright": 0.35},
}


def parse_line(line: str) -> list:
    """'step:len:Note[:opt...]' tokens of one bar -> [(step, len, midi, opts)]; opts: v (vibrato), b-2 (pre-bend
    from 2 semitones below), B+2 (bend up at the end), s (slide in), l (legato, no pick)."""
    out = []
    for tok in line.split():
        parts = tok.split(":")
        out.append((float(parts[0]), float(parts[1]), note_midi(parts[2]), parts[3:]))
    return out


def phrase(lines: list, bar0: int, transpose: int = 0) -> list:
    """Notes of consecutive bars -> [{t, dur, midi, opts}] (absolute seconds)."""
    notes = []
    for j, line in enumerate(lines):
        for st, ln, m, opts in parse_line(line):
            notes.append({"t": (bar0 + j) * BAR + st * STEP, "dur": ln * STEP, "midi": m + transpose, "opts": opts})
    return notes


def pitch_curve(notes: list, t0: float, n: int, glide: float, vib: float, key: str, guitar: bool = False):
    """Per-sample pitch (MIDI, float) and gate/attack info for a monophonic phrase."""
    t = t0 + np.arange(n) / SR
    pitch = np.full(n, float(notes[0]["midi"]))
    gate = np.zeros(n)
    attacks = []
    prev = None
    for i, nt in enumerate(notes):
        a = max(0, int(round((nt["t"] - t0) * SR)))
        nxt = notes[i + 1] if i + 1 < len(notes) else None
        end_t = nt["t"] + nt["dur"]
        legato_next = nxt is not None and nxt["t"] - end_t < 0.03
        e = int(round(((nxt["t"] if legato_next else end_t) - t0) * SR))
        e = min(max(e, a + 1), n)
        tt = t[a:e] - nt["t"]
        m = float(nt["midi"])
        p = np.full(e - a, m)
        opts = nt["opts"]
        slide = prev is not None and ("s" in opts or (not guitar and prev["t"] + prev["dur"] >= nt["t"] - 0.03))
        if slide:
            p = m + (float(prev["midi"]) - m) * np.exp(-tt / (glide if not guitar else 0.035))
        for o in opts:
            if o.startswith("b"):
                p = p + float(o[1:]) * np.exp(-tt / 0.06)                      # pre-bend released into pitch
            if o.startswith("B"):
                u = np.clip((tt - 0.55 * nt["dur"]) / (0.35 * nt["dur"]), 0.0, 1.0)
                p = p + float(o[1:]) * (u * u * (3 - 2 * u))
        long_note = nt["dur"] >= 0.3
        if "v" in opts or (long_note and not guitar):
            depth = (0.32 if guitar else vib) * np.clip((tt - 0.16) / 0.25, 0.0, 1.0)
            rate = 5.9 if guitar else 5.6
            p = p + depth * np.sin(2 * np.pi * rate * np.maximum(tt - 0.16, 0.0))
        pitch[a:e] = p
        if e < n:
            pitch[e:] = p[-1]
        gate[a:e] = 1.0
        if not (("l" in opts) or (not guitar and slide)):
            attacks.append(a)
        else:
            attacks.append(-a - 1)                                           # legato: soft re-articulation
        prev = nt
    return pitch, gate, attacks


def synth_lead(notes: list, patch: str, key: str, vel: float = 1.0) -> tuple:
    """Monophonic synth lead (wavetables) for a phrase: returns (start time, mono signal)."""
    P = LEAD_PATCHES[patch]
    t0 = notes[0]["t"]
    t1 = notes[-1]["t"] + notes[-1]["dur"] + 0.6
    n = int((t1 - t0) * SR)
    pitch, gate, attacks = pitch_curve(notes, t0, n, P["glide"], P["vib"], key)
    rng = rng_of("lead", key, patch)
    y = np.zeros(n)
    for wave, det, octv, lvl in P["osc"]:
        fr = mtof(pitch + octv) * 2.0 ** (det / 1200.0)
        y += lvl * osc(wave, fr, n, rng.random())
    t = np.arange(n) / SR
    # amplitude: attack on articulated notes, legato keeps the level; release after the gate closes
    env = gate_env(gate, P["att"], P["rel"])
    bright = np.zeros(n)
    for a in attacks:
        strength = 1.0 if a >= 0 else 0.5            # legato notes re-articulate softly (filter "pluck" only)
        a = a if a >= 0 else -a - 1
        m = min(n - a, int(0.6 * SR))
        bright[a:a + m] = np.maximum(bright[a:a + m], strength * np.exp(-t[:m] / 0.16))
    lp = apply_eq(y, [("lp", P["cut"], 0.8)], 1024)
    y = lp + P["bright"] * bright * (y - lp)
    return t0, y * env * vel * 0.5


def lead_guitar_di(notes: list, key: str) -> tuple:
    """DI of a lead guitar phrase: string partials following the pitch curve (bends, vibrato, slides), bright
    pick attacks, legato re-articulations; returns (start time, mono)."""
    t0 = notes[0]["t"]
    t1 = notes[-1]["t"] + notes[-1]["dur"] + 0.3
    n = int((t1 - t0) * SR)
    pitch, gate, attacks = pitch_curve(notes, t0, n, 0.035, 0.32, key, guitar=True)
    rng = rng_of("leadgtr", key)
    f = mtof(pitch)
    theta = 2.0 * np.pi * np.cumsum(f) / SR
    t = np.arange(n) / SR
    K = 20
    k = np.arange(1, K + 1)
    base = np.abs(np.sin(np.pi * k * 0.16)) / k ** 0.75
    bright = np.zeros(n)
    amp = np.zeros(n)
    for a in attacks:
        soft = a < 0
        a = -a - 1 if soft else a
        m = n - a
        tt = t[:m]
        bright[a:] = np.maximum(bright[a:] * (0.0 if not soft else 1.0), (0.4 if soft else 1.0) * np.exp(-tt / 0.12))
        amp[a:] = (0.7 if soft else 1.0) * (0.55 + 0.45 * np.exp(-tt / 0.35)) * (1.0 - np.exp(-tt / 0.0012))
    # gate: silence between non-legato notes (finger mute)
    gs = np.convolve(gate, np.ones(int(0.012 * SR)) / int(0.012 * SR), mode="same")
    amp *= gs
    y = np.zeros(n)
    ph = rng.uniform(0, 2 * np.pi, K)
    for i in range(K):
        y += base[i] * (1.0 + 2.0 * bright * (i / K)) * np.sin((i + 1) * theta + ph[i])
    y *= amp
    for a in attacks:
        if a >= 0:
            m = min(n - a, int(0.02 * SR))
            y[a:a + m] += band_noise(rng, m, 1500.0, 6000.0) * np.exp(-t[:m] / 0.003) * 0.15
    return t0, y * 0.35


# ------------------------------------------------------------------------------------------------
# Melodies (16th steps; one string per bar). The hook: rising arpeggio and falling line in 3-3-2 rhythm.
# ------------------------------------------------------------------------------------------------

HOOK = [
    "0:3:E5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:F#5",          # Em
    "0:6:G5 6:2:E5 8:2:G5 10:4:E5 14:2:D5",                  # C
    "0:3:D5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:A5",           # G
    "0:8:F#5 8:2:E5 10:2:F#5 12:4:A5",                       # D
    "0:3:E5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:F#5",          # Em
    "0:6:G5 6:2:E5 8:2:G5 10:4:E5 14:2:D5",                  # C
    "0:3:D5 3:3:G5 6:2:B5 8:3:D6 11:3:B5 14:2:A5",           # G
    "0:6:A5 6:2:G5 8:3:F#5 11:3:E5 14:2:D5",                 # D
]
THEME_GTR = [
    "0:3:E5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:F#5",
    "0:6:G5:v 6:2:E5 8:2:G5 10:4:E5:v 14:2:D5",
    "0:3:D5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:A5",
    "0:8:F#5:b-2:v 8:2:E5 10:2:F#5 12:4:A5:v",
    "0:3:E5 3:3:G5 6:2:B5 8:3:A5 11:3:G5 14:2:F#5",
    "0:6:G5:v 6:2:E5 8:2:G5 10:4:E5:v 14:2:D5",
    "0:3:D5 3:3:G5 6:2:B5 8:3:D6:b-2 11:3:B5 14:2:A5",
    "0:6:A5:v 6:2:G5 8:3:F#5 11:3:E5 14:2:D5",
]
VERSE = [
    "0:4:B4 4:2:A4 6:2:G4 8:6:E4 14:2:G4",                   # Em
    "0:4:A4 4:4:B4 8:8:G4",                                  # Em
    "0:6:E5 6:2:D5 8:4:C5 12:4:B4",                          # C
    "0:8:A4 8:4:F#4 12:4:A4",                                # D
    "0:4:B4 4:2:A4 6:2:G4 8:4:E4 12:2:G4 14:2:B4",           # Em
    "0:6:E5 6:2:D5 8:8:B4",                                  # Em
    "0:4:C5 4:4:E5 8:4:G5 12:4:E5",                          # C
    "0:8:F#5 8:4:E5 12:4:D5",                                # D
]
PRE = [
    "0:8:C5 8:4:B4 12:4:A4",                                 # Am
    "0:16:E5",                                               # Am
    "0:8:E5 8:4:D5 12:4:C5",                                 # C
    "0:16:G5",                                               # C
    "0:8:F#5 8:4:E5 12:4:D5",                                # D
    "0:16:A5",                                               # D
    "0:8:B5 8:8:A5",                                         # B (A = the seventh: B7)
    "0:8:F#5 8:8:D#5",                                       # B -> E (chorus)
]
SOLO = [
    "0:4:B4:b-2 4:2:G4 6:2:E4 8:2:G4 10:2:A4 12:4:B4:v",                                          # Em
    "0:2:C5 2:2:B4 4:2:G4 6:2:E4 8:8:G4:v",                                                       # C
    "0:1:D4 1:1:E4 2:1:G4 3:1:A4 4:1:B4 5:1:D5 6:1:E5 7:1:F#5 8:8:G5:v",                          # G
    "0:6:A5:b-2:v 6:2:F#5 8:4:D5 12:4:A4",                                                        # D
    "0:8:E5:v 8:2:D5 10:2:B4 12:2:D5 14:2:E5",                                                    # Em
    "0:4:G5 4:4:E5 8:2:G5 10:2:A5 12:4:B5:b-2:v",                                                 # C
    "0:1:D6 1:1:B5 2:1:A5 3:1:F#5 4:1:A5 5:1:F#5 6:1:E5 7:1:D5 8:1:F#5 9:1:E5 10:1:D5 11:1:B4 "
    "12:1:E5 13:1:D5 14:1:B4 15:1:A4",                                                            # D
    "0:6:B4:v 6:2:G#4 8:4:B4 12:4:E5:B+2",                                                        # E (bend to F#)
]
BELL_INTRO = [
    "0:6:E5 6:6:G5 12:4:B5", "0:12:A5 12:4:G5", "0:6:E5 6:6:G5 12:4:C6", "0:12:B5 12:4:G5",
    "0:6:E5 6:6:A5 12:4:C6", "0:16:B5",
]
BELL_BRIDGE = [
    "0:6:G5 6:6:E5 12:4:C5", "0:6:D5 6:6:B4 12:4:G4", "0:6:F#5 6:6:D5 12:4:A4", "0:6:G5 6:6:E5 12:4:B4",
    "0:6:G5 6:6:E5 12:4:C5", "0:6:B5 6:6:G5 12:4:D5", "0:6:A5 6:6:F#5 12:4:D5", "0:16:F#5",
]
E_MINOR = [4, 6, 7, 9, 11, 0, 2]


def harmony_line(line: str, steps_down: int = 2) -> str:
    """Diatonic harmony (E natural minor) a third below (two scale steps)."""
    toks = []
    for st, ln, m, opts in parse_line(line):
        pc = m % 12
        i = E_MINOR.index(pc) if pc in E_MINOR else min(range(7), key=lambda q: abs(E_MINOR[q] - pc))
        target = E_MINOR[(i - steps_down) % 7]
        h = m - ((m - target) % 12 or 12)            # nearest tone of that pitch class below m
        name = [k for k, v in NOTE_PC.items() if v == h % 12 and len(k) <= 2 and "b" not in k][0]
        toks.append(":".join([f"{st:g}", f"{ln:g}", f"{name}{h // 12 - 1}"] + opts))
    return " ".join(toks)


# ------------------------------------------------------------------------------------------------
# Patterns: drums, bass, guitars, keys (per bar, in 16th steps)
# ------------------------------------------------------------------------------------------------

def _drive(kick14: bool = False, clap: bool = True) -> list:
    ev = [(s, "kick", 1.0 if s in (0, 8) else 0.92) for s in (0, 4, 8, 12)]
    ev += [(4, "snare", 1.0), (12, "snare", 1.0)]
    if clap:
        ev += [(4, "clap", 0.75), (12, "clap", 0.75)]
    ev += [(s, "hat_o", 0.55) for s in (2, 6, 10, 14)]
    ev += [(s, "hat_c", 0.42 if s % 4 == 0 else 0.26) for s in range(16) if s % 4 != 2]
    if kick14:
        ev.append((14, "kick", 0.8))
    return ev


def _rock(ghosts: bool, odd: bool) -> list:
    ev = [(0, "kick", 1.0), (8, "kick", 0.95), (10, "kick", 0.85), (4, "snare", 1.0), (12, "snare", 1.0)]
    if odd:
        ev.append((7, "kick", 0.7))
    ev += [(s, "hat_c", 0.62 if s % 4 == 0 else 0.42) for s in range(0, 16, 2)]
    if ghosts:
        ev += [(s, "hat_c", 0.2) for s in range(1, 16, 2)]
    return ev


FILLS = {
    "small": [(12, "snare", 0.7), (13, "snare", 0.75), (14, "tom_h", 0.85), (15, "tom_m", 0.9)],
    "toms": [(12, "tom_h", 0.85), (13, "tom_h", 0.8), (14, "tom_m", 0.9), (15, "tom_f", 0.95)],
    "big": [(8, "snare", 0.75), (9, "snare", 0.7), (10, "tom_h", 0.85), (11, "tom_h", 0.8), (12, "tom_m", 0.9),
            (13, "tom_m", 0.85), (14, "tom_f", 0.95), (15, "tom_f", 1.0)],
}


def _with_fill(ev: list, kind: str) -> list:
    fill = FILLS[kind]
    start = min(s for s, _, _ in fill)
    keep = [e for e in ev if e[0] < start or e[1] == "kick"]
    return keep + fill


def _build(kind: str) -> list:
    if kind == "8ths":
        ev = [(s, "snare", 0.45 + 0.5 * s / 14) for s in range(0, 16, 2)]
    else:
        ev = [(s, "snare", 0.4 + 0.6 * s / 15) for s in range(16)]
    return ev + [(s, "kick", 0.9) for s in (0, 4, 8, 12)]


def drum_bar(b: Bar) -> list:
    s, j, n = b.sec, b.j, b.n
    if b.key[0] == "turn":
        if b.key[1] == 0:
            return [(0, "kick", 1.0), (0, "crash", 0.9), (6, "kick", 0.95), (6, "snare", 0.95), (12, "kick", 0.95),
                    (12, "snare", 0.95)] + [(st, "hat_c", 0.42) for st in (2, 4, 8, 10, 14)]
        return [(0, "kick", 1.0), (0, "crash", 0.85), (6, "kick", 0.95), (6, "snare", 0.95), (2, "hat_c", 0.4),
                (4, "hat_c", 0.42), (8, "tom_h", 0.75), (9, "tom_h", 0.8), (10, "tom_m", 0.8), (11, "tom_m", 0.85),
                (12, "tom_f", 0.85), (13, "tom_f", 0.9), (14, "kick", 0.8), (14, "snare", 0.9), (15, "snare", 1.0)]
    if s == "intro":
        if j == 4:
            return [(0, "kick", 0.55), (8, "kick", 0.5)] + [(st, "hat_c", 0.22 + 0.01 * st) for st in range(0, 16, 2)]
        if j == 5:
            return ([(st, "kick", 0.62) for st in (0, 4, 8, 12)] + [(st, "hat_c", 0.3) for st in range(0, 8, 2)]
                    + [(st, "snare", 0.3 + 0.55 * (st - 8) / 7) for st in range(8, 16)])
        return []
    if s == "outro":
        if j == 0:
            return [(0, "kick", 1.0), (0, "crash", 1.0), (0, "tom_f", 0.8)]
        return [(st, "tom_f", 0.35 + 0.5 * st / 14) for st in range(0, 16, 2)] + [(0, "kick", 0.6), (8, "kick", 0.7)]
    if s in ("theme", "chorus1", "chorus2", "solo", "final"):
        ev = _drive(kick14=(s == "final" and j % 2 == 1))
        crash_bars = (0, 4, 8, 12) if s == "final" else ((0, 2, 4, 6) if s == "solo" else (0, 4))
        if j in crash_bars:
            ev.append((0, "crash", 0.95 if j == 0 else 0.8))
        if j == n - 1:
            ev = _with_fill(ev, "big" if s == "solo" else "toms")
        elif s == "final" and j == 7:
            ev = _with_fill(ev, "small")
        return ev
    if s.startswith("verse"):
        ev = _rock(ghosts=(s == "verse2" or j >= 8), odd=(j % 2 == 1))
        if j == 0:
            ev.append((0, "crash", 0.85))
        if j == n - 1:
            ev = _with_fill(ev, "toms")
        elif j % 4 == 3:
            ev = _with_fill(ev, "small")
        return ev
    if s.startswith("pre"):
        if j == 6:
            return _build("8ths")
        if j == 7:
            return _build("16ths") + [(12, "tom_m", 0.7), (14, "tom_f", 0.8)]
        ev = [(0, "kick", 1.0), (8, "kick", 0.95), (4, "snare", 1.0), (12, "snare", 1.0)]
        if j % 2:
            ev.append((14, "kick", 0.8))
        ev += [(st, "hat_o", 0.45) for st in (0, 4, 8, 12)] + [(st, "tom_f", 0.3) for st in (2, 6, 10, 14)]
        if j in (0, 4):
            ev.append((0, "crash", 0.8))
        return ev
    if s == "bridge":
        if j < 2:
            return [(0, "kick", 0.5)]
        if j < 4:
            return [(0, "kick", 0.55)] + [(st, "hat_c", 0.25) for st in range(0, 16, 2)]
        if j < 6:
            return ([(0, "kick", 0.85), (10, "kick", 0.7), (8, "snare", 0.85)]
                    + [(st, "hat_c", 0.35) for st in range(0, 16, 2)] + ([(0, "crash", 0.6)] if j == 4 else []))
        return _build("8ths") if j == 6 else _build("16ths")
    raise ValueError(s)


def bass_bar(b: Bar) -> list:
    """(step, length in steps, midi, velocity, layers: p = picked, s = synth)."""
    r = bass_root(b.chord)
    s, j = b.sec, b.j
    eighths = range(0, 16, 2)
    if b.key[0] == "turn":
        if b.key[1] == 0:
            return [(0, 5, r, 1.0, "ps"), (6, 5, r, 0.95, "ps"), (12, 4, r, 0.95, "ps")]
        return [(0, 5, r, 1.0, "ps"), (6, 2, r, 0.9, "ps"), (8, 2, r, 0.85, "ps"), (10, 2, r + 2, 0.88, "ps"),
                (12, 2, r + 3, 0.9, "ps"), (14, 2, r + 4, 0.95, "ps")]
    if s == "intro":
        if j < 4:
            return [(0, 16, r, 0.42, "s")]
        return [(st, 1.8, r, 0.45 + 0.025 * st + (j - 4) * 0.2, "s") for st in eighths]
    if s == "outro":
        if j == 0:
            return [(0, 15, r, 1.0, "ps")]
        return [(st, 1.8, r, 0.4 + 0.035 * st, "s") for st in eighths]
    if s in ("theme", "chorus1", "chorus2", "solo", "final"):
        return [(st, 1.8, r + (12 if (st // 2) % 2 else 0), 0.95 if st % 4 == 0 else 0.82, "ps") for st in eighths]
    if s.startswith("verse") or s.startswith("pre"):
        return [(st, 1.8, r, 0.92 if st % 8 == 0 else 0.8, "ps") for st in eighths]
    if s == "bridge":
        if j < 4:
            return [(st, 0.9, r + 12, 0.42, "s") for st in range(16)]
        if j < 6:
            return [(st, 1.8, r, 0.7, "s") for st in eighths]
        return [(st, 1.8, r, 0.8, "ps") for st in eighths]
    raise ValueError(s)


def gtr_bar(b: Bar) -> list:
    """(step, length, chord, mode, velocity, stroke)."""
    s, j, c = b.sec, b.j, b.chord
    if b.key[0] == "turn":
        if b.key[1] == 0:
            return [(0, 5, c, "open", 1.0, 1), (6, 5, c, "open", 0.95, 1), (12, 4, c, "open", 0.95, 1)]
        return ([(0, 5, c, "open", 1.0, 1), (6, 2, c, "open", 0.95, 1)]
                + [(st, 2, c, "mute", 0.75, 1) for st in (8, 10, 12, 14)])
    if s == "intro":
        if j < 4:
            return []
        return [(st, 2, c, "mute", 0.4 + 0.012 * st + (j - 4) * 0.2, 1) for st in range(0, 16, 2)]
    if s == "outro":
        return [(0, 32, c, "open", 1.0, 1)] if j == 0 else []
    if s == "theme":
        if j == b.n - 1:
            return [(0, 3, c, "open", 0.95, 1), (3, 3, c, "open", 0.92, 1), (6, 2, c, "open", 0.92, 1),
                    (8, 8, c, "open", 0.95, 1)]
        return ([(0, 3, c, "open", 0.95, 1), (3, 3, c, "open", 0.92, 1), (6, 2, c, "open", 0.92, 1)]
                + [(st, 2, c, "mute", 0.8, 1) for st in (8, 10, 12, 14)])
    if s.startswith("verse"):
        ev = [(0, 2, c, "open", 0.9, 1)] + [(st, 2, c, "mute", 0.75, 1) for st in range(2, 14, 2)]
        if j % 2:
            ev += [(14, 1, c, "mute", 0.8, 1), (15, 1, c, "mute", 0.72, -1)]
        else:
            ev.append((14, 2, c, "mute", 0.75, 1))
        return ev
    if s.startswith("pre"):
        if j == 6:
            return [(st, 2, c, "open", 0.88, 1) for st in range(0, 16, 2)]
        if j == 7:
            return [(st, 1, c, "mute", 0.55 + 0.45 * st / 15, 1 if st % 2 == 0 else -1) for st in range(16)]
        return [(0, 4, c, "open", 0.95, 1)] + [(st, 2, c, "half", 0.8, 1) for st in (4, 6, 8, 10, 12, 14)]
    if s in ("chorus1", "chorus2", "final", "solo"):
        v = 0.86 if s == "solo" else 0.95
        return [(st, 2, c, "open", v if st % 4 == 0 else v - 0.08, 1) for st in range(0, 16, 2)]
    if s == "bridge":
        if j < 4:
            return []
        if j < 7:
            return [(0, 16, c, "open", 0.72, 1)]
        return [(st, 1, c, "mute", 0.5 + 0.5 * st / 15, 1 if st % 2 == 0 else -1) for st in range(16)]
    raise ValueError(s)


PAD_LEVEL = {"intro": 0.55, "theme": 0.5, "verse1": 0.42, "verse2": 0.48, "pre1": 0.62, "pre2": 0.65,
             "chorus1": 0.72, "chorus2": 0.75, "bridge": 0.82, "solo": 0.55, "final": 0.8, "outro": 0.75}
ARP = {"intro": 0.55, "verse1": 0.5, "verse2": 0.55, "chorus1": 0.3, "chorus2": 0.3, "bridge": 0.68, "final": 0.38}


def pad_events(bars: list) -> list:
    """(t, duration, chord, velocity): equal chords of neighbouring bars merged within a section."""
    out = []
    for b in bars:
        turn = b.key[0] == "turn"
        group = ("turn", b.key[1]) if turn else (b.sec, b.i - b.j)
        lvl = 0.7 if turn else PAD_LEVEL[b.sec]
        prev = out[-1] if out else None
        if prev and not turn and prev["group"] == group and prev["chord"] == b.chord:
            prev["dur"] += BAR
        else:
            out.append({"t": b.t, "dur": BAR, "chord": b.chord, "vel": lvl, "group": group})
    return [(e["t"], e["dur"], e["chord"], e["vel"]) for e in out]


def arp_bar(b: Bar) -> list:
    """(step, midi, velocity, brightness index)."""
    if b.key[0] == "turn":
        vel, bright = 0.55, 7
    elif b.sec == "intro":
        vel, bright = 0.3 + 0.05 * b.j, min(b.j, 5)
    elif b.sec in ARP and not (b.sec == "final" and b.j < 8):
        vel = ARP[b.sec] * (0.9 if b.sec == "verse1" and b.j < 8 else 1.0)
        bright = 6 if b.sec.startswith("verse") else 7
    else:
        return []
    pc, third = CHORDS[b.chord]
    root = 55 + (pc - 7) % 12
    pat = [0, 7, 12, 12 + third, 19, 12 + third, 12, 7]
    return [(st, root + pat[st % 8], vel * (1.0 if st % 4 == 0 else 0.82), bright) for st in range(16)]


def brass_bar(b: Bar) -> list:
    if b.key[0] == "turn":
        return [(0, 4, 0.85), (6, 4, 0.85), (12, 3, 0.85)] if b.key[1] == 0 else [(0, 4, 0.85), (6, 2, 0.85)]
    s, j = b.sec, b.j
    if s == "theme" and j == 0:
        return [(0, 6, 0.7)]
    if s.startswith("pre"):
        if j in (0, 2, 4):
            return [(0, 6, 0.7)]
        if j == 6:
            return [(0, 4, 0.75), (6, 4, 0.75), (12, 3, 0.75)]
        if j == 7:
            return [(0, 6, 0.8)]
    if s.startswith("chorus") and j == 0:
        return [(0, 8, 0.7)]
    if s == "final" and j in (0, 8):
        return [(0, 8, 0.8)]
    return []


def brass_notes(chord: str) -> tuple:
    tri = upper_triad(chord, 62)
    return tuple(tri + [tri[0] + 12])


# phrases: section, first bar in section, lines, transposition, patch, velocity, track
LEAD_PHRASES = [
    ("theme", 0, HOOK, 0, "lead", 0.42, "lead_syn"),
    ("verse1", 8, VERSE, 0, "soft", 0.85, "lead_syn"),
    ("pre1", 0, PRE, 0, "lead", 0.82, "lead_syn"),
    ("chorus1", 0, HOOK, 0, "lead", 1.0, "lead_syn"),
    ("verse2", 0, VERSE, 0, "soft", 0.85, "lead_syn"),
    ("pre2", 0, PRE, 0, "lead", 0.82, "lead_syn"),
    ("chorus2", 0, HOOK, 0, "lead", 1.0, "lead_syn"),
    ("chorus2", 0, [harmony_line(x) for x in HOOK], 0, "lead", 0.6, "harm_syn"),
    ("final", 0, HOOK + HOOK + ["0:14:E5"], 2, "lead", 1.0, "lead_syn"),
    ("final", 8, [harmony_line(x) for x in HOOK] + ["0:14:C5"], 2, "lead", 0.6, "harm_syn"),
]
GTR_PHRASES = [
    ("theme", 0, THEME_GTR, 0, 0.9),
    ("solo", 0, SOLO, 0, 1.0),
    ("final", 8, THEME_GTR + ["0:14:E5:v"], -10, 0.7),
]
BELL_PHRASES = [("intro", 0, BELL_INTRO, 0.7), ("bridge", 0, BELL_BRIDGE, 0.75)]


# ------------------------------------------------------------------------------------------------
# Events -> tracks
# ------------------------------------------------------------------------------------------------

class Render:
    """Track buffers of one render: bars [bar_a, bar_b) of the timeline (+ TAIL_S)."""

    JITTER = {"kick": 0.0012, "snare": 0.002, "clap": 0.002, "hat_c": 0.003, "hat_o": 0.003, "crash": 0.002,
              "tom_h": 0.003, "tom_m": 0.003, "tom_f": 0.003}

    def __init__(self, bar_a: int = 0, bar_b: int | None = None):
        self.bars = timeline()
        self.bar_a = bar_a
        self.bar_b = len(self.bars) if bar_b is None else bar_b
        self.t0 = bar_a * BAR
        self.n = int(round((self.bar_b - bar_a) * BAR * SR + TAIL_S * SR))
        self.kick_times = []

    def active(self, b: Bar) -> bool:
        return self.bar_a <= b.i < self.bar_b

    def section_bars(self, sec: str) -> list:
        """Start bars (absolute) of every occurrence of a section in the timeline."""
        return [b.i for b in self.bars if b.sec == sec and b.j == 0]

    def phrase_range(self, b0: int, count: int) -> int:
        """Number of a phrase's bars that exist in the timeline (the theme after the body is shorter), 0 when
        the phrase lies outside the rendered range."""
        avail = min(count, len(self.bars) - b0)
        if b0 + avail <= self.bar_a or b0 >= self.bar_b:
            return 0
        return avail

    def place(self, buf: np.ndarray, x: np.ndarray, t: float, gain: float = 1.0, pan: float = 0.0) -> None:
        i = int(round((t - self.t0) * SR))
        if i >= self.n or i + len(x) <= 0:
            return
        a, b = max(0, -i), min(len(x), self.n - i)
        if x.ndim == 1:
            gl, gr = pan_gains(pan)
            buf[i + a:i + b, 0] += x[a:b] * (gain * gl)
            buf[i + a:i + b, 1] += x[a:b] * (gain * gr)
        else:
            bl, br = min(1.0, 1.0 - pan), min(1.0, 1.0 + pan)
            buf[i + a:i + b, 0] += x[a:b, 0] * (gain * bl)
            buf[i + a:i + b, 1] += x[a:b, 1] * (gain * br)

    def place_mono(self, buf: np.ndarray, x: np.ndarray, t: float, gain: float = 1.0) -> None:
        i = int(round((t - self.t0) * SR))
        if i >= self.n or i + len(x) <= 0:
            return
        a, b = max(0, -i), min(len(x), self.n - i)
        buf[i + a:i + b] += x[a:b] * gain

    # --- drums -----------------------------------------------------------------------------------
    def drum_events(self) -> list:
        ev = []
        for b in self.bars:
            if not self.active(b):
                continue
            for st, inst, vel in drum_bar(b):
                r = rng_of("drum", b.key, st, inst)
                t = b.t + st * STEP + self.JITTER[inst] * r.uniform(-1.0, 1.0)
                ev.append((t, inst, vel * (1.0 + 0.05 * r.uniform(-1.0, 1.0)), int(r.integers(0, 4))))
        self.kick_times = [e[0] for e in ev if e[1] == "kick"]
        return ev

    def drums(self) -> dict:
        ev = self.drum_events()
        out = {k: np.zeros((self.n, 2)) for k in ("kick", "snare", "clap", "toms", "hats", "crash")}
        for t, inst, vel, var in ev:
            if inst == "kick":
                self.place(out["kick"], kick(var), t, vel)
            elif inst == "snare":
                self.place(out["snare"], snare(var), t, vel ** 1.3)
            elif inst == "clap":
                self.place(out["clap"], clap(var), t, vel)
            elif inst.startswith("tom"):
                self.place(out["toms"], tom(inst, var), t, vel ** 1.2,
                           {"tom_h": -0.35, "tom_m": 0.0, "tom_f": 0.35}[inst])
            elif inst == "hat_c":
                self.place(out["hats"], hat(False, var), t, vel, 0.3)
            elif inst == "hat_o":
                self.place(out["hats"], hat(True, var), t, vel, 0.3)
            elif inst == "crash":
                self.place(out["crash"], crash(var % 2), t, vel, -0.35 if var % 2 else 0.35)
        return out

    # --- bass ------------------------------------------------------------------------------------
    def bass(self) -> dict:
        pick = np.zeros((self.n, 2))
        syn = np.zeros((self.n, 2))
        for b in self.bars:
            if not self.active(b):
                continue
            for st, ln, m, vel, layers in bass_bar(b):
                r = rng_of("bass", b.key, st)
                t = b.t + st * STEP + 0.0015 * r.uniform(-1.0, 1.0)
                var = int(r.integers(0, 3))
                if "p" in layers:
                    self.place(pick, bass_pick(m, ln, var), t, vel)
                if "s" in layers and ln >= 16:          # intro drone: dark, slow attack
                    self.place(syn, bass_syn(m, ln, var, 170.0, 300.0, 0.6), t, vel)
                elif "s" in layers:
                    self.place(syn, bass_syn(m, ln, var, 200.0 if b.sec == "bridge" else 260.0), t, vel)
        return {"bass_pick": pick, "bass_syn": syn}

    # --- rhythm guitars (two takes) --------------------------------------------------------------
    def guitars(self) -> dict:
        out = {}
        for take, name in ((0, "gtr_L"), (1, "gtr_R")):
            di = np.zeros(self.n)
            for b in self.bars:
                if not self.active(b):
                    continue
                for st, ln, c, mode, vel, stroke in gtr_bar(b):
                    r = rng_of("gtr_ev", take, b.key, st)
                    t = b.t + st * STEP + 0.004 * r.uniform(-1.0, 1.0) + (0.006 if take else 0.0)
                    x = gtr_hit(power_chord(c), ln, mode, stroke, take, int(r.integers(0, 4)))
                    self.place_mono(di, x, t, vel * (1.0 + 0.04 * r.uniform(-1, 1)))
            p = dict(AMP_RHYTHM)
            if take:
                p = {**p, "mid_f": 820.0, "g1": 7.5, "post": p["post"] + [("peak", 2600.0, 1.0, 1.5)]}
            y = amp_sim(di, p)
            out[name] = np.stack([y, y], axis=1)
        return out

    def lead_guitar(self) -> dict:
        di = np.zeros(self.n)
        for sec, j0, lines, tr, vel in GTR_PHRASES:
            for bar0 in self.section_bars(sec):
                avail = self.phrase_range(bar0 + j0, len(lines))
                if avail:
                    t0, y = lead_guitar_di(phrase(lines[:avail], bar0 + j0, tr), f"{sec}:{j0}")
                    self.place_mono(di, y, t0, vel)
        y = amp_sim(di, AMP_LEAD)
        return {"lead_gtr": np.stack([y, y], axis=1)}

    # --- synths ----------------------------------------------------------------------------------
    def leads(self) -> dict:
        out = {"lead_syn": np.zeros((self.n, 2)), "harm_syn": np.zeros((self.n, 2))}
        for sec, j0, lines, tr, patch, vel, track in LEAD_PHRASES:
            for bar0 in self.section_bars(sec):
                avail = self.phrase_range(bar0 + j0, len(lines))
                if avail:
                    t0, y = synth_lead(phrase(lines[:avail], bar0 + j0, tr), patch, f"{sec}:{j0}:{track}", vel)
                    self.place(out[track], y, t0, 1.0)
        return out

    def pad(self) -> dict:
        out = np.zeros((self.n, 2))
        for t, d, c, v in pad_events(self.bars):
            if t + d < self.t0 or t >= self.bar_b * BAR:
                continue
            self.place(out, pad_chord(pad_notes(c), round(d, 4), 0), t, v)
        return {"pad": out}

    def arp(self) -> dict:
        out = np.zeros((self.n, 2))
        for b in self.bars:
            if not self.active(b):
                continue
            for st, m, vel, bright in arp_bar(b):
                self.place(out, arp_note(m, bright, st % 2), b.t + st * STEP, vel, 0.28 if st % 2 else -0.28)
        return {"arp": out}

    def brass(self) -> dict:
        out = np.zeros((self.n, 2))
        for b in self.bars:
            if not self.active(b):
                continue
            for st, ln, vel in brass_bar(b):
                self.place(out, brass(brass_notes(b.chord), ln, 0), b.t + st * STEP, vel)
        return {"brass": out}

    def bells(self) -> dict:
        out = np.zeros((self.n, 2))
        for sec, j0, lines, vel in BELL_PHRASES:
            for bar0 in self.section_bars(sec):
                for nt in phrase(lines, bar0 + j0):
                    if self.bar_a * BAR - 3.0 <= nt["t"] < self.bar_b * BAR:
                        self.place(out, bell(nt["midi"], round(nt["dur"] / STEP, 3), 0), nt["t"], vel, -0.15)
        return {"bell": out}

    def fx(self) -> dict:
        out = np.zeros((self.n, 2))
        for sec in ("theme", "chorus1", "chorus2", "solo", "final"):
            for b0 in self.section_bars(sec):
                t = b0 * BAR
                rev = reverse_crash(2.0)
                self.place(out, rev, t - len(rev) / SR, 0.7)
                if sec in ("theme", "final"):
                    self.place(out, impact(), t, 0.9)
                r = riser(4)
                self.place(out, r, t - len(r) / SR, 0.6 if sec == "theme" else 0.55)
        return {"fx": out}


# ------------------------------------------------------------------------------------------------
# Mix
# ------------------------------------------------------------------------------------------------

# bus, loudness target (LUFS of the processed track, gated), pan, EQ, sends (dB), extras
MIX = {
    "kick": {"bus": "drums", "lufs": -18.5, "eq": [("hp", 34.0, 0.7), ("peak", 92.0, 2.0, 1.0),
                                                   ("peak", 330.0, -4.0, 1.2), ("peak", 3600.0, 3.0, 1.0)]},
    "snare": {"bus": "drums", "lufs": -18.8, "eq": [("hp", 95.0, 0.7), ("peak", 210.0, 2.5, 1.2),
                                                    ("peak", 800.0, -2.5, 1.0), ("hs", 9000.0, -3.0)],
              "sends": {"plate": -15.0}},
    "clap": {"bus": "drums", "lufs": -27.0, "eq": [("hp", 350.0, 0.7)], "sends": {"plate": -11.0}},
    "toms": {"bus": "drums", "lufs": -21.5, "eq": [("hp", 60.0, 0.7), ("peak", 420.0, -3.0, 1.0),
                                                   ("peak", 4200.0, 2.0, 1.0)], "sends": {"plate": -15.0}},
    "hats": {"bus": "drums", "lufs": -31.5, "eq": [("hp", 450.0, 0.7), ("hs", 10000.0, -3.0), ("lp", 15000.0, 0.7)]},
    "crash": {"bus": "drums", "lufs": -28.5, "eq": [("hp", 400.0, 0.7), ("hs", 8000.0, -4.0), ("lp", 14000.0, 0.7)]},
    "bass_pick": {"bus": "inst", "lufs": -19.5, "sat": 1.8, "eq": [("hp", 33.0, 0.8), ("ls", 70.0, -2.5),
                                                                  ("peak", 250.0, -1.5, 1.0),
                                                                  ("peak", 950.0, 3.0, 1.2), ("lp", 4200.0, 0.7)],
                  "comp": (-6.0, 4.0, 0.004, 0.08)},
    "bass_syn": {"bus": "inst", "lufs": -21.5, "eq": [("hp", 30.0, 0.8), ("ls", 70.0, -2.5), ("peak", 420.0, -3.0, 1.0),
                                                       ("lp", 2200.0, 0.7)], "duck": 0.35},
    "gtr_L": {"bus": "inst", "lufs": -22.5, "pan": -1.0, "eq": [("hp", 85.0, 0.7), ("lp", 8000.0, 0.7)]},
    "gtr_R": {"bus": "inst", "lufs": -22.5, "pan": 1.0, "eq": [("hp", 85.0, 0.7), ("lp", 8000.0, 0.7)]},
    "lead_gtr": {"bus": "inst", "lufs": -20.5, "pan": 0.06, "eq": [("hp", 180.0, 0.7), ("peak", 3000.0, 1.0, 1.0)],
                 "sends": {"plate": -11.0, "delay": -10.0}},
    "lead_syn": {"bus": "inst", "lufs": -18.5, "eq": [("hp", 140.0, 0.7), ("peak", 2800.0, 1.5, 1.0)],
                 "sends": {"hall": -13.0, "delay": -11.0}},
    "harm_syn": {"bus": "inst", "lufs": -25.5, "pan": -0.3, "eq": [("hp", 160.0, 0.7)],
                 "sends": {"hall": -11.0, "delay": -14.0}},
    "pad": {"bus": "inst", "lufs": -25.5, "eq": [("hp", 160.0, 0.7), ("peak", 400.0, -1.5, 1.0), ("lp", 3600.0, 0.8)],
            "chorus": True,
            "duck": 0.45, "sends": {"hall": -9.0}},
    "arp": {"bus": "inst", "lufs": -26.5, "eq": [("hp", 250.0, 0.7)], "duck": 0.3,
            "sends": {"delay": -6.0, "hall": -14.0}},
    "brass": {"bus": "inst", "lufs": -24.0, "eq": [("hp", 200.0, 0.7), ("peak", 1200.0, 1.0, 1.0)],
              "sends": {"hall": -11.0}},
    "bell": {"bus": "inst", "lufs": -23.0, "eq": [("hp", 200.0, 0.7)], "sends": {"hall": -7.0, "delay": -10.0}},
    "fx": {"bus": "fx", "lufs": -27.0, "eq": [("hp", 25.0, 0.7), ("hs", 6000.0, -6.0)], "sends": {"hall": -12.0}},
}
REVERBS = {   # impulse response (name, length, predelay, RT60 at 125 Hz, RT60 at 8 kHz, air damping, reflections)
    "plate": {"ir": ("plate", 2.4, 0.018, 1.5, 1.1, 9000.0, 0.15), "eq": [("hp", 280.0, 0.7), ("lp", 7500.0, 0.7)]},
    "hall": {"ir": ("hall", 4.0, 0.035, 3.0, 2.0, 6000.0, 0.25), "eq": [("hp", 180.0, 0.7), ("lp", 6500.0, 0.7)]},
}
DELAY = (0.75 * BEAT, 0.38, 9, 3800.0, 350.0)          # dotted eighth, feedback, taps, low-pass, high-pass
TRACK_ORDER = ["drums", "bass", "guitars", "lead_guitar", "leads", "pad", "arp", "brass", "bells", "fx"]
# Mix automation (dB) per track group: by section, or by (section, first bar, last bar); 60 ms ramps around the bar
# lines. Intro, turnaround and outro carry none, the theme the same on both passes - the loop seam stays exact.
AUTOMATION = {
    "drums": {"verse1": -3.5, ("verse1", 0, 7): -4.0, "verse2": -3.0, ("pre1", 0, 5): -1.5, ("pre2", 0, 5): -1.5,
              ("bridge", 0, 3): -4.0, ("bridge", 4, 7): -2.0},
    "guitars": {"verse1": -3.0, "verse2": -2.5, ("pre1", 0, 5): -1.5, ("pre2", 0, 5): -1.5, "bridge": -2.0,
                "solo": -3.0},
    "bass": {"verse1": -2.0, "verse2": -2.0, ("bridge", 0, 3): -2.0},
    "pad": {"verse1": -1.0, "verse2": -1.0, "chorus1": 0.5, "chorus2": 0.5},
    "lead_gtr": {"solo": 4.0, "theme": 1.0, "final": -1.5},
}
TRACK_GROUP = {"kick": "drums", "snare": "drums", "clap": "drums", "toms": "drums", "hats": "drums", "crash": "drums",
               "gtr_L": "guitars", "gtr_R": "guitars", "bass_pick": "bass", "bass_syn": "bass"}


def automation(name: str, rd: "Render") -> np.ndarray | None:
    """Per-sample linear gain of a track's section automation (None: no automation)."""
    rules = AUTOMATION.get(TRACK_GROUP.get(name, name))
    if not rules:
        return None
    pts_t, pts_v = [], []
    prev = None
    for b in rd.bars:
        v = 0.0
        if b.key[0] != "turn":
            v = rules.get(b.sec, 0.0)
            for k, val in rules.items():
                if isinstance(k, tuple) and k[0] == b.sec and k[1] <= b.j <= k[2]:
                    v = val
        if v != prev:
            t = b.t - rd.t0
            pts_t += [t - 0.03, t + 0.03]
            pts_v += [v if prev is None else prev, v]
            prev = v
    return 10.0 ** (np.interp(np.arange(rd.n) / SR, pts_t, pts_v) / 20.0)


def process_track(name: str, x: np.ndarray, duck: np.ndarray | None, auto: np.ndarray | None = None) -> np.ndarray:
    spec = MIX[name]
    if auto is not None:
        x = x * auto[:, None]
    if "sat" in spec:
        k = spec["sat"]
        pk = np.max(np.abs(x)) + 1e-12
        x = np.tanh(k * x / pk) / math.tanh(k) * pk
    if spec.get("eq"):
        x = apply_eq(x, spec["eq"])
    if "comp" in spec:
        rel, ratio, att, rls = spec["comp"]
        x = x * compressor_gain(x, integrated_lufs(x) + rel, ratio, att, rls)[:, None]
    if spec.get("chorus"):
        x = chorus(x, mix=0.6)
    if "pan" in spec:
        gl, gr = pan_gains(spec["pan"])
        x = np.stack([x[:, 0] * gl, x[:, 1] * gr], axis=1)
    if "duck" in spec and duck is not None:
        x = x * (1.0 - spec["duck"] * (1.0 - duck))[:, None]
    lv = integrated_lufs(x)
    if lv > -150.0:
        x = x * undb(spec["lufs"] - lv)
    return x


def mix(rd: Render, log=print, stems_dir: str | None = None) -> tuple:
    n = rd.n
    buses = {k: np.zeros((n, 2)) for k in ("drums", "inst", "fx")}
    sends = {k: np.zeros(n) for k in ("plate", "hall", "delay")}
    duck = None
    levels = {}
    for group in TRACK_ORDER:
        t1 = time.time()
        tracks = getattr(rd, group)()
        if group == "drums":
            duck = duck_env([t - rd.t0 for t in rd.kick_times], n, 1.0)
        names = []
        for name, x in tracks.items():
            if not np.any(x):
                continue
            y = process_track(name, x, duck, automation(name, rd))
            spec = MIX[name]
            buses[spec["bus"]] += y
            for s, lvl in spec.get("sends", {}).items():
                sends[s] += (y[:, 0] + y[:, 1]) * (0.5 * undb(lvl))
            levels[name] = round(integrated_lufs(y), 2)
            names.append(name)
            if stems_dir:
                write_wav(os.path.join(stems_dir, f"stem_{name}.wav"), y, 16)
        log(f"  {group:12s} {time.time() - t1:6.1f} s  " + ", ".join(f"{k} {levels[k]:.1f}" for k in names))
    # drum bus: parallel compression (punch, sustain of the gated rooms)
    d = buses["drums"]
    buses["drums"] = d + 0.45 * undb(4.0) * d * compressor_gain(d, integrated_lufs(d) - 2.0, 5.0, 0.004, 0.11)[:, None]
    ret = np.zeros((n, 2))
    for name, r in REVERBS.items():
        ret += apply_eq(convolve(sends[name], np.asarray(reverb_ir(*r["ir"]))), r["eq"])
    ret += convolve(sends["delay"], np.asarray(pingpong_ir(*DELAY)))
    return buses["drums"] + buses["inst"] + buses["fx"] + ret, levels


# tonal balance of the sum (checked against a rock/pop target by music_preview.py): less boom at the kick's
# fundamental, more body at 100-250 Hz, softer top
MASTER_EQ = [("hp", 24.0, 0.7), ("peak", 62.0, -2.5, 1.4), ("peak", 105.0, 2.0, 1.0), ("peak", 250.0, 2.5, 0.8),
             ("hs", 8500.0, -2.5)]


def master_chain(x: np.ndarray, measure: slice, log=print) -> tuple:
    """Master EQ, glue compressor, mono low end, loudness to TARGET_LUFS (measured over `measure`), limiter."""
    x = apply_eq(x, MASTER_EQ)
    g = compressor_gain(x, integrated_lufs(x[measure]) + 3.0, 2.0, 0.015, 0.2, 6.0)
    x = x * g[:, None]
    mid = 0.5 * (x[:, 0] + x[:, 1])
    side = apply_eq(0.5 * (x[:, 0] - x[:, 1]), [("hp", 120.0, 0.7071)])
    x = np.stack([mid + side, mid - side], axis=1)
    gain = undb(TARGET_LUFS - integrated_lufs(x[measure]))
    for it in range(6):
        y, gr = limiter(x * gain, CEILING_DBTP - 0.7)
        lv = integrated_lufs(y[measure])
        log(f"  Master: Durchgang {it + 1}: {lv:.2f} LUFS, Begrenzer bis {gr.min():.1f} dB")
        if abs(lv - TARGET_LUFS) < 0.03:
            break
        gain *= undb(TARGET_LUFS - lv)
    return y, {"glue_gr_db": round(float(db(g.min())), 2), "limiter_gr_db": round(float(gr.min()), 2),
               "limiter_gr_p995_db": round(float(np.percentile(gr[measure], 0.5)), 2)}


# ------------------------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------------------------

def write_wav(path: str, x: np.ndarray, bits: int = 32) -> None:
    """WAV writer: 32-bit float (bits=32) or 16-bit PCM."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    ch = x.shape[1]
    if bits == 32:
        data = x.astype("<f4").tobytes()
        fmt, bps = 3, 4
    else:
        data = (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes()
        fmt, bps = 1, 2
    hdr = b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVEfmt " + (16).to_bytes(4, "little")
    hdr += fmt.to_bytes(2, "little") + ch.to_bytes(2, "little") + SR.to_bytes(4, "little")
    hdr += (SR * ch * bps).to_bytes(4, "little") + (ch * bps).to_bytes(2, "little") + (8 * bps).to_bytes(2, "little")
    with open(path, "wb") as fh:
        fh.write(hdr + b"data" + len(data).to_bytes(4, "little") + data)


def read_wav(path: str) -> np.ndarray:
    with open(path, "rb") as fh:
        raw = fh.read()
    fmt = int.from_bytes(raw[20:22], "little")
    ch = int.from_bytes(raw[22:24], "little")
    bps = int.from_bytes(raw[34:36], "little") // 8
    i = raw.index(b"data")
    data = raw[i + 8:i + 8 + int.from_bytes(raw[i + 4:i + 8], "little")]
    x = np.frombuffer(data, "<f4" if fmt == 3 else "<i2").astype(np.float64)
    if fmt != 3:
        x /= 32768.0
    return x.reshape(-1, ch)


def encode_ogg(x: np.ndarray, path: str) -> None:
    """Vorbis via ffmpeg, bit-exact (fixed stream serial, no encoder version tag)."""
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg fehlt (Vorbis-Kodierung)")
    cmd = [exe, "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(OGG_QUALITY), "-fflags", "+bitexact", "-flags:a", "+bitexact",
           "-map_metadata", "-1", "-metadata", "title=Crossing Europe - Titelmelodie", path]
    subprocess.run(cmd, input=np.asarray(x, "<f4").tobytes(), check=True)


def decode_ogg(path: str) -> np.ndarray:
    r = subprocess.run([shutil.which("ffmpeg"), "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2",
                        "-ar", str(SR), "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, "<f4").reshape(-1, 2).astype(np.float64)


IMPORT_TEMPLATE = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"
{uid}path="res://.godot/imported/{name}-{md5}.oggvorbisstr"

[deps]

source_file="res://assets/audio/music/{name}"
dest_files=["res://.godot/imported/{name}-{md5}.oggvorbisstr"]

[params]

loop=true
loop_offset={offset}
bpm=0
beat_count=0
bar_beats=4
"""


def write_import(ogg_path: str) -> None:
    """Godot import settings: loop from the end of the intro. An existing .import keeps its uid (references stay
    valid; a new file gets one from Godot's next import); the import path carries Godot's md5 of the resource path."""
    import hashlib
    imp = ogg_path + ".import"
    name = os.path.basename(ogg_path)
    uid = ""
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("uid="):
                    uid = line
    md5 = hashlib.md5(f"res://assets/audio/music/{name}".encode()).hexdigest()
    with open(imp, "w", encoding="utf-8") as fh:
        fh.write(IMPORT_TEMPLATE.format(uid=uid, name=name, md5=md5, offset=f"{LOOP_OFFSET_S:g}"))


def info() -> None:
    print(f"Titelmelodie: {BPM:g} bpm, 1 Takt = {BAR:g} s, Intro {INTRO_BARS} Takte = {LOOP_OFFSET_S:g} s "
          f"(Schleifenbeginn, Sample {N_LOOP_START}), Schleife {BODY_BARS} Takte = {BODY_BARS * BAR:g} s, "
          f"Datei {N_FILE / SR:g} s ({N_FILE} Samples)")
    for s in section_map():
        m, sec = divmod(s["start_s"], 60)
        print(f"  {s['bar']:4d}  {int(m)}:{sec:05.2f}  {s['label']:26s} {s['bars']:3d} Takte  {s['key']:8s} {s['chords']}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Titelmelodie rendern (docs/ui.md, Abschnitt Audio)")
    ap.add_argument("--out", default=os.path.join(OUT_DIR, OUT_NAME), help="Ziel-OGG")
    ap.add_argument("--wav", metavar="DIR", help="zusätzlich Master (Float-WAV, ganze Berechnung) und Spuren hier")
    ap.add_argument("--bars", metavar="A:B", help="nur diese Takte rendern (Skizze nach --wav, kein OGG)")
    ap.add_argument("--info", action="store_true", help="nur den Abschnittsplan zeigen")
    args = ap.parse_args(argv)
    if args.info:
        info()
        return 0
    t_start = time.time()
    rd = Render(*(int(v) for v in args.bars.split(":"))) if args.bars else Render()
    if args.wav:
        os.makedirs(args.wav, exist_ok=True)
    print(f"Titelmelodie: Takte {rd.bar_a + 1}..{rd.bar_b}, {rd.n / SR:.1f} s")
    master, levels = mix(rd, stems_dir=args.wav)
    if args.bars:
        y, mst = master_chain(master, slice(0, rd.n))
        if args.wav:
            write_wav(os.path.join(args.wav, "sketch.wav"), y)
        print(f"Skizze: {integrated_lufs(y):.2f} LUFS, True Peak {true_peak_db(y):.2f} dBTP, {mst}, "
              f"{time.time() - t_start:.0f} s")
        return 0
    y, mst = master_chain(master, slice(0, N_FILE))
    if args.wav:
        write_wav(os.path.join(args.wav, "master_full.wav"), y)
    out = y[:N_FILE]
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    encode_ogg(out, args.out)
    write_import(args.out)
    dec = decode_ogg(args.out)
    m = int(2 * BAR * SR)
    seam = y[N_LOOP_START:N_LOOP_START + m] - y[N_FILE:N_FILE + m]
    rep = {"lufs": round(integrated_lufs(out), 2), "true_peak_dbtp": round(true_peak_db(out), 2),
           "ogg_samples": int(len(dec)), "file_samples": int(N_FILE), "ogg_peak_dbfs": round(db(np.max(np.abs(dec))), 2),
           "seam_diff_dbfs": round(db(np.max(np.abs(seam))), 1), "levels": levels, **mst,
           "seconds": round(time.time() - t_start, 1)}
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
