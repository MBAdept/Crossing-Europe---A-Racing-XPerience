"""The interlude's bus stage (Mixer.finish) step by step: where do the two passes over the loop start differ?"""
import math
import os
import sys

ROOT = sys.argv[1]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "music"))
import numpy as np  # noqa: E402
import music_lib as mlib  # noqa: E402
from music_lib import ms  # noqa: E402
import race_lib  # noqa: E402
import zwischenspiel as zs  # noqa: E402

z = zs.Zwischenspiel()
fb, lp = z.F_BODY, z.LOOP_FRAMES
n2 = int(2 * ms.BAR * mlib.SR)


def rep(name, y):
    d = y[fb:fb + n2] - y[fb + lp:fb + lp + n2]
    m = float(np.abs(d).max())
    print(f"  {name:18s} max diff {20 * math.log10(m + 1e-300):8.1f} dB at {int(np.argmax(np.abs(d).max(axis=1) if d.ndim == 2 else np.abs(d)))}")


def finish(self):
    d = self.buses["drums"]
    rep("bus drums in", d)
    rep("bus inst", self.buses["inst"])
    rep("bus fx", self.buses["fx"])
    for k, v in self.sends.items():
        rep("send " + k, v)
    dlv = ms.integrated_lufs(d)
    g = ms.compressor_gain(d, dlv - 2.0, 6.0, 0.003, 0.10)
    rep("drum comp gain", g[:, None])
    par = d * g[:, None]
    d = d + 0.5 * ms.undb(4.0) * par
    pk = np.max(np.abs(d)) + 1e-12
    d = np.tanh(1.7 * d / pk) / math.tanh(1.7) * pk
    rep("drums out", d)
    out = d + self.buses["inst"] + self.buses["fx"]
    for name, r in mlib.REVERBS2.items():
        ir = np.asarray(ms.reverb_ir(*r["ir"]))
        wet = np.stack([ms.convolve(self.sends[name][:, c], ir[:, c]) for c in range(2)], axis=1)
        rep("wet " + name, wet)
        out += ms.apply_eq(wet, r["eq"])
    dly = np.asarray(ms.pingpong_ir(*ms.DELAY))
    dl = ms.convolve(0.5 * (self.sends["delay"][:, 0] + self.sends["delay"][:, 1]), dly)
    rep("delay", dl)
    out += dl
    rep("mix", out)
    return out


mlib.Mixer.finish = finish
race_lib.render(z, z.tl, z.N_RENDER, z.specs(), zs.SEED, log=lambda *a: None)
