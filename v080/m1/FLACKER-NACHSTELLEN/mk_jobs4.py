#!/usr/bin/env python3
"""Writes the run-4 job files.
jobs4a.txt: switch look (probe_switch2.gd): Modern / Arcade, forced refusal, clips, presets, light, colours.
jobs4b.txt: natural drives (probe_drive.gd, cheap: 320x180, no pictures, ts 3).
jobs4m.txt: the essentials again on the M2 head (after git checkout --detach 6e48405 + import)."""
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN"
P = f"{S}/gd/follow_pilot.gd"
R = f"{S}/runs4"
W = f"{S}/sw4"
SW = f"--resolution 1280x720 --fixed-fps 60 -s {S}/gd/probe_switch2.gd -- --wait=80"
BASE = "--stage=erfurt_kassel --from=erfurt --start-km=30 --crop=440,230,400,240 --gfx-sync"
WHITE = "--sets=traffic/hatch_white,traffic/wagon_white"
OTHERS = ("--sets=traffic/hatch_red,traffic/hatch_blue,traffic/hatch_green,traffic/hatch_yellow,traffic/sedan_black,"
          "traffic/sedan_blue,traffic/sedan_red,traffic/sedan_silver,traffic/wagon_darkblue,traffic/wagon_green,traffic/wagon_silver")
M = "--gfx=modern --graphics=modern"
A = "--gfx=arcade --graphics=arcade"
SWEEP = "--mode=sweep --far=44 --near=34 --step=0.1"
CLIP = "--mode=clip --centre=40 --amp=3.5 --period=2.4 --clip-frames=300 --sets=traffic/hatch_white"


def jobs(tag, out_w):
    return [
        f"{tag}m_med_noon|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 {WHITE} {SWEEP} --out={out_w}/{tag}m_med_noon",
        f"{tag}r0_med_noon|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 {WHITE} {SWEEP} --refuse=lod0 --out={out_w}/{tag}r0_med_noon",
        f"{tag}a_noon|2400|{out_w}|{SW} {A} {BASE} --hour=12 {WHITE} {SWEEP} --out={out_w}/{tag}a_noon",
        f"{tag}clip_r0_med_noon|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 {CLIP} --refuse=lod0 --out={out_w}/{tag}clip_r0_med_noon",
        f"{tag}clip_m_med_noon|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 {CLIP} --out={out_w}/{tag}clip_m_med_noon",
        f"{tag}clip_a_noon|2400|{out_w}|{SW} {A} {BASE} --hour=12 {CLIP} --out={out_w}/{tag}clip_a_noon",
        f"{tag}m_high_noon|2400|{out_w}|{SW} {M} --gfx-preset=high {BASE} --hour=12 {WHITE} --mode=sweep --far=65 --near=55 --step=0.1 --full-d=60 --out={out_w}/{tag}m_high_noon",
        f"{tag}m_deck_noon|2400|{out_w}|{SW} {M} --gfx-preset=deck {BASE} --hour=12 {WHITE} {SWEEP} --out={out_w}/{tag}m_deck_noon",
        f"{tag}m_med_low|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=17.5 {WHITE} {SWEEP} --out={out_w}/{tag}m_med_low",
        f"{tag}m_med_dusk|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=20.5 {WHITE} {SWEEP} --out={out_w}/{tag}m_med_dusk",
        f"{tag}r0_med_dusk|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=20.5 --sets=traffic/hatch_white {SWEEP} --refuse=lod0 --out={out_w}/{tag}r0_med_dusk",
        f"{tag}a_dusk|2400|{out_w}|{SW} {A} {BASE} --hour=20.5 {WHITE} {SWEEP} --out={out_w}/{tag}a_dusk",
        f"{tag}r1_med_noon|2400|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 --sets=traffic/hatch_white {SWEEP} --refuse=lod1 --out={out_w}/{tag}r1_med_noon",
        f"{tag}m_med_all|3600|{out_w}|{SW} {M} --gfx-preset=medium {BASE} --hour=12 {OTHERS} --mode=sweep --far=43 --near=37 --step=0.1 --out={out_w}/{tag}m_med_all",
    ]


D = (f"--resolution 320x180 --fixed-fps 60 -s {S}/gd/probe_drive.gd -- --graphics=modern --no-watchdog --stage=erfurt_kassel "
     f"--ts=3 --pilot={P} --prefer=_white --res=320x180 --sim-s=1500 --shots=0 --start-km=0 --end-km=155")
b = [
    f"n1_med_erf|7200|{R}|{D} --gfx-preset=medium --from=erfurt --hour=13 --out={R}/n1_med_erf",
    f"n2_med_kas|7200|{R}|{D} --gfx-preset=medium --from=kassel --hour=17 --out={R}/n2_med_kas",
    f"n3_high_erf|7200|{R}|{D} --gfx-preset=high --from=erfurt --hour=17 --out={R}/n3_high_erf",
    f"n4_deck_kas|7200|{R}|{D} --gfx-preset=deck --from=kassel --hour=13 --out={R}/n4_deck_kas",
]
open(f"{S}/jobs4a.txt", "w").write("\n".join(jobs("", W)) + "\n")
open(f"{S}/jobs4b.txt", "w").write("\n".join(b) + "\n")
m2 = [j for j in jobs("M2_", f"{S}/sw4m") if any(k in j.split("|")[0] for k in ("m_med_noon", "r0_med_noon", "clip_r0", "m_high_noon", "m_deck_noon"))]
m2 = [j.replace(WHITE, WHITE + ",traffic/suv_white,traffic/van_white") if "|" in j and "clip" not in j.split("|")[0] else j for j in m2]
open(f"{S}/jobs4m.txt", "w").write("\n".join(m2) + "\n")
print("ok")
