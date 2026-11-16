#!/usr/bin/env python3
"""KRITIK-R: in-game loop seams (kr_seam.gd captures) against the file decoded with ffmpeg and tiled.
For every loop: the start of the playback in the capture (cross-correlation with the first 50 ms of the file), the
residual capture - tiled file over two and more periods, its largest value near each seam (+-20 ms) against
the largest elsewhere, and the period the engine really plays (lag of the best match around the file length).
usage: ana_seam.py <capdir> <tree> <out.json> id ..."""
import json
import os
import subprocess
import sys

import numpy as np

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"
SR = 44100


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def main():
    capdir, tree, out = sys.argv[1], sys.argv[2], sys.argv[3]
    res = {}
    for sid in sys.argv[4:]:
        c = np.fromfile(os.path.join(capdir, sid + ".f32"), dtype="<f4").astype(np.float64).reshape(-1, 2)[:, 0]
        x = decode(f"{K}/{tree}/assets/audio/modern/vehicle/{sid}.ogg")
        N = len(x)
        head = x[:2205]
        # start: first index where the capture matches the head
        nz = np.nonzero(np.abs(c) > 1e-7)[0]
        s0 = int(nz[0]) if len(nz) else 0
        best, bs = -1.0, s0
        for s in range(max(0, s0 - 2048), s0 + 2048):
            seg = c[s:s + len(head)]
            if len(seg) < len(head):
                break
            v = float(np.dot(seg, head) / (np.linalg.norm(seg) * np.linalg.norm(head) + 1e-12))
            if v > best:
                best, bs = v, s
        periods = (len(c) - bs) // N
        tiled = np.tile(x, periods + 1)[:len(c) - bs]
        r = c[bs:] - tiled
        seams = [k * N for k in range(1, periods + 1) if k * N < len(r)]
        w = int(0.02 * SR)
        near = max((float(np.max(np.abs(r[max(0, q - w):q + w]))) for q in seams), default=0.0)
        mask = np.ones(len(r), bool)
        for q in seams:
            mask[max(0, q - w):q + w] = False
        far = float(np.max(np.abs(r[mask]))) if mask.any() else 0.0
        # the period the engine plays: best match of the second period against the first around N
        a = c[bs + 4410:bs + 4410 + 22050]
        bp, bl = -1.0, N
        for L in range(N - 64, N + 65):
            b = c[bs + 4410 + L:bs + 4410 + L + 22050]
            if len(b) < len(a):
                break
            v = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
            if v > bp:
                bp, bl = v, L
        # file seam: wrap step against the largest step within 100 ms
        ww = int(0.1 * SR)
        ext = np.concatenate([x[-ww:], x[:ww]])
        d1 = np.abs(np.diff(ext))
        step_ratio = float(d1[ww - 1] / (np.max(np.delete(d1, [ww - 1])) + 1e-12))
        res[sid] = {"frames_file": N, "start_corr": round(best, 6), "periods": int(periods), "played_period": bl,
                    "period_corr": round(bp, 6), "resid_near_seams": near, "resid_elsewhere": far,
                    "level_peak": float(np.max(np.abs(x))), "file_step_ratio": round(step_ratio, 3)}
        print(f"{sid:16s} N {N} Start-Korrelation {best:.6f}, {periods} Perioden, gespielte Periode {bl} ({bp:.6f}) | Rest an den "
              f"Nähten {near:.2e}, sonst {far:.2e} | Naht der Datei: Sprung x{step_ratio:.2f}")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
