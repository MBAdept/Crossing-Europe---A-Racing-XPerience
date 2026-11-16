#!/usr/bin/env bash
# AS5aR1: review tools UNTRACKED into tools/kritik/ of the worktree (never committed; rm -rf before run_tests)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1/env.sh
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
mkdir -p "$S/kt" "$S/py"
cp -n "$K"/tools_kritik/* "$S/kt/"
cp -n /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R/tools_kritik/prop_scene_as3.gd "$S/kt/"
cp -n "$K"/py/* "$S/py/"
T=$WT/tools/kritik
mkdir -p "$T"
cp "$S/kt/prop_scene_as3.gd" "$T/prop_scene_as3.gd"
sed 's#extends "res://tools/models/prop_scene.gd"#extends "res://tools/kritik/prop_scene_as3.gd"#' "$S/kt/kritik_scene.gd" > "$T/kritik_scene.gd"
for f in k4_scene.gd k5_scene.gd my_scene.gd mesh_probe.gd texel_probe.gd texel_k5.gd positions.gd census_all.gd census_k5.gd tint_scene.gd; do
  if [ -f "$S/kt/$f" ]; then cp "$S/kt/$f" "$T/$f"; fi
done
ls "$T"
