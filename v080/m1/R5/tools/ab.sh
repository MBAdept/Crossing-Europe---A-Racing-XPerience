#!/usr/bin/env bash
# R5 picture helper: ab.sh <out_dir> <name> <preset> <race args...>
# runs tools/ab_shot.sh at nice 19 (nice 10 once QA_M2_FERTIG exists) with a shared Mesa cache; Modern gets
# --gfx-preset=<preset>. WT = the project folder to run (default: the R5 worktree; the base copy for baselines).
set -uo pipefail
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2}
OUT=$1; NAME=$2; PRESET=$3; shift 3
mkdir -p "$OUT" "$R5/mesa"
export MESA_SHADER_CACHE_DIR=$R5/mesa
export TMPDIR=$R5/tmp
mkdir -p "$TMPDIR"
cd "$WT" || exit 1
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
GFX_ARGS="--gfx-preset=$PRESET ${EXTRA_GFX:-}" nice -n $NICE tools/ab_shot.sh "$OUT/$NAME" "$@"
