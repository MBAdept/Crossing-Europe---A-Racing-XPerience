import sys, time, math
import numpy as np
import alib
from alib import *
import engine_synth as es

SRN = int(sys.argv[1]) if len(sys.argv) > 1 else 32000
es.SR = SRN
es.SR_INT = SRN * es.OS
es.IR_N = 16384 if SRN == 32000 else 32768
t0 = time.time()
m = es.CarModel("gran_turismo")
m.calibrate(print)
print("calibrate %.1f s" % (time.time() - t0), {k: round(float(v), 4) for k, v in m.cal["k"].items()})
for rpm_t, load in ((5200, "on"), (5200, "off"), (2500, "on"), (700, "off")):
    P = int(round(120.0 * SRN / rpm_t))
    t0 = time.time()
    res = m.render_steady(P, load)
    a = res["n_warm"] * P
    b = a + res["n_var"] * P
    print("rpm %d %s: render %.2f s, period %d" % (rpm_t, load, time.time() - t0, P))
    tot = m.mix(res["parts"])[a:b]
    fc, vt = third_octave(tot, SRN, 25, 20000)
    ref = vt.max()
    print("   total rms %.3f peak %.3f" % (np.sqrt(np.mean(tot ** 2)), np.max(np.abs(tot))))
    print("   %-7s" % "band", " ".join("%5g" % round(f) for f in fc))
    print("   %-7s" % "total", " ".join("%5.0f" % (v - ref) for v in vt))
    for c in es.COMPONENTS:
        if c in res["parts"] and m.cal["k"].get(c, 0.0) != 0.0:
            x = (m.cal["k"][c] * res["parts"][c])[a:b]
            _, v = third_octave(x, SRN, 25, 20000)
            print("   %-7s" % c, " ".join("%5.0f" % (q - ref) for q in v), "  rms %.1f dB re total" % (10 * np.log10(np.mean(x ** 2) / np.mean(tot ** 2))))
