#!/bin/bash
# One Modern run of the race scene with screenshots (like the modern half of tools/ab_shot.sh) and an own XDG folder,
# so a user://game_config.json override can be put there:   mshot.sh <out_prefix> <xdg_dir> <race args...>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
out="$1"; shift
xdg="$1"; shift
mkdir -p "$(dirname "$out")" "$xdg"
start=$(date +%s)
XDG_DATA_HOME="$xdg" nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=$out" "$@" \
	--graphics=modern --gfx-sync > "$out.log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s"
grep -E "SCRIPT ERROR|SHADER ERROR|Modus Modern nicht|Overrides geladen" "$out.log" | head -5
ls "$out"_*.png 2>/dev/null
