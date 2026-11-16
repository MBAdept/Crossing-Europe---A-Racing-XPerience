"""Which track of the interlude differs between the two passes over the loop start? (stems compared after process())"""
import os
import sys

ROOT = sys.argv[1]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "music"))
import numpy as np  # noqa: E402
import music_lib as mlib  # noqa: E402
import race_lib  # noqa: E402
import zwischenspiel as zs  # noqa: E402

z = zs.Zwischenspiel()
fb, lp = z.F_BODY, z.LOOP_FRAMES
n2 = int(2 * zs.ms.BAR * mlib.SR)
orig_add = mlib.Mixer.add


def add(self, name, x, spec, auto=None):
    if x is not None and np.any(x):
        xx = x if len(x) >= self.n else np.pad(x, ((0, self.n - len(x)),) + ((0, 0),) * (x.ndim - 1))
        raw = xx[fb:fb + n2] - xx[fb + lp:fb + lp + n2]
        print(f"  raw {name:10s} max diff {20*np.log10(np.abs(raw).max()+1e-15):7.1f} dB at "
              f"{int(np.argmax(np.abs(raw).max(axis=1) if raw.ndim == 2 else np.abs(raw)))}")
    orig_add(self, name, x, spec, auto)
    if name in self.fit["tracks"]:
        pass


mlib.Mixer.add = add
mix, levels, fit, _u = race_lib.render(z, z.tl, z.N_RENDER, z.specs(), zs.SEED, log=lambda *a: None)
d = mix[fb:fb + n2] - mix[fb + lp:fb + lp + n2]
print("mix max diff", 20 * np.log10(np.abs(d).max()), "at", np.argmax(np.abs(d).max(axis=1)))
