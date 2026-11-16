#!/usr/bin/env python3
"""Print identifier-like strings of a decompressed GDScript token buffer (chars stored as u32 ^ 0xb6)."""
import re
import struct
import sys

d = open(sys.argv[1], "rb").read()
found = set()
for shift in range(4):
    words = [struct.unpack_from("<I", d, i)[0] for i in range(shift, len(d) - 3, 4)]
    chars = []
    for w in words:
        c = w ^ 0xB6B6B6B6
        chars.append(chr(c) if 32 <= c < 127 else "\n")
    for m in re.findall(r"[A-Za-z_][A-Za-z0-9_]{3,}", "".join(chars)):
        found.add(m)
    # also plain (non-xored) utf-32 strings: constants
    chars2 = [chr(w) if 32 <= w < 127 else "\n" for w in words]
    for m in re.findall(r"[ -~]{6,}", "".join(chars2)):
        found.add("STR:" + m)
for name in sys.argv[2:]:
    print(name, "PRESENT" if name in found else "absent")
if len(sys.argv) == 2:
    print("\n".join(sorted(found)))
