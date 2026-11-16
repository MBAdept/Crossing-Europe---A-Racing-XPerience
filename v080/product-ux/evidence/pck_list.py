#!/usr/bin/env python3
"""Lists the files of a Godot 4.7 PCK embedded in an executable (or a bare .pck): path, size.
Usage: pck_list.py <file> [--tsv out.tsv]"""
import struct, os, sys

def read_pck(path):
    sz = os.path.getsize(path)
    with open(path, 'rb') as f:
        f.seek(0)
        start = 0
        if f.read(4) != b'GDPC':
            f.seek(sz - 12)
            tail = f.read(12)
            pck_size, = struct.unpack('<Q', tail[:8])
            assert tail[8:] == b'GDPC', 'no embedded pck'
            start = sz - 12 - pck_size
        f.seek(start)
        magic = f.read(4)
        assert magic == b'GDPC'
        ver, major, minor, patch, flags = struct.unpack('<5I', f.read(20))
        file_base, = struct.unpack('<Q', f.read(8))
        dir_off = None
        if ver >= 3:
            dir_off, = struct.unpack('<Q', f.read(8))
        f.read(64)
        if dir_off is not None:
            f.seek(start + dir_off)
        count, = struct.unpack('<I', f.read(4))
        files = []
        for _ in range(count):
            plen, = struct.unpack('<I', f.read(4))
            p = f.read(plen).rstrip(b'\0').decode('utf-8')
            off, size = struct.unpack('<QQ', f.read(16))
            f.read(16)
            fl, = struct.unpack('<I', f.read(4))
            files.append((p, size, off, fl))
        return dict(start=start, ver=ver, godot=(major, minor, patch), flags=flags, file_base=file_base,
                    dir_off=dir_off, count=count, total=sz, engine=start), files

if __name__ == '__main__':
    info, files = read_pck(sys.argv[1])
    print(info, file=sys.stderr)
    out = sys.stdout
    if '--tsv' in sys.argv:
        out = open(sys.argv[sys.argv.index('--tsv') + 1], 'w')
    for p, size, off, fl in sorted(files):
        out.write(f"{size}\t{p}\n")
