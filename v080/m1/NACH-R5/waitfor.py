#!/usr/bin/env python3
"""waitfor.py <file> <substring> [max_s]: returns when the file contains the substring (or after max_s), prints the file tail."""
import sys, time, os
f, s = sys.argv[1], sys.argv[2]
mx = float(sys.argv[3]) if len(sys.argv) > 3 else 580
t0 = time.time()
while time.time() - t0 < mx:
    if os.path.exists(f) and s in open(f, errors='replace').read():
        break
    time.sleep(3)
print("waited %.0f s, found=%s" % (time.time() - t0, os.path.exists(f) and s in open(f, errors='replace').read()))
print(''.join(open(f, errors='replace').readlines()[-12:]) if os.path.exists(f) else 'no file')
