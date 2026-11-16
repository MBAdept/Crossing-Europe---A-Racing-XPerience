#!/usr/bin/env bash
# AS5a1 scratch: one run of the KRITIK-4 scene (untracked tools/kritik/k4_scene.gd or a scene extending it).
#   k4.sh <out.png> <script basename> [scene args...]      e.g. k4.sh $S/shots/x.png k4_scene --mode=close --items=...
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
OUT="$1"; SCRIPT="$2"; shift 2
while true; do
	AV=$(free -g | awk '/^Mem:/{print $7}')
	if [ "${AV:-0}" -ge 3 ]; then break; fi
	echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
done
nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s "res://tools/kritik/$SCRIPT.gd" -- --out="$OUT" "$@" 2>&1 | grep -E "k4_scene|tint_scene|my_scene|FLIMMER|UMSCHALT|STUFEN|UMRISS|SCRIPT ERROR|Parse Error|FEHLER|kein" | head -40
