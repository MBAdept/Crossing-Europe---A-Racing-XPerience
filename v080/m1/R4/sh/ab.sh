#!/bin/bash
# ab.sh <outdir> <name> <POS> <preset> [extra args...]  – one A/B pair with tools/ab_shot.sh, nice 19, shared mesa cache
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
OUTDIR=$1; NAME=$2; POS=$3; PRESET=$4; shift 4
mkdir -p "$OUTDIR"
ARGS=$("$R4/sh/pos.sh" "$POS") || exit 2
export MESA_SHADER_CACHE_DIR=$R4/mesa
NICE=${NICE:-19}
cd "$WT" || exit 2
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=$PRESET ${GFX_EXTRA:-}" SCREEN=${SCREEN:-1280x720} nice -n $NICE tools/ab_shot.sh "$OUTDIR/$NAME" $ARGS "$@"
