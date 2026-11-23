#!/bin/bash
# NACH-R7a occlusion probe (FIX-M2 qa_occl.gd, test car in three lanes): occl.sh <head|m3> <C1|T4|T3>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
which=$1; name=$2
wt=$WT
[ "$which" = m3 ] && wt=$S/m3
case "$name" in
T3) a="--stage=saragossa_pau --from=saragossa --km=172.8 --hour=11 --vehicle=kompakt --seed=4" ;;
T4) a="--stage=saragossa_pau --from=saragossa --km=198.8 --hour=11 --vehicle=kompakt --seed=4" ;;
C1) a="--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15" ;;
esac
probe=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_occl.gd
o=$S/occl
mkdir -p "$o" "$S/mesa" "$S/tmp"
x=$S/xdg/occ_$name_$which
rm -rf "$x"; mkdir -p "$x"
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
t0=$SECONDS
# shellcheck disable=SC2086
(cd "$wt" && XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$probe" -- \
	--graphics=modern --gfx-preset=high --gfx-sync --sound=arcade --out="$o" --tag="${name}_$which" \
	--dists=25,55,85,120,150,200,270 $a > "$o/${name}_$which.log" 2>&1)
echo "$(date -u +%H:%M:%S) occl $which $name exit=$? $((SECONDS - t0)) s"
rm -rf "$x"
