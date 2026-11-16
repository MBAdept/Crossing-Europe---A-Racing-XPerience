#!/bin/bash
# RINT-M2: vehicle probe (QA-M2-BILD/FIX-M2 probe/qa_vehicles.gd + --eye_spec) on a tree.
#   veh.sh <tree: wt|merged|path> <mode> <tag> <args...>  -> shots/veh/<tag>_<scene>.png, <tag>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
case "$1" in
wt) WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1 ;;
merged) WT=$S/merged ;;
[A-H]) WT=$S/snap_$1 ;;
*) WT=$1 ;;
esac
O=$S/shots/veh
mkdir -p $O
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mode=$2 tag=$3
shift 3
x=$S/xdg/veh_$$
rm -rf "$x"; mkdir -p "$x"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$x nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $S/probe/qa_vehicles.gd -- \
	--graphics=$mode --gfx-sync --sound=arcade --out=$O --tag=$tag "$@" > "$O/$tag.log" 2>&1)
echo "$(date -u +%H:%M:%S) veh $mode $tag exit=$? $((SECONDS - t0)) s pics=$(ls $O/${tag}_*.png 2> /dev/null | wc -l)"
rm -rf "$x"
