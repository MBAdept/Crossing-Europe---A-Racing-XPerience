"""Which processing step of the interlude differs between the two passes over the loop start?"""
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
orig = mlib.process


def proc(x, spec, duck, ref=None, rec=None):
    y = orig(x, spec, duck, ref, rec)
    d = y[fb:fb + n2] - y[fb + lp:fb + lp + n2]
    m = np.abs(d).max()
    if m > 0:
        keys = sorted(k for k in spec if k not in ("bus", "lufs"))
        print(f"  processed bus {spec.get('bus')} lufs {spec.get('lufs')}: max diff {20*np.log10(m):7.1f} dB at "
              f"{int(np.argmax(np.abs(d).max(axis=1)))} keys {keys}")
    return y


mlib.process = proc
orig_conv = mlib.ms.convolve
mix, levels, fit, _u = race_lib.render(z, z.tl, z.N_RENDER, z.specs(), zs.SEED, log=lambda *a: None)
d = mix[fb:fb + n2] - mix[fb + lp:fb + lp + n2]
print("mix max diff", 20 * np.log10(np.abs(d).max()), "at", np.argmax(np.abs(d).max(axis=1)))
