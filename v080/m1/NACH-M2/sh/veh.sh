#!/bin/bash
# NACH-M2: vehicle probe (QA-M2-BILD probe/qa_vehicles.gd, copy of FIX-M2) on head (515dd51) or base (6e48405).
#   veh.sh head|base <mode> <tag> <args...>  -> shots/veh/<tag>_<scene>.png, <tag>.log
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
P=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_vehicles.gd
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6
[ "$1" = base ] && WT=$N/base
O=$N/shots/veh
export MESA_SHADER_CACHE_DIR=$N/mesa
export LP_NUM_THREADS=2
mode=$2 tag=$3
shift 3
if grep -q "QA-VEH-END" "$O/$tag.log" 2> /dev/null; then echo "skip $tag"; exit 0; fi
x=$N/xdg/veh_$$
rm -rf "$x"; mkdir -p "$x"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$x nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $P -- \
	--graphics=$mode --gfx-sync --sound=arcade --out=$O --tag=$tag "$@" > "$O/$tag.log" 2>&1)
echo "$(date -u +%H:%M:%S) veh $mode $tag exit=$? $((SECONDS - t0)) s pics=$(ls $O/${tag}_*.png 2> /dev/null | wc -l)"
rm -rf "$x"
