import re
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()

# car -> (loudness, idle_db, low_db, load_curve); INTERNAL_LUFS
VALUES = {
    "kompakt": (0.6, 1.3, 0.0, 0.55),
    "kombi": (0.1, 1.8, 1.3, 0.45),
    "limousine": (-0.85, 2.6, 3.5, 0.4),
    "sportwagen": (0.45, -0.7, 0.7, 0.65),
    "gran_turismo": (-0.5, 1.8, 0.0, 0.55),
}
INTERNAL = -14.6
if len(sys.argv) > 2:
    import json
    cfg = json.load(open(sys.argv[2]))
    VALUES = {k: tuple(v) for k, v in cfg["values"].items()}
    INTERNAL = cfg["internal"]

s, n = re.subn(r'INTERNAL_LUFS = -?[0-9.]+ ', 'INTERNAL_LUFS = %s ' % INTERNAL, s, count=1)
assert n == 1
for car, (loud, idle, low, lc) in VALUES.items():
    # the block of the car: from '"car": {' to its "mix" line
    m = re.search(r'    "%s": \{.*?"mix": \{[^\n]*\n' % car, s, re.S)
    assert m, car
    blk = m.group(0)
    blk2, n1 = re.subn(r'"loudness": -?[0-9.]+, "idle_db": -?[0-9.]+, "low_db": -?[0-9.]+,',
                       '"loudness": %s, "idle_db": %s, "low_db": %s,' % (loud, idle, low), blk, count=1)
    blk2, n2 = re.subn(r'"load_curve": [0-9.]+', '"load_curve": %s' % lc, blk2, count=1)
    assert n1 == 1 and n2 == 1, (car, n1, n2)
    s = s.replace(blk, blk2, 1)
open(p, 'w', encoding='utf-8').write(s)
print('ok', INTERNAL, VALUES)
