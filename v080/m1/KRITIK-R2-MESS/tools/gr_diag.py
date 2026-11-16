#!/usr/bin/env python3
"""AU-R2: the limiter's gain reduction of one capture as a time series (per 0.5 s: max GR, pre peak dBFS) and the
blocks above 0.1 / 0.5 dB – to tell real limiting from a measurement artefact.
usage: gr_diag.py <capdir> <segment>"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True
from ana_cap import gain_reduction, load_f32  # noqa: E402

SR = 44100
d, seg = sys.argv[1], sys.argv[2]
pre = load_f32(os.path.join(d, seg + "_pre.f32"))
post = load_f32(os.path.join(d, seg + "_post.f32"))
info = gain_reduction(pre, post)
lag = info["lag_frames"]
n = min(len(pre), len(post))
pre, post = pre[:n], post[:n]
if lag > 0:
    pre, post = pre[:n - lag], post[lag:]
blk = 441
nb = len(pre) // blk
pp = np.max(np.abs(pre[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
qq = np.max(np.abs(post[:nb * blk]).reshape(nb, blk, 2), axis=(1, 2))
gr = np.where(pp > 1e-3, 20 * np.log10(pp / np.maximum(qq, 1e-9)), 0.0)
print(info)
print("GR quantiles (dB): 50 %.3f 90 %.3f 99 %.3f max %.3f; negative min %.3f" % (np.median(gr), np.percentile(gr, 90),
      np.percentile(gr, 99), gr.max(), gr.min()))
for i in range(0, nb, 50):
    g = gr[i:i + 50]
    print(f"{i / 100:5.1f} s  GR max {g.max():5.2f} mean {g.mean():5.2f}  pre peak {20 * np.log10(pp[i:i + 50].max()):6.2f} dBFS")
