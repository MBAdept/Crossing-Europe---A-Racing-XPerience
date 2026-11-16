import sys

sys.dont_write_bytecode = True
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3"
sys.path.insert(0, R + "/tools/audio/qc")
import qc_lib

x, sr = qc_lib.read_audio(R + "/assets/audio/music/title_theme.ogg")
print("title_theme.ogg: %d Hz, %.1f s, integriert %.2f LUFS, True Peak %.2f dBTP, LRA %.2f" % (
    sr, len(x) / sr, qc_lib.integrated_lufs(x, sr), qc_lib.true_peak_db(x), qc_lib.loudness_range(x, sr)))
first = x[sr:50 * sr]
print("erste 50 s (ab 1 s): integriert %.2f LUFS" % qc_lib.integrated_lufs(first, sr))
