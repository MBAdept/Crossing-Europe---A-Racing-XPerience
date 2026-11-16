#!/usr/bin/env python3
"""AU-R3: allocation variants for the old towns with a bridge without a stone deck, from data/cities.json
(bridges count from the finish; tunnels are per stage and not modelled here):
  greedy  = AU-R's greedy in hash order over the street metres (the AU-R3 fix as committed)
  swap    = greedy, then the best single add / remove / swap of blocks while it brings the street metres nearer
            to the target (ties: the move found first in hash order) – only where a stretch is cut.
Shares: alloc = allocated street metres / (centre − non-stone bridges) (stone bridges count as streets, as in the
allocation); street = allocated metres off every bridge / metres off every bridge (stone bridges counted apart)."""
import json
import math
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3/tools")
from alloc_model import unit_hash  # noqa: E402

TREE = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-1"
STYLES = ["hanse", "german_old", "bavarian", "dutch", "belgian", "paris", "french", "french_south", "italian", "vienna",
          "austrian", "swiss", "central", "eastern", "baltic", "balkan", "spanish", "spanish_north"]
DECK = {"cable_stayed": "steel", "truss_arch": "steel", "stone_arch": "stone"}


def weights(centre_m, block_m, skip):
    n = max(int(math.ceil(centre_m / block_m - 1e-6)), 1)
    w = []
    for b in range(n):
        a0 = b * block_m
        x = min(block_m, centre_m - a0)
        cut = sum(max(min(a0 + x, s1) - max(a0, s0), 0.0) for s0, s1 in skip)
        w.append(max(x - cut, 0.0) if cut > 0 else x)
    return w


def greedy(city, w, target):
    order = sorted(range(len(w)), key=lambda b: unit_hash(f"{city}|{b}"))
    got, out = 0.0, [False] * len(w)
    for b in order:
        if abs(got + w[b] - target) < abs(got - target):
            got += w[b]
            out[b] = True
    return out, got, order


def improve(w, target, out, got, order):
    while True:
        best = abs(got - target)
        move = None
        for i in order:            # remove i / swap i for j
            for j in [None] + order:
                if j is not None and (out[j] or j == i):
                    continue
                if not out[i]:
                    continue
                g = got - w[i] + (w[j] if j is not None else 0.0)
                if abs(g - target) < best - 1e-6:
                    best, move = abs(g - target), (i, j, g)
        for j in order:            # add j
            if out[j]:
                continue
            g = got + w[j]
            if abs(g - target) < best - 1e-6:
                best, move = abs(g - target), (None, j, g)
        if move is None:
            return out, got
        i, j, g = move
        if i is not None:
            out[i] = False
        if j is not None:
            out[j] = True
        got = g


def closer(w, target, out, got, order, band):
    """Mirror of AudioFeed._closer (GDScript order): while |got - target| > band, the best single move – for each
    block in hash order: if taken, drop it or swap it for a block not taken (in hash order); if not taken, add it."""
    for _ in range(len(w) * 2):
        err = abs(got - target)
        if err <= band:
            break
        best, take, drop = err, -1, -1
        for i in order:
            if out[i]:
                g = got - w[i]
                if abs(g - target) < best - 1e-6:
                    best, take, drop = abs(g - target), -1, i
                for j in order:
                    if out[j]:
                        continue
                    g2 = got - w[i] + w[j]
                    if abs(g2 - target) < best - 1e-6:
                        best, take, drop = abs(g2 - target), j, i
            else:
                g3 = got + w[i]
                if abs(g3 - target) < best - 1e-6:
                    best, take, drop = abs(g3 - target), i, -1
        if take < 0 and drop < 0:
            break
        if drop >= 0:
            out[drop] = False
            got -= w[drop]
        if take >= 0:
            out[take] = True
            got += w[take]
    return out, got


def main():
    db = json.load(open(f"{TREE}/data/cities.json"))
    rows = []
    for cid, e in sorted(db["cities"].items()):
        if e.get("style") not in STYLES:
            continue
        centre = float(e.get("center_km", db.get("center_km", 8.0))) * 100.0
        ns, st = [], []
        for b in e.get("bridges", []):
            t1 = float(b["km_to_finish"]) * 100.0
            s = (t1 - float(b["length_m"]), t1)
            if s[0] >= centre:
                continue
            (st if DECK.get(b["type"], "concrete") == "stone" else ns).append(s)
        if not ns:
            continue
        w = weights(centre, 90.0, ns)
        base = centre - sum(min(s1, centre) - max(s0, 0.0) for s0, s1 in ns)
        target = 0.6 * base
        g_out, g_got, order = greedy(cid, w, target)
        if "--band" in sys.argv:
            s_out, s_got = closer(w, target, list(g_out), g_got, order, 0.05 * base)
        else:
            s_out, s_got = improve(w, target, list(g_out), g_got, order)
        stone_in = [(max(s0, 0.0), min(s1, centre)) for s0, s1 in st]
        stone_m = sum(b - a for a, b in stone_in)

        def street_share(out):
            cob = 0.0
            for b, x in enumerate(out):
                if not x:
                    continue
                a0, a1 = b * 90.0, min(b * 90.0 + 90.0, centre)
                cob += w[b] - sum(max(min(a1, s1) - max(a0, s0), 0.0) for s0, s1 in stone_in)
            return cob / (base - stone_m)
        rows.append((cid, centre, base, stone_m, g_got / base, s_got / base, street_share(g_out), street_share(s_out),
                     "".join("P" if x else "-" for x in g_out), "".join("P" if x else "-" for x in s_out)))
    print(f"{'Stadt':14s} {'Altst':>6s} {'Basis':>6s} {'Stein':>5s} | greedy alloc/straße | swap alloc/straße | Muster greedy -> swap")
    bad_g = bad_s = 0
    for r in rows:
        fg = abs(r[4] - 0.6) > 0.05 + 1e-9
        fs = abs(r[5] - 0.6) > 0.05 + 1e-9
        bad_g += fg
        bad_s += fs
        print(f"{r[0]:14s} {r[1]:6.0f} {r[2]:6.0f} {r[3]:5.0f} | {r[4]:.3f}{'!' if fg else ' '} / {r[6]:.3f} | {r[5]:.3f}{'!' if fs else ' '} / {r[7]:.3f} | {r[8]} -> {r[9]}")
    print(f"außerhalb 0,6 ± 0,05 (Zuteilungssicht): greedy {bad_g}, swap {bad_s} von {len(rows)}")


if __name__ == "__main__":
    main()
