#!/usr/bin/env bash
# FIX-WASSER: one A/B run (Arcade | Modern) of the Köhlbrandbrücke stretch.
#   ab_one.sh <out_prefix> <preset> <hour> <start_km> <shot_times> [extra args…]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$S/mesa" "$(dirname "$1")"
OUT=$1
PRESET=$2
HOUR=$3
KM=$4
TIMES=$5
shift 5
GFX_ARGS="--gfx-preset=$PRESET" nice -n 10 tools/ab_shot.sh "$OUT" --stage=kiel_hamburg --from=kiel --hour="$HOUR" \
	--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown \
	--start-km="$KM" --start-speed=60 --no-traffic --shot-times="$TIMES" "$@"
