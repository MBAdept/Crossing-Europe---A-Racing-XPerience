#!/bin/bash
# ab.sh <head|base> <name> <POS> <preset> [extra args...] – one A/B pair with tools/ab_shot.sh (nice 10)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
WHICH=$1; NAME=$2; POS=$3; PRESET=$4; shift 4
if [ "$WHICH" = base ]; then WT=$S/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3; fi
OUTDIR=$S/shots/$WHICH
mkdir -p "$OUTDIR"
ARGS=$("$S/sh/pos.sh" "$POS") || exit 2
export MESA_SHADER_CACHE_DIR=$S/mesa_$WHICH
cd "$WT" || exit 2
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=$PRESET ${GFX_EXTRA:-}" SCREEN=${SCREEN:-1280x720} nice -n ${NICE:-10} tools/ab_shot.sh "$OUTDIR/$NAME" $ARGS "$@"
echo "ab.sh $WHICH $NAME exit=$?"
