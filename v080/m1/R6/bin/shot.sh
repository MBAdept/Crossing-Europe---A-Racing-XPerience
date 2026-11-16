#!/usr/bin/env bash
# R6 wrapper: A/B shot at low priority with a shared, warm Mesa cache.
# usage: shot.sh <out_prefix> [args…]   (GFX_ARGS default: --gfx-preset=high)
R6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1}
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
export MESA_SHADER_CACHE_DIR=$R6/mesa
export GFX_ARGS=${GFX_ARGS:---gfx-preset=high}
export AB_TIMEOUT=${AB_TIMEOUT:-2400}
cd "$WT" || exit 1
exec nice -n "$NICE" tools/ab_shot.sh "$@"
