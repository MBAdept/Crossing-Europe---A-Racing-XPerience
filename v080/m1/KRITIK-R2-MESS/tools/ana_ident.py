#!/usr/bin/env python3
"""KRITIK-R2-MESS: which loop file is playing in a stretch of a recording (constant speed = constant pitch)?
The stretch (one channel or the mono sum, band-passed) is cross-correlated (normalised, every lag of one loop period)
with each candidate loop file rendered at the pitch (linear interpolation, tiled, the same band). The file that plays
gives a clear maximum; the others stay near the noise level.
usage: ana_ident.py <audio> <t0> <t1> <pitch> <lo_hz> <hi_hz> <L|R|M> name=path[:loop_frames[:file_channel]] ..."""
import subprocess
import sys

import numpy as np

SR = 44100


def decode(path, ch=2):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, ch).astype(np.float64)


def bp(m, lo, hi):
    n = len(m)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    h = 1.0 / np.sqrt(1.0 + (lo / f) ** 8) / np.sqrt(1.0 + (f / hi) ** 8)
    return np.fft.irfft(np.fft.rfft(m) * h, n)


def render(y, pitch, n_out):
    n = len(y)
    pos = (np.arange(n_out) * pitch) % n
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    return y[i] * (1.0 - fr) + y[(i + 1) % n] * fr


def ncc(a, b):
    """normalised correlation of a (len L) against every window of b (len >= L)."""
    L = len(a)
    nfft = 1 << int(np.ceil(np.log2(len(b) + L)))
    num = np.fft.irfft(np.fft.rfft(b, nfft) * np.conj(np.fft.rfft(a, nfft)), nfft)[:len(b) - L + 1]
    c2 = np.concatenate([[0.0], np.cumsum(b * b)])
    den = np.sqrt(np.maximum(c2[L:] - c2[:-L], 1e-20)) * np.sqrt(np.sum(a * a))
    return num / den


def main():
    path, t0, t1, pitch, lo, hi, chan = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), \
        float(sys.argv[5]), float(sys.argv[6]), sys.argv[7]
    x = decode(path)
    seg = x[int(t0 * SR):int(t1 * SR)]
    s = {"L": seg[:, 0], "R": seg[:, 1], "M": seg.mean(axis=1)}[chan]
    s = bp(s, lo, hi)
    out = []
    for item in sys.argv[8:]:
        name, spec = item.split("=", 1)
        parts = spec.split(":")
        f = decode(parts[0])
        if len(parts) > 1 and parts[1]:
            f = f[:int(parts[1])]
        fc = parts[2] if len(parts) > 2 else "M"
        y = {"L": f[:, 0], "R": f[:, 1], "M": f.mean(axis=1)}[fc]
        period = int(len(y) / pitch) + 2
        r = render(y, pitch, len(s) + period)
        r = bp(r, lo, hi)
        c = ncc(s, r)
        k = int(np.argmax(np.abs(c)))
        out.append((name, float(np.abs(c[k])), k, float(np.median(np.abs(c)))))
    for name, cmax, k, med in out:
        print(f"   {name:10s} max |r| {cmax:.3f} (Lag {k}, Median {med:.3f})")


if __name__ == "__main__":
    main()
