#!/bin/bash
# post.sh – after the gates: a second head stage run (load noise) and the night-rain clip with traffic (N2N, 20 s)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5
G=$S/gates
until grep -q GATES_DONE $G/gates.log 2>/dev/null; do sleep 30; done
echo "== stage_head2 start $(date -u +%T)" >> $G/gates.log
$S/sh/stage.sh head2 $WT > $G/stage_head2.log 2>&1
echo "== stage_head2 exit=$? $(date -u +%T)" >> $G/gates.log
mkdir -p $S/clips
cd $WT || exit 2
ARGS=$($S/sh/pos.sh N2N)
echo "== clip N2N start $(date -u +%T)" >> $G/gates.log
# shellcheck disable=SC2086
MESA_SHADER_CACHE_DIR=$S/mesa GFX_ARGS="--gfx-preset=high" CLIP_S=20 nice -n 10 tools/ab_clip.sh $S/clips/N2N.mp4 $ARGS > $S/clips/N2N.out 2>&1
echo "== clip N2N exit=$? $(date -u +%T)" >> $G/gates.log
echo POST_DONE >> $G/gates.log
