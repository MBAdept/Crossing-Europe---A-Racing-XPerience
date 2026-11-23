#!/bin/bash
# QA-R7c: R7c's/KRITIK's review scene (k6_scene --mode=lodcol, installed untracked in the mutation copy) - lod0 | lod1 |
# sprite of models at distances in the race look.   k6.sh <name> <k6 args...>
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
NAME=$1
shift
mkdir -p "$S/k6"
memwait
cd "$MUT" || exit 1
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_k6 nice -n 10 timeout 2400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy -s res://tools/kritik/k6_scene.gd -- "--out=$S/k6/$NAME.png" "$@" > "$S/k6/$NAME.log" 2>&1
echo "$(date -u +%H:%M:%S) k6 $NAME exit=$? $((SECONDS - t0)) s" | tee -a "$S/logs/k6.out"
grep -E "^LODCOL|SCRIPT ERROR|SHADER ERROR|Parse" "$S/k6/$NAME.log" | head -60
