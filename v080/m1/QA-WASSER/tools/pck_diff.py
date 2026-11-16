#!/usr/bin/env python3
"""Compare the PCK directories (path, size, md5) of two exported Godot executables.

usage: pck_diff.py <exe_a> <exe_b>
Prints every path that is new, gone or whose md5/size differs, and the counts.
"""
import struct
import sys

PCK_MAGIC = b"GDPC"


def directory(path):
    import os
    total = os.path.getsize(path)
    out = {}
    with open(path, "rb") as f:
        if f.read(4) == PCK_MAGIC:
            start = 0          # a bare .pck
        else:
            f.seek(total - 12)
            tail = f.read(12)
            if tail[8:] != PCK_MAGIC:
                raise SystemExit("%s: no embedded PCK" % path)
            (pck_size,) = struct.unpack("<Q", tail[:8])
            start = total - 12 - pck_size
        f.seek(start)
        if f.read(4) != PCK_MAGIC:
            raise SystemExit("bad PCK start")
        version, major, minor, patch, flags = struct.unpack("<5I", f.read(20))
        (file_base,) = struct.unpack("<Q", f.read(8))
        (dir_offset,) = struct.unpack("<Q", f.read(8))
        f.read(64)
        f.seek(start + dir_offset)
        (count,) = struct.unpack("<I", f.read(4))
        for _ in range(count):
            (plen,) = struct.unpack("<I", f.read(4))
            name = f.read(plen).rstrip(b"\0").decode("utf-8", "replace")
            offset, size = struct.unpack("<QQ", f.read(16))
            md5 = f.read(16).hex()
            (fflags,) = struct.unpack("<I", f.read(4))
            out[name] = (size, md5)
    return out


a = directory(sys.argv[1])
b = directory(sys.argv[2])
changed = [n for n in sorted(set(a) & set(b)) if a[n] != b[n]]
new = sorted(set(b) - set(a))
gone = sorted(set(a) - set(b))
for n in changed:
    print("CHANGED", n, a[n][0], "->", b[n][0])
for n in new:
    print("NEW", n, b[n][0])
for n in gone:
    print("GONE", n, a[n][0])
print("files a=%d b=%d changed=%d new=%d gone=%d" % (len(a), len(b), len(changed), len(new), len(gone)))
