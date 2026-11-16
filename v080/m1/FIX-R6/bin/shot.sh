#!/usr/bin/env bash
# FIX-R6: A/B shot at nice 10 with a shared warm Mesa cache.
# usage: [WT=<project dir>] shot.sh <out_prefix> [args…]   (GFX_ARGS default: --gfx-preset=high)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3}
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR" "$(dirname "$1")"
export GFX_ARGS=${GFX_ARGS:---gfx-preset=high}
export AB_TIMEOUT=${AB_TIMEOUT:-2400}
cd "$WT" || exit 1
exec nice -n 10 tools/ab_shot.sh "$@"
