#!/bin/bash
# QA-M2-BILD: occlusion probe (probe/qa_occl.gd) – red hatch at 40…270 m in three lanes, Arcade vs Modern (high, and
# ZS1 high for comparison) at bend positions with trees. Output shots/occl/<tag>_*.png + <tag>.log. Idempotent.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
O=$S/shots/occl
mkdir -p $O
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
occ() {   # occ <tree> <mode> <tag> <args...>
	local tree=$1 mode=$2 tag=$3
	shift 3
	local wt=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
	[ "$tree" = zs1 ] && wt=$S/zs1tree
	if grep -q "QA-OCC-END" "$O/$tag.log" 2> /dev/null; then echo "skip occ $tag"; return; fi
	local x=$S/xdg/occ_$$
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	(cd "$wt" && XDG_DATA_HOME=$x nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $S/probe/qa_occl.gd -- \
		--graphics=$mode --gfx-sync --sound=arcade --out=$O --tag=$tag "$@" > "$O/$tag.log" 2>&1)
	echo "$(date -u +%H:%M:%S) occ $tree $mode $tag exit=$? $((SECONDS - t0)) s"
	rm -rf "$x"
}
T4="--stage=saragossa_pau --from=saragossa --km=198.8 --hour=11 --vehicle=kompakt --seed=4"
T3="--stage=saragossa_pau --from=saragossa --km=172.8 --hour=11 --vehicle=kompakt --seed=4"
T1="--stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --vehicle=kombi --seed=12"
W1="--stage=dortmund_frankfurt --from=dortmund --km=121.4 --hour=16 --vehicle=gran_turismo --seed=14"
D="--dists=25,40,55,70,85,100,130,170,220,270"
for p in T4 T3 T1 W1; do
	eval "A=\$$p"
	occ m2 arcade "${p}_arcade" $A $D
	occ m2 modern "${p}_m2high" $A $D --gfx-preset=high
done
# ZS1 comparison runs dropped (time; the corridor rule is the same in ZS1)
