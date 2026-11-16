"""Decompress Godot RSCC (compressed binary resource) files and compare / inspect them."""
import struct, sys, zstandard

def decompress(path):
    data = open(path, "rb").read()
    assert data[:4] == b"RSCC", data[:4]
    mode, block, total = struct.unpack_from("<III", data, 4)
    assert mode == 2, mode
    n = (total + block - 1) // block
    sizes = struct.unpack_from("<%dI" % n, data, 16)
    off = 16 + 4 * n
    out = bytearray()
    d = zstandard.ZstdDecompressor()
    for i, s in enumerate(sizes):
        want = min(block, total - len(out))
        out += d.decompress(data[off:off + s], max_output_size=want)
        off += s
    assert len(out) == total, (len(out), total)
    return bytes(out)

if __name__ == "__main__":
    a = decompress(sys.argv[1])
    if len(sys.argv) > 2:
        b = decompress(sys.argv[2])
        diff = [i for i in range(min(len(a), len(b))) if a[i] != b[i]]
        print("sizes", len(a), len(b), "differing bytes:", len(diff), "at", diff[:24])
        if diff:
            lo, hi = diff[0], diff[-1]
            print("  a:", a[lo - 8:hi + 9].hex(" "))
            print("  b:", b[lo - 8:hi + 9].hex(" "))
    else:
        sys.stdout.buffer.write(a)
