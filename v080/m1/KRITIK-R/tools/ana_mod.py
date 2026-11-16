#!/usr/bin/env python3
"""KRITIK-R: regressions in the recordings – envelope modulation (zipper noise of the level drift would put
modulation energy near the frame rate and its multiples of the mix block rate), new tonal peaks (>= 12 dB over the
third-octave neighbourhood), clicks (samples where the 4-kHz high-passed signal jumps far over its running level).
usage: ana_mod.py <capdir_before> <capdir_after> <out.json> seg ..."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
import dsp  # noqa: E402

SR = 44100


def modspec(x, frame_s=0.0025):
    """Envelope (2.5-ms RMS of the mono sum) relative to its mean, its power spectrum: share of the modulation power
    in bands, and the peak-to-neighbourhood ratio at 50-70 Hz (frame rate) and 80-95 Hz (mix blocks of 512)."""
    e = dsp.frames_env(x, SR, frame_s)
    v = e / (e.mean() + 1e-20) - 1.0
    w = np.hanning(len(v))
    sp = np.abs(np.fft.rfft(v * w)) ** 2
    f = np.fft.rfftfreq(len(v), frame_s)
    tot = float(sp[f > 0.1].sum()) + 1e-20

    def share(lo, hi):
        return round(float(sp[(f >= lo) & (f < hi)].sum()) / tot, 4)

    def line(lo, hi):
        m = (f >= lo) & (f < hi)
        nb = ((f >= lo - 15) & (f < lo)) | ((f >= hi) & (f < hi + 15))
        return round(float(10 * np.log10((sp[m].max() + 1e-30) / (np.median(sp[nb]) + 1e-30))), 1)

    return {"cv": round(float(np.std(e) / (e.mean() + 1e-20)), 3), "m0.1_1": share(0.1, 1), "m1_4": share(1, 4),
            "m4_16": share(4, 16), "m16_64": share(16, 64), "m64_200": share(64, 200),
            "line_55_65_db": line(55, 65), "line_83_90_db": line(83, 90)}


def clicks(x, thr_db=20.0):
    m = dsp.mono(x)
    y = dsp.zero_phase(m, SR, dsp.hp_mag(4000.0, 4))
    a = np.abs(y)
    k = 441
    n = len(a) // k
    rms = np.sqrt(np.mean(y[:n * k].reshape(n, k) ** 2, axis=1))
    med = np.array([np.median(rms[max(0, i - 50):i + 50]) for i in range(n)])
    pk = np.max(a[:n * k].reshape(n, k), axis=1)
    hit = pk > med * 10 ** (thr_db / 20.0) * 3.0
    return int(np.sum(hit))


def main():
    cb, ca, out = sys.argv[1], sys.argv[2], sys.argv[3]
    res = {}
    for seg in sys.argv[4:]:
        row = {}
        for lab, d in (("vorher", cb), ("nachher", ca)):
            p = os.path.join(d, seg + ".wav")
            if not os.path.exists(p):
                continue
            x, _ = dsp.load(p)
            row[lab] = {"mod": modspec(x), "tonal": [(round(fr), round(pr, 1)) for fr, pr in dsp.tonal_peaks(x, top=8)],
                        "clicks": clicks(x)}
        res[seg] = row
        v, n = row.get("vorher", {}), row.get("nachher", {})
        print(f"{seg:18s} vorher {v.get('mod')} Klicks {v.get('clicks')}\n{'':18s} nachher {n.get('mod')} Klicks {n.get('clicks')}")
        print(f"{'':18s} Töne vorher {v.get('tonal')}\n{'':18s} Töne nachher {n.get('tonal')}")
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
