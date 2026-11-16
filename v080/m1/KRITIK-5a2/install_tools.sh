#!/usr/bin/env bash
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2/env.sh
SRC=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1/kt
P=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1/py
mkdir -p "$K/kt" "$K/py"
cp -n "$SRC"/* "$K/kt/"
cp -n "$P"/* "$K/py/"
D=$T/tools/kritik
mkdir -p "$D"
cp "$K/kt/prop_scene_as3.gd" "$D/prop_scene_as3.gd"
sed 's#extends "res://tools/models/prop_scene.gd"#extends "res://tools/kritik/prop_scene_as3.gd"#' "$K/kt/kritik_scene.gd" > "$D/kritik_scene.gd"
for f in k6_scene.gd k4_scene.gd k5_scene.gd my_scene.gd mesh_probe.gd texel_probe.gd texel_k5.gd positions.gd census_all.gd census_k5.gd tint_scene.gd; do
  if [ -f "$K/kt/$f" ]; then cp "$K/kt/$f" "$D/$f"; fi
done
ls "$D"
