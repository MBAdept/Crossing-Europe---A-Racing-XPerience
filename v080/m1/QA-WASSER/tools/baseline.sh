#!/usr/bin/env bash
# QA-WASSER: two stretches from the PROJECT at 0ad9012 (same Godot binary for both), once with the far_ground.gd of
# 3a23cb8 (before the fix, "old") and once with the committed one ("new") – Modern only:
#   senk      Kiel – Hamburg from km 66.8 at 120 km/h: the Köhlbrandbrücke enters the window at km 67.1, the plane sinks
#   holtenau  Kiel – Hamburg from Hamburg, km 75.5 at 120 km/h: the plane lies 12.3 m lower, the bridge is not in sight
# The old file is put back right after its runs (git checkout).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-2
F=scripts/race3d/layers/far_ground.gd
O=$S/shots_base
mkdir -p "$O"
cd "$W" || exit 1
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --hour=12 --gfx-preset=high --no-traffic"
SENK="--stage=kiel_hamburg --from=kiel --start-km=66.8 --start-speed=120 --shot-times=0.2,0.4,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.6,1.8,2.0"
HOLT="--stage=kiel_hamburg --from=hamburg --start-km=75.5 --start-speed=120 --shot-times=0.3,1.5"
export MESA_SHADER_CACHE_DIR=$S/mesa_project
mkdir -p "$MESA_SHADER_CACHE_DIR"
run() {   # run <name> <args>
	local name=$1
	shift
	local t0=$SECONDS
	export XDG_DATA_HOME=$S/xdg/base_$name
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"
	rm -f "$O/$name"_modern_[0-9][0-9].png
	# shellcheck disable=SC2086
	nice -n 5 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=$O/${name}_modern" $COMMON "$@" --graphics=modern \
		--gfx-sync > "$O/$name.log" 2>&1
	echo "$name exit $? ($((SECONDS - t0)) s), $(ls "$O/$name"_modern_[0-9][0-9].png 2>/dev/null | wc -l) Bilder"
}
git checkout -- "$F"
git show 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf:$F > "$F"
git diff --stat
# shellcheck disable=SC2086
run senk_old $SENK
# shellcheck disable=SC2086
run holtenau_old $HOLT
git checkout -- "$F"
git status --short
# shellcheck disable=SC2086
run senk_new $SENK
# shellcheck disable=SC2086
run holtenau_new $HOLT
git status --short
