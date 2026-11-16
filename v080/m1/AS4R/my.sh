#!/usr/bin/env bash
# AS4R scratch: run tools/kritik/k4_scene.gd (untracked review tool) under Xvfb.  k4.sh <name> <args...>
# -> $S/shots/<name>.png, log $S/logs/<name>.log
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$TMPDIR" "$S/shots" "$S/logs"
cd "$WT"
name=$1; shift
start=$(date +%s)
timeout 3000 nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/kritik/my_scene.gd -- "--out=$S/shots/$name.png" "$@" > "$S/logs/$name.log" 2>&1
rc=$?
echo "$name exit $rc $(( $(date +%s) - start )) s"
grep -E "^(FLIMMER|UMRISS|STUFEN|STUFE|UMSCHALT|PEGEL|SPRUNG|SZENE|my_scene|k4_scene|kritik_scene|prop_scene)|ERROR|SCRIPT|Parse" "$S/logs/$name.log" | awk '!seen[$0]++' | head -60
