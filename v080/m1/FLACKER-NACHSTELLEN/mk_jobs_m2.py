#!/usr/bin/env python3
"""Writes jobs4m.txt: the essentials on the M2 head (run after git checkout --detach 6e48405 + import)."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN"
W = f"{S}/sw4m"
R = f"{S}/runs4m"
SW = f"--resolution 1280x720 --fixed-fps 60 -s {S}/gd/probe_switch2.gd -- --wait=80"
BASE = "--stage=erfurt_kassel --from=erfurt --start-km=30 --crop=440,230,400,240 --gfx-sync --hour=12"
M = "--gfx=modern --graphics=modern"
A = "--gfx=arcade --graphics=arcade"
S2 = "--mode=sweep --far=44 --near=34 --step=0.2"
P = f"{S}/gd/follow_pilot.gd"
jobs = [
    f"M2_m_med_noon|3600|{W}|{SW} {M} --gfx-preset=medium {BASE} --sets=traffic/hatch_white,traffic/suv_white,traffic/van_white {S2} --out={W}/M2_m_med_noon",
    f"M2_r0_med_noon|3600|{W}|{SW} {M} --gfx-preset=medium {BASE} --sets=traffic/hatch_white,traffic/suv_white {S2} --refuse=lod0 --out={W}/M2_r0_med_noon",
    f"M2_a_noon|2400|{W}|{SW} {A} {BASE} --sets=traffic/hatch_white,traffic/suv_white,traffic/van_white {S2} --out={W}/M2_a_noon",
    f"M2_m_high_noon|2400|{W}|{SW} {M} --gfx-preset=high {BASE} --sets=traffic/hatch_white --mode=sweep --far=64 --near=55 --step=0.2 --full-d=60 --out={W}/M2_m_high_noon",
    f"M2_m_deck_noon|2400|{W}|{SW} {M} --gfx-preset=deck {BASE} --sets=traffic/hatch_white {S2} --out={W}/M2_m_deck_noon",
    f"M2_n0_med_erf_start|3600|{R}|--resolution 320x180 --fixed-fps 60 -s {S}/gd/probe_drive.gd -- --graphics=modern --no-watchdog "
    f"--stage=erfurt_kassel --ts=2 --pilot={P} --prefer=_white --res=320x180 --sim-s=1500 --shots=0 --start-km=0 --end-km=25 "
    f"--gfx-preset=medium --from=erfurt --hour=13 --out={R}/M2_n0_med_erf_start",
]
open(f"{S}/jobs4m.txt", "w").write("\n".join(jobs) + "\n")
print("ok", len(jobs))
