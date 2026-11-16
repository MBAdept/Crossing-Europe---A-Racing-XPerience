#!/usr/bin/env bash
# usage: ab_start.sh <out_prefix> [extra race args…]  – A/B shots of a standing start at km 0 (countdown) at
# 1 s, 3 s (countdown) and 3.7 / 4.5 / 7 s (0.7 / 1.5 / 4 s after "LOS!"), Modern on "Mittel".
set -uo pipefail
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
OUT=$1
shift
export MESA_SHADER_CACHE_DIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR"
GFX_ARGS="${GFX_ARGS:---gfx-preset=medium}" nice -n 5 tools/ab_shot.sh "$OUT" --stage=kiel_hamburg --from=kiel --hour=12 \
	--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup \
	--shot-times=1,3,3.7,4.5,7 "$@"
