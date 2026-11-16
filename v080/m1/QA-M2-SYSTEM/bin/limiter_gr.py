#!/usr/bin/env python3
"""Gain reduction of the Modern limiter: the same deterministic capture (Movie Maker, --audio-sync, same seed) with the
limiter on and off. Checks first that the two runs are the same signal where the limiter cannot act (correlation of
quiet blocks), then reports per 50-ms block the level difference on - off (= gain reduction where negative), its
maximum, the p95, and the time of the largest reduction; plus true peak of both.
Usage: limiter_gr.py <qc_lib dir> <on.wav> <off.wav>"""
import json
import math
import sys

import numpy as np

sys.path.insert(0, sys.argv[1])
import qc_lib  # noqa: E402

on, sr = qc_lib.read_wav(sys.argv[2])
off, sr2 = qc_lib.read_wav(sys.argv[3])
n = min(len(on), len(off))
on, off = on[:n], off[:n]
blk = int(0.05 * sr)
nb = n // blk
r_on = np.sqrt((on[: nb * blk] ** 2).reshape(nb, blk, -1).mean(axis=(1, 2)))
r_off = np.sqrt((off[: nb * blk] ** 2).reshape(nb, blk, -1).mean(axis=(1, 2)))
pk_off = np.abs(off[: nb * blk]).reshape(nb, blk, -1).max(axis=(1, 2))
diff = 20 * np.log10((r_on + 1e-9) / (r_off + 1e-9))
quiet = pk_off < 10 ** (-12 / 20)          # blocks whose peak stays 10 dB under the ceiling: the limiter is idle there
same = float(np.median(np.abs(diff[quiet]))) if quiet.any() else float("nan")
exact = bool(np.array_equal(on[: int(sr * 0.5)], off[: int(sr * 0.5)]))
gr = -diff
print(json.dumps({
    "seconds": round(n / sr, 2), "first_0.5s_identical": exact,
    "median_abs_diff_quiet_blocks_db": round(same, 3),
    "true_peak_on_dbtp": round(qc_lib.true_peak_db(on), 2), "true_peak_off_dbtp": round(qc_lib.true_peak_db(off), 2),
    "sample_peak_off_dbfs": round(qc_lib.sample_peak_db(off), 2),
    "gain_reduction_max_db": round(float(gr.max()), 2), "gain_reduction_p95_db": round(float(np.percentile(gr, 95)), 2),
    "gain_reduction_t_max_s": round(float(np.argmax(gr)) * 0.05, 2),
    "blocks_gr_over_0.5db": int((gr > 0.5).sum()), "blocks": int(nb)}, indent=1))
