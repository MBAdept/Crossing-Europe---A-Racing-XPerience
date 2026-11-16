"""AU-R: where do the peaks of a recording come from? Top peaks (separated by >= 50 ms) with their spectral balance
(share below 200 Hz, 200-2600 Hz, above 2600 Hz in a 20 ms window) and the level of the 50 ms around them."""
import sys

import numpy as np

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R")
import ana  # noqa: E402

for path in sys.argv[1:]:
    x = ana.load(path)
    a = np.max(np.abs(x), axis=1)
    order = np.argsort(a)[::-1]
    picked = []
    for i in order:
        if all(abs(int(i) - j) > 0.05 * ana.SR for j in picked):
            picked.append(int(i))
        if len(picked) >= 8:
            break
    print(path.rsplit("/", 1)[-1], "peaks:")
    for i in sorted(picked):
        w = x[max(i - 441, 0):i + 441].mean(axis=1)
        f = np.fft.rfftfreq(len(w), 1 / ana.SR)
        p = np.abs(np.fft.rfft(w * np.hanning(len(w)))) ** 2
        tot = p.sum() + 1e-20
        print("   t %6.3f s  %6.2f dBFS  <200 Hz %3.0f %%  200-2600 %3.0f %%  >2600 %3.0f %%" % (
            i / ana.SR, 20 * np.log10(a[i]), 100 * p[f < 200].sum() / tot, 100 * p[(f >= 200) & (f < 2600)].sum() / tot,
            100 * p[f >= 2600].sum() / tot))
    # spacing of the strong peaks (all above peak - 3 dB)
    thr = a.max() * 10 ** (-3 / 20)
    idx = np.where(a > thr)[0]
    groups = []
    for i in idx:
        if not groups or i - groups[-1][-1] > 0.02 * ana.SR:
            groups.append([i])
        else:
            groups[-1].append(i)
    starts = [g[0] / ana.SR for g in groups]
    print("   peaks within 3 dB of the maximum: %d, first gaps (s): %s" % (len(starts), [round(b - a2, 3) for a2, b in zip(starts[:12], starts[1:13])]))
