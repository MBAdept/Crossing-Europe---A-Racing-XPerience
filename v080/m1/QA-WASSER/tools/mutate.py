#!/usr/bin/env python3
"""Apply one named mutation to scripts/race3d/layers/far_ground.gd (QA-WASSER: is the unit test a real guard?).

usage: mutate.py <far_ground.gd> <M0|M1|M2|M3|M4>
  M0  no change (control)
  M1  the old rule: the plane ignores the water again (target = lowest road - drop)
  M2  no margin: the plane lies exactly at the water surface (WATER_MARGIN_M = 0)
  M3  no glide: the plane snaps to its target every frame (a jump when the bridge enters the window)
  M4  the plane lies 0.5 m lower everywhere (no longer the old rule away from deep water)
"""
import sys

path, name = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
edits = {
    "M0": [],
    "M1": [("\t\t_target = target_height(path, track, cam_z, vis)\n",
            "\t\t_target = lowest_road(path, cam_z, vis) - _drop\n")],
    "M2": [("const WATER_MARGIN_M := 0.3 ", "const WATER_MARGIN_M := 0.0 ")],
    "M3": [("\tif not _valid or moved > SNAP_M:\n", "\tif true:\n")],
    "M4": [("\treturn minf(lowest_road(path, cam_z, visibility_m) - _drop, water_y - WATER_MARGIN_M)\n",
            "\treturn minf(lowest_road(path, cam_z, visibility_m) - _drop, water_y - WATER_MARGIN_M) - 0.5\n")],
}[name]
for old, new in edits:
    if src.count(old) != 1:
        sys.exit("mutation %s: pattern not found exactly once: %r" % (name, old))
    src = src.replace(old, new)
open(path, "w", encoding="utf-8").write(src)
print("applied", name, len(edits), "edit(s)")
