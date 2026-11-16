#!/usr/bin/env python3
"""How the switch to the ending sums with the loop's next downbeat, at every bar line of the loop, for several fades
(the engine's FADE_OUT: linear fade of the loop over fade_beats from the bar line; FADE_DISABLED: 1 ms)."""
import sys
import numpy as np
SCR = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1"
sys.path.insert(0, WT + "/tools/audio/qc")
import qc_lib  # noqa: E402

SR = 44100
BEAT = 60.0 / 132.0
BAR_F = 4 * BEAT * SR
main, _ = qc_lib.read_audio(WT + "/assets/audio/modern/music/linke_spur.ogg")
end, _ = qc_lib.read_audio(WT + "/assets/audio/modern/music/linke_spur_schluss.ogg")
F_BODY = 721636
W = int(0.4 * SR)
e = end[:W]
tp_end = qc_lib.true_peak_db(e)


def rms_db(x):
    return 10 * np.log10(np.mean(x ** 2) + 1e-20)


for name, fade_s in (("FADE_OUT 0.5 Schlag", 0.5 * BEAT), ("FADE_OUT 0.25 Schlag", 0.25 * BEAT), ("FADE_OUT 0.125 Schlag", 0.125 * BEAT),
                     ("FADE_OUT 0.0625 Schlag", 0.0625 * BEAT), ("FADE_DISABLED (1 ms)", 0.001)):
    peaks, bumps = [], []
    n_f = max(1, int(fade_s * SR))
    g = np.zeros(W)
    g[:n_f] = np.linspace(1.0, 0.0, n_f)
    for k in range(88):
        a = F_BODY + int(round(k * BAR_F))
        body = main[a:a + W]
        if len(body) < W:
            body = np.concatenate([body, main[F_BODY:F_BODY + W - len(body)]])
        s = e + body * g[:, None]
        peaks.append(qc_lib.true_peak_db(s[: int(0.1 * SR)]))
        # loudness bump of the first 100 ms against the ending alone
        bumps.append(rms_db(s[: int(0.1 * SR)]) - rms_db(e[: int(0.1 * SR)]))
    peaks = np.array(peaks)
    bumps = np.array(bumps)
    print("%-24s True Peak max %+.2f dBTP (Median %+.2f; Schluss allein %+.2f) | Pegel der ersten 100 ms über dem Schluss allein: Median %+.2f dB, max %+.2f dB" % (
        name, peaks.max(), np.median(peaks), tp_end, np.median(bumps), bumps.max()))
