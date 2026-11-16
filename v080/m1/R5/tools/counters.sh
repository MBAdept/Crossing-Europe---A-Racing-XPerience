#!/usr/bin/env bash
# R5: draw calls / primitives at R5 positions (scratch_gd/r5_scratch_counters.gd), worktree and base.  counters.sh new|base
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WHICH=${1:-new}
if [ "$WHICH" = base ]; then WT=$R5/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2; fi
mkdir -p $R5/perf $R5/tmp
cp $R5/scratch_gd/r5_scratch_counters.gd $WT/r5_scratch_counters.gd
X=$(mktemp -d "$R5/tmp/xdg_cnt.XXXXXX")
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
cd $WT || exit 1
XDG_DATA_HOME="$X" MESA_SHADER_CACHE_DIR=$R5/mesa nice -n $NICE timeout 2400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s res://r5_scratch_counters.gd -- \
	--graphics=modern --gfx-sync --audio-sync --gfx-preset=medium > $R5/perf/counters_$WHICH.log 2>&1
echo "counters $WHICH: exit $?"
rm -rf "$X"
rm -f $WT/r5_scratch_counters.gd $WT/r5_scratch_counters.gd.uid
grep -E "COUNTERS|SCRIPT ERROR" $R5/perf/counters_$WHICH.log
