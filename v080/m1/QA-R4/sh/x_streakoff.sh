#!/bin/bash
# Confirms the source of the red column above a far car at N2N 22:00 (frame at 4 s): same run with the vehicle
# lamp reflections on the wet road switched off (STREAK_GAIN 0) in the mutation copy.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3
F=scripts/race3d/layers/vehicles.gd
sed 's/^const STREAK_GAIN := 0.7 /const STREAK_GAIN := 0.0 /' $WT/$F > $S/mut/$F
grep -n '^const STREAK_GAIN' $S/mut/$F
ARGS=$($S/sh/pos.sh N2N)
mkdir -p $S/shots/mut
cd $S/mut || exit 2
export MESA_SHADER_CACHE_DIR=$S/mesa_mut
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh $S/shots/mut/N2N_streakoff $ARGS --shot-times=4
cp $WT/$F $S/mut/$F
echo "x_streakoff done"
