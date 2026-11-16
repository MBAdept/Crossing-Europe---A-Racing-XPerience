#!/usr/bin/env python3
"""Reorders jobs4a.txt after the running job (lines up to and including RUNNING stay byte-identical): short natural
drives at the stage ends for medium / high / deck first, then the remaining look jobs. Empties jobs4b.txt (full-stage
drives dropped for time; kept as jobs4b_full.txt)."""
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN"
running = sys.argv[1]
lines = open(S + "/jobs4a.txt").read().splitlines()
names = [l.split("|")[0] for l in lines]
k = names.index(running)
head, rest = lines[:k + 1], lines[k + 1:]
by = {l.split("|")[0]: l for l in rest}
n0 = by["n0_med_erf_start"]
extra = [
    n0.replace("n0_med_erf_start", "n0_high_erf_start").replace("--gfx-preset=medium", "--gfx-preset=high").replace("--end-km=25", "--end-km=15"),
    n0.replace("n0_med_erf_start", "n0_deck_erf_start").replace("--gfx-preset=medium", "--gfx-preset=deck").replace("--end-km=25", "--end-km=15"),
]
order = ["n0_med_erf_start", "n0b_med_kas_end", "clip_a_noon", "clip_m_med_noon", "m_high_noon", "m_deck_noon", "m_med_dusk",
         "r0_med_dusk", "a_dusk", "m_med_low", "m_med_all", "r1_med_noon"]
new = head + [by["n0_med_erf_start"], by["n0b_med_kas_end"]] + extra + [by[n] for n in order[2:] if n in by]
open(S + "/jobs4a.txt", "w").write("\n".join(new) + "\n")
if os.path.getsize(S + "/jobs4b.txt") > 0:
    os.replace(S + "/jobs4b.txt", S + "/jobs4b_full.txt")
    open(S + "/jobs4b.txt", "w").close()
print([l.split("|")[0] for l in new])
