#!/usr/bin/env python3
"""KRITIK-R2-MESS: kr_restart.gd – start, restart on a playing player, volume steps, drift, stop of a 441-Hz sine.
Amplitude envelope = |analytic signal| (FFT Hilbert) of the left channel; a hard cut shows as a sample step far above
the largest step of the sine (A*2*pi/100), a cross-fade as an amplitude dip spread over many samples.
usage: ana_restart.py <base> <out.json>"""
import json
import sys

import numpy as np

SR = 44100


def analytic_amp(x):
    n = len(x)
    X = np.fft.fft(x)
    h = np.zeros(n)
    h[0] = 1
    if n % 2 == 0:
        h[n // 2] = 1
        h[1:n // 2] = 2
    else:
        h[1:(n + 1) // 2] = 2
    return np.abs(np.fft.ifft(X * h))


def transition(amp, i0, i1, lo_frac=0.1, hi_frac=0.9, rising=True):
    seg = amp[i0:i1]
    a0, a1 = float(np.median(amp[max(0, i0 - 3000):i0])), float(np.median(amp[i1:i1 + 3000]))
    if rising:
        lo = a0 + lo_frac * (a1 - a0)
        hi = a0 + hi_frac * (a1 - a0)
        ia = int(np.argmax(seg > lo))
        ib = int(np.argmax(seg > hi))
    else:
        lo = a1 + hi_frac * (a0 - a1)
        hi = a1 + lo_frac * (a0 - a1)
        ia = int(np.argmax(seg < lo))
        ib = int(np.argmax(seg < hi))
    return ib - ia


def analyse(x, marks):
    s = x[:, 0]
    amp = analytic_amp(s)
    A = float(np.median(amp[marks["start"] + 6000:marks["restart"] - 2000]))
    dmax_sine = A * 2 * np.pi / 100.0
    d = np.abs(np.diff(s))
    out = {"A": round(A, 4), "sine_step_max": round(dmax_sine, 5)}
    # start: fade-in length (10 -> 90 %)
    i0 = marks["start"]
    seg = amp[i0:i0 + 6000]
    on = int(np.argmax(seg > 0.02 * A))
    out["start_rise_10_90_samples"] = transition(amp, i0, i0 + 6000)
    out["start_first_audible_at"] = on
    out["start_step_ratio"] = round(float(d[i0:i0 + 6000].max() / dmax_sine), 2)
    for k in ("restart", "restart2"):
        i0 = marks[k]
        w = slice(i0 - 500, i0 + 6000)
        seg_amp = amp[w]
        ratio = float(d[w].max() / dmax_sine)
        dip = float(seg_amp[400:-400].min() / A)
        # width of the dip below 0.98 A
        below = np.nonzero(seg_amp < 0.98 * A)[0]
        width = int(below[-1] - below[0]) if len(below) else 0
        out[k] = {"step_ratio": round(ratio, 2), "amp_min_rel": round(dip, 3), "dip_width_samples": width}
    # volume steps 0 / -3 dB per frame: does the gain jump within a few samples or ramp?
    i0, i1 = marks["steps"], marks["drift"] - 1000
    st = amp[i0:i1]
    dd = np.abs(np.diff(st))
    g3 = A * (1 - 10 ** (-3 / 20))
    out["steps"] = {"step_ratio": round(float(d[i0:i1].max() / dmax_sine), 2),
                    "amp_change_per_sample_max_rel_to_3db_step": round(float(dd[200:-200].max() / g3), 4),
                    "samples_for_3db_change_min": round(float(g3 / max(dd[200:-200].max(), 1e-12)), 1)}
    # drift: modulation spectrum of the amplitude around frame rate / block rate
    i0, i1 = marks["drift"], marks["drift_end"]
    a = amp[i0:i1]
    v = a / a.mean() - 1.0
    sp = np.abs(np.fft.rfft(v * np.hanning(len(v)))) ** 2
    f = np.fft.rfftfreq(len(v), 1.0 / SR)

    def line(lo, hi):
        m = (f >= lo) & (f < hi)
        nb = ((f >= lo - 20) & (f < lo)) | ((f >= hi) & (f < hi + 20))
        return round(float(10 * np.log10((sp[m].max() + 1e-30) / (np.median(sp[nb]) + 1e-30))), 1)

    out["drift"] = {"step_ratio": round(float(d[i0:i1].max() / dmax_sine), 2), "line_55_65_db": line(55, 65),
                    "line_83_90_db": line(83, 90), "line_170_175_db": line(170, 175),
                    "amp_db_range": round(float(20 * np.log10(a.max() / a.min())), 2)}
    # stop: fade-out length
    i0 = marks["stop"]
    out["stop_fall_90_10_samples"] = transition(amp, i0, i0 + 6000, rising=False)
    out["stop_step_ratio"] = round(float(d[i0:i0 + 6000].max() / dmax_sine), 2)
    return out


def main():
    base, outp = sys.argv[1], sys.argv[2]
    meta = json.load(open(base + ".json"))
    res = {}
    for k in ("plain", "2d"):
        x = np.fromfile(f"{base}_{k}.f32", dtype="<f4").astype(np.float64).reshape(-1, 2)
        res[k] = analyse(x, meta[k])
        print(k, json.dumps(res[k]))
    json.dump(res, open(outp, "w"), indent=1)


if __name__ == "__main__":
    main()
