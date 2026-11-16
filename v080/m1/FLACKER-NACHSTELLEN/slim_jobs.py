#!/usr/bin/env python3
"""Slims and reorders jobs4a.txt in place (line 1 = the running job stays byte-identical)."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN"
lines = open(S + "/jobs4a.txt").read().splitlines()
by = {l.split("|")[0]: l for l in lines}


def mod(name, rep=()):
    l = by[name]
    for a, b in rep:
        assert a in l, (name, a)
        l = l.replace(a, b)
    return l


H = "--sets=traffic/hatch_white"
W2 = "--sets=traffic/hatch_white,traffic/wagon_white"
S2 = "--mode=sweep --far=44 --near=34 --step=0.2"
S1 = "--mode=sweep --far=44 --near=34 --step=0.1"
CF = ("--clip-frames=300", "--clip-frames=240")
new = [lines[0],
       mod("r0_med_noon", [(W2, H), (S1, S2)]),
       by["a_noon"],
       mod("clip_r0_med_noon", [CF]),
       by["n0_med_erf_start"],
       mod("clip_a_noon", [CF]),
       mod("clip_m_med_noon", [CF]),
       mod("m_high_noon", [(W2, H), ("--far=65 --near=55 --step=0.1", "--far=64 --near=55 --step=0.2")]),
       mod("m_deck_noon", [(W2, H), (S1, S2)]),
       mod("m_med_dusk", [(W2, H), (S1, S2)]),
       mod("r0_med_dusk", [(S1, S2)]),
       mod("a_dusk", [(W2, H), (S1, S2)]),
       mod("m_med_low", [(W2, H), (S1, S2)]),
       mod("m_med_all", [("--far=43 --near=37 --step=0.1", "--far=43 --near=37 --step=0.2")]),
       mod("r1_med_noon", [(S1, S2)])]
open(S + "/jobs4a.txt", "w").write("\n".join(new) + "\n")
for l in new:
    print(l.split("|")[0], [t for t in l.split() if t.startswith(("--sets", "--step", "--clip-frames", "--far"))])
