"""Loudness per phase of a drive_demo / layers_demo recording (phases or marks from its .json), optionally against a
second recording of the same run (e.g. without the engine): phases.py full.wav [other.wav]"""
import json
import os
import sys

sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1/tools/audio/qc")
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402


def load(p):
    x, sr = qc_lib.read_audio(p)
    meta = json.load(open(os.path.splitext(p)[0] + ".json", encoding="utf-8"))
    marks = meta.get("phases") or meta.get("marks") or []
    marks = [(float(m["t"]), str(m.get("name", m.get("label", "")))) for m in marks]
    return x, sr, marks


def lufs(seg, sr):
    xk = qc_lib.k_weight(qc_lib.as_played(seg), sr)
    return float(-0.691 + 10.0 * np.log10(max(float(np.mean(np.sum(xk * xk, axis=1))), 1e-14)))


x, sr, marks = load(sys.argv[1])
y = None
if len(sys.argv) > 2:
    y, _, _ = load(sys.argv[2])
print(f"{'Abschnitt':44s} {'Dauer':>6s} {'LUFS':>7s} {'Spitze':>7s}" + (f" {'zweite':>7s} {'Diff':>6s}" if y is not None else ""))
for i in range(len(marks) - 1):
    t0, name = marks[i]
    t1 = marks[i + 1][0]
    a, b = int(t0 * sr), min(int(t1 * sr), len(x))
    if b - a < sr // 4:
        continue
    seg = x[a:b]
    row = f"{name[:44]:44s} {t1 - t0:6.1f} {lufs(seg, sr):7.2f} {20*np.log10(np.max(np.abs(seg))+1e-12):7.2f}"
    if y is not None:
        s2 = y[a:min(b, len(y))]
        row += f" {lufs(s2, sr):7.2f} {lufs(s2, sr) - lufs(seg, sr):6.2f}"
    print(row)
