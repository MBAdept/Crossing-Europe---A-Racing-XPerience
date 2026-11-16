#!/bin/bash
# FIX-M2: occlusion probe (probe/qa_occl.gd of QA-M2-BILD) on this worktree.  occl.sh <mode> <tag> <args...>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5
O=$S/shots/occl
mkdir -p $O
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mode=$1 tag=$2
shift 2
x=$S/xdg/occ_$$
rm -rf "$x"; mkdir -p "$x"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$x nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $S/probe/qa_occl.gd -- \
	--graphics=$mode --gfx-sync --sound=arcade --out=$O --tag=$tag "$@" > "$O/$tag.log" 2>&1)
echo "$(date -u +%H:%M:%S) occ $mode $tag exit=$? $((SECONDS - t0)) s"
rm -rf "$x"
