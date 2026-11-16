#!/usr/bin/env python3
"""AU-R3: Python model of AudioFeed.unit_hash (djb2 String.hash + murmur3 fmix32) and of cobbled_blocks with
optional skipped stretches (bridges without a stone deck), to explore geometries offline. The game code is the
truth; this model is checked against the reference values of test_unit_hash_mixes_neighbouring_keys."""
import math
import sys

M = 0xFFFFFFFF


def djb2(s):
    h = 5381
    for ch in s:
        h = ((h << 5) + h + ord(ch)) & M
    return h


def unit_hash(key):
    h = djb2(key)
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & M
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & M
    h ^= h >> 16
    return (h >> 8) / float(0x1000000)


def blocks(city, centre_m, block_m, share, skip=()):
    n = max(int(math.ceil(centre_m / block_m - 1e-6)), 1)
    w = []
    for b in range(n):
        a0 = b * block_m
        a1 = min(a0 + block_m, centre_m)
        x = min(block_m, centre_m - b * block_m)
        for s0, s1 in skip:
            x -= max(min(a1, s1) - max(a0, s0), 0.0)
        w.append(max(x, 0.0))
    streets = sum(w) if skip else centre_m
    order = sorted(range(n), key=lambda b: unit_hash(f"{city}|{b}"))
    target = share * streets
    got = 0.0
    out = [False] * n
    for b in order:
        if abs(got + w[b] - target) < abs(got - target):
            got += w[b]
            out[b] = True
    return out, w, got, streets


def main():
    ref = {"hamburg|0": 0.3253776431083679, "hamburg|1": 0.7149350643157959, "A7|Holstein": 0.48531436920166016}
    for k, v in ref.items():
        assert abs(unit_hash(k) - v) < 1e-9, (k, unit_hash(k), v)
    print("hash model ok")
    if len(sys.argv) > 1:
        city = sys.argv[1]
        centre = float(sys.argv[2])
        skip = []
        for a in sys.argv[3:]:
            s0, s1 = a.split(":")
            skip.append((float(s0), float(s1)))
        old, w0, got0, _ = blocks(city, centre, 90.0, 0.6)
        new, w, got, streets = blocks(city, centre, 90.0, 0.6, skip)
        st_old = sum(w[b] for b in range(len(w)) if old[b])
        print("old", "".join("P" if x else "-" for x in old), "street share %.3f" % (st_old / streets))
        print("new", "".join("P" if x else "-" for x in new), "street share %.3f (%.0f of %.0f m)" % (got / streets, got, streets))


if __name__ == "__main__":
    main()
