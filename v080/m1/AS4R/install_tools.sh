#!/usr/bin/env bash
# AS4R scratch: puts the review tools (KRITIK-4 / AS3 prop scene with the race look) UNTRACKED into tools/kritik/ of
# the worktree. Never committed; removed by remove_tools.sh before the test suite.
set -euo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
T=$WT/tools/kritik
mkdir -p "$T"
cp "$S/tools_kritik/prop_scene_as3.gd" "$T/prop_scene_as3.gd"
sed 's#extends "res://tools/models/prop_scene.gd"#extends "res://tools/kritik/prop_scene_as3.gd"#' \
	"$S/tools_kritik/kritik_scene.gd" > "$T/kritik_scene.gd"
for f in k4_scene.gd mesh_probe.gd texel_probe.gd positions.gd; do
	cp "$S/tools_kritik/$f" "$T/$f"
done
cp "$S/census_all.gd" "$T/census_all.gd"
[ -f "$S/my_scene.gd" ] && cp "$S/my_scene.gd" "$T/my_scene.gd"
[ -f "$S/pylon_census.gd" ] && cp "$S/pylon_census.gd" "$T/pylon_census.gd"
ls "$T"
