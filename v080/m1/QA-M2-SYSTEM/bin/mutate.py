#!/usr/bin/env python3
"""Applies or reverts one named mutation in the scratch copy (never in the gate worktree).
Usage: mutate.py <tree> <mutation id> apply|revert|list
Each mutation breaks exactly one line of production code; revert restores the file from the gate worktree."""
import os
import shutil
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4"

MUT = {
    # check_vehicles "kasten": a set without a model is drawn as its stand-in, never missing
    "kasten_sprite": ("scripts/race3d/layers/vehicles.gd",
                      "\t\t_update_sprite(car, c, info, is_player, path, track, cam_z, vis, lights, time, sim_dt, length)\n\t\treturn",
                      "\t\t_show(car, false)\n\t\treturn"),
    "kasten_box": ("scripts/race3d/layers/vehicles.gd",
                   "\t\tif lod == \"box\":\n\t\t\tn = ModelFactory.build_box(car.set_id, _mats)",
                   "\t\tif lod == \"box\":\n\t\t\tn = null"),
    # check_vehicles "leistung": no node built while the same cars drive on (built levels are kept for reuse)
    "leistung_cache": ("scripts/race3d/layers/vehicles.gd",
                       "\t\tcar.levels[lod] = n\n",
                       "\t\tpass  # QA mutation: car.levels[lod] = n\n"),
    # check_vehicles "leistung": no level freed for the instance budget
    "leistung_trim": ("scripts/race3d/layers/vehicles.gd",
                      "const INSTANCE_BUDGET := 128",
                      "const INSTANCE_BUDGET := 8"),
    # test_props: the bridge pylon model is dark at night (night_albedo), without the night atlas (emit_energy 0)
    "props_pylon_albedo": ("scripts/race3d/builders/props.gd",
                           "\t\tdup.set_shader_parameter(\"night_albedo\", PYLON_NIGHT_ALBEDO)\n", "\t\tpass\n"),
    "props_pylon_emit": ("scripts/race3d/builders/props.gd",
                         "\t\tdup.set_shader_parameter(\"emit_energy\", 0.0)\n", "\t\tpass\n"),
    # test_props: the landmarks without sprite or model get the fallback set of their plan entry
    "props_landmark": ("scripts/race3d/builders/props.gd",
                       "\t\tif lm.has(\"proc\") and str(lm.get(\"fallback\", \"\")) != \"\":",
                       "\t\tif lm.has(\"proc\") and str(lm.get(\"fallback\", \"\")) == \"<none>\":"),
    # test_props: the aviation light blinks like Arcade's (two sides 0.4 s apart)
    "props_blink": ("scripts/race3d/layers/flares.gd",
                    "\treturn night > BLINK_MIN_NIGHT and fposmod(time + b.z, b.x) < b.y",
                    "\treturn night > BLINK_MIN_NIGHT and fposmod(time - b.z, b.x) < b.y"),
    # test_props: the stand-in pylon (no model) has no light layer
    "props_standin_dark": ("scripts/race3d/builders/props.gd",
                           "\tmat.set_shader_parameter(\"lights_rect\", Vector4.ZERO)\n", "\tpass\n"),
    # test_terrain_builder / test_far_ground_water (rewritten in the ZS1 merge): the far ground lies below the water
    "farground_water": ("scripts/race3d/layers/far_ground.gd",
                        "\treturn minf(lowest_road(path, cam_z, visibility_m) - _drop, water_y - WATER_MARGIN_M)",
                        "\treturn lowest_road(path, cam_z, visibility_m) - _drop"),
    # Modern goldens: a small, visible change of the Modern picture (sun disc of the race? no: the road shader)
    # Modern goldens, effective variant: the lane-line width the road builder hands to the shader (the shader default
    # above is overwritten at run time – that first mutation changed nothing in the picture)
    "golden_lane": ("scripts/race3d/builders/road.gd",
                    "\tmaterial.set_shader_parameter(\"lane_line_w\", _lane_line)",
                    "\tmaterial.set_shader_parameter(\"lane_line_w\", _lane_line * 1.2)"),
    "golden_road": ("assets/shaders/modern/road.gdshader",
                    "uniform float lane_line_w = 0.15;", "uniform float lane_line_w = 0.17;"),
}


def main():
    tree, mid, op = sys.argv[1], sys.argv[2], sys.argv[3]
    if os.path.realpath(tree) == os.path.realpath(WT):
        print("REFUSED: never in the gate worktree")
        sys.exit(2)
    if op == "list":
        print(" ".join(MUT))
        return
    rel, old, new = MUT[mid]
    dst = os.path.join(tree, rel)
    if op == "revert":
        shutil.copyfile(os.path.join(WT, rel), dst)
        print("reverted", rel)
        return
    s = open(dst).read()
    if old is None:
        print("no automatic mutation for", mid)
        sys.exit(2)
    n = s.count(old)
    if n != 1:
        print("MUTATION %s: pattern found %d times in %s" % (mid, n, rel))
        sys.exit(2)
    open(dst, "w").write(s.replace(old, new))
    print("applied", mid, "to", rel)


main()
