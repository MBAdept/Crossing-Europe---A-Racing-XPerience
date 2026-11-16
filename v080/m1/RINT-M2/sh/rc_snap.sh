#!/bin/bash
# RINT-M2: one render check file on a snapshot tree.
#   rc_snap.sh <tree: A|B|C|merged|path> <tag> <check file basename without .gd> [check args...]
#   -> logs/rc_<tag>.log, pictures in shots/rc_<tag>/ when the check supports --save
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
case "$1" in
merged) T=$S/merged ;;
[A-H]) T=$S/snap_$1 ;;
*) T=$1 ;;
esac
TAG=$2; F=$3; shift 3
x=$S/xdg/rc_$$
rm -rf "$x"; mkdir -p "$x" $S/shots/rc_$TAG
export XDG_DATA_HOME="$x"   # absolute, empty, under the scratch dir (never the real user folder)
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$T" || exit 2
t0=$SECONDS
nice -n 10 timeout ${TO:-1800} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "res://tests/race3d/render/$F.gd" -- --graphics=modern \
	--gfx-sync --audio-sync --save=$S/shots/rc_$TAG "$@" > $S/logs/rc_$TAG.log 2>&1
code=$?
echo "$(date -u +%H:%M:%S) rc $1 $TAG $F exit=$code $((SECONDS - t0))s"
grep -E "^RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|Too many instances" $S/logs/rc_$TAG.log | head -20
rm -rf "$x"
