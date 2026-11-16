#!/usr/bin/env bash
# Scratch: the A/B set of R1 (S1–S5 by day, dawn / dusk / night on the open Autobahn). Usage: shots_set.sh <tag> [preset]
# Run from the worktree. Heavy: one pair at a time, nice -n 10.
set -u
R1=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1
TAG=${1:-set}
PRESET=${2:-high}
OUT=$R1/shots/$TAG
mkdir -p "$OUT" "$R1/tmp" "$R1/mesa"
export MESA_SHADER_CACHE_DIR=$R1/mesa TMPDIR=$R1/tmp GFX_ARGS="--gfx-preset=$PRESET"
run() {
	local name=$1
	shift
	nice -n 10 tools/ab_shot.sh "$OUT/$name" "$@" 2>&1 | tail -1
	grep -E "SCRIPT ERROR|SHADER ERROR|^ERROR" "$OUT/${name}_modern.log" | head -5
}
run s1 S1
run s2 S2
run s3 S3
run s4 S4
run s5 S5
run dawn S1 --hour=6.3
run dusk S1 --hour=19.4
run night S1 --hour=23
run rain S3 --weather=rain
