"""Loudness, peaks and stereo of the review drive's scenes: per scene integrated LUFS, short-term max/median,
true peak, L/R correlation; optional per-second short-term track."""
import json, os, sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix/tools/audio/qc")
import numpy as np, qc_lib
d = sys.argv[1]
detail = "--detail" in sys.argv
for s in json.load(open(os.path.join(d, "szenen.json"))):
    x, sr = qc_lib.read_audio(s["file"])
    x = x[int(0.3 * sr):]
    st = qc_lib.short_term(x, sr, 3.0, 1.0)
    corr = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])
    print(f"{os.path.basename(s['file']):16s} {qc_lib.integrated_lufs(x, sr):6.1f} LUFS  kurz max {st.max():6.1f} median {np.median(st):6.1f}  "
          f"TP {qc_lib.true_peak_db(x):5.1f}  Korr {corr:4.2f}  {s['title'][:60]}")
    if detail:
        mo = qc_lib.short_term(x, sr, 0.4, 0.5)
        print("   momentan je 0,5 s: " + " ".join(f"{v:.0f}" for v in mo))
