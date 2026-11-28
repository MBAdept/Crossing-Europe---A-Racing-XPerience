"""L/R correlation of WAV files per section of capture_mix's drive (phases from the .json next to it) and overall,
plus the correlation above / below 500 Hz."""
import json, os, sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix/tools/audio/qc")
import numpy as np, qc_lib
def band(x, sr, lo, hi):
    n = len(x); f = np.fft.rfftfreq(n, 1 / sr); X = np.fft.rfft(x, axis=0)
    X[(f < lo) | (f >= hi)] = 0
    return np.fft.irfft(X, n, axis=0)
for p in sys.argv[1:]:
    x, sr = qc_lib.read_audio(p)
    meta = p[:-4] + ".json"
    phases = json.load(open(meta)).get("phases", []) if os.path.exists(meta) else []
    out = []
    segs = [(ph.get("name"), ph.get("t0", ph.get("start")), ph.get("t1", ph.get("end"))) for ph in phases] if phases else []
    if not segs or segs[0][1] is None:
        segs = [("alles", 0.5, len(x) / sr)]
    for name, a, b in segs:
        y = x[int(a * sr):int(b * sr)]
        if len(y) < sr * 0.5: continue
        c = np.corrcoef(y[:, 0], y[:, 1])[0, 1]
        lo = band(y, sr, 20, 500); hi = band(y, sr, 500, 16000)
        out.append(f"{name} {c:.2f} (<500 {np.corrcoef(lo[:,0],lo[:,1])[0,1]:.2f}, >500 {np.corrcoef(hi[:,0],hi[:,1])[0,1]:.2f})")
    print(os.path.basename(p), " | ".join(out))
