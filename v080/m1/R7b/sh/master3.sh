#!/usr/bin/env bash
# R7b: rest of the queue after the gates (replaces master2.sh, which only waited for gates.sh):
# the changed Modern golden modern_s4_mittel kept on head and on base, Brussels on base (row of houses), near views,
# Madrid and Dortmund night redo.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
echo "master3 start $(date -u +%H:%M)"
while pgrep -f "sh/gates.sh" > /dev/null; do sleep 20; done
echo "GATES_DONE $(date -u +%H:%M)"
export TMPDIR=$S/tmp MESA_SHADER_CACHE_DIR=$S/mesa
for tree in head base; do
	T=$WT
	[ "$tree" = base ] && T=$S/base
	rm -rf "$S/golden_s4_$tree"
	mkdir -p "$S/golden_s4_$tree"
	guard
	(cd "$T" && KEEP="$S/golden_s4_$tree" nice -n 10 tools/golden.sh modern-check modern_s4 > "$S/golden_s4_$tree.log" 2>&1)
	echo "golden s4 $tree exit $?: $(grep -E '^GOLDEN' $S/golden_s4_$tree.log)"
done
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
mkdir -p $S/basecmp
WT=$S/base GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$S/basecmp/bruessel_12_base" --stage=koeln_bruessel --from=koeln --start-km=206.4 --hour=12 $COMMON 2>&1 | tail -2
echo "brussels base done $(date -u +%H:%M)"
rm -f $S/batch3.log
$S/sh/batch3.sh > $S/batch3.log 2>&1
echo "batch3 done $(date -u +%H:%M)"
GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$D/ab/madrid_22" --stage=burgos_madrid --from=burgos --start-km=228.0 --hour=22 $COMMON 2>&1 | tail -2
GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$D/ab/dortmund_22" --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=22 $COMMON 2>&1 | tail -2
echo "MASTER3_DONE $(date -u +%H:%M)"
