"""Peaks of a worst-case recording: true peak after the limiter, per 0.5 s window the sample peak before / after it.
usage: peaks.py worst.wav   (reads worst_pre.wav next to it, stored at -6 dB)"""
import os
import sys

sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1/tools/audio/qc")
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402

post, sr = qc_lib.read_audio(sys.argv[1])
pre_path = os.path.splitext(sys.argv[1])[0] + "_pre.wav"
pre = None
if os.path.exists(pre_path):
    pre, _ = qc_lib.read_audio(pre_path)
    pre = pre * 2.0
print(f"after the limiter: true peak {qc_lib.true_peak_db(post):.2f} dBTP, sample peak {qc_lib.sample_peak_db(post):.2f} dBFS, "
      f"integrated {qc_lib.integrated_lufs(post, sr):.2f} LUFS, short-term max {qc_lib.short_term_max(post, sr):.2f}")
if pre is not None:
    print(f"before the limiter: sample peak {20*np.log10(np.max(np.abs(pre))+1e-12):.2f} dBFS, frames over -0.8 dBFS: "
          f"{int(np.sum(np.max(np.abs(pre), axis=1) > 10**(-0.8/20)))}")
w = int(0.5 * sr)
for i in range(0, len(post) - w, w):
    a = 20 * np.log10(np.max(np.abs(post[i:i + w])) + 1e-12)
    b = 20 * np.log10(np.max(np.abs(pre[i:i + w])) + 1e-12) if pre is not None and i + w <= len(pre) else float("nan")
    tp = qc_lib.true_peak_db(post[i:i + w])
    print(f"  {i / sr:5.1f} s  vorher {b:6.2f}  nachher {a:6.2f} dBFS  True Peak {tp:6.2f}")
