#!/bin/bash
# ab.sh <name> <POS> <preset> [extra args...] – tools/ab_shot.sh in the head worktree (Arcade + Modern), nice 10
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
NAME=$1; POS=$2; PRESET=$3; shift 3
ARGS=$("$S/sh/pos.sh" "$POS") || exit 2
export MESA_SHADER_CACHE_DIR=$S/mesa_head TMPDIR=$S/tmp
cd "$WT" || exit 2
t0=$SECONDS
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=$PRESET ${GFX_EXTRA:-}" SCREEN=${SCREEN:-1280x720} nice -n ${NICE:-10} tools/ab_shot.sh "$S/shots/head/$NAME" $ARGS "$@"
echo "ab.sh $NAME exit=$? $((SECONDS-t0))s"
