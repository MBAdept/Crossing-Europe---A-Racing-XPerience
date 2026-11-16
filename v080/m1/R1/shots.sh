#!/usr/bin/env bash
# Scratch: a set of A/B pictures. Usage: shots.sh <tag> [preset]   (run from the worktree)
set -u
R1=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1
TAG=${1:-x}
PRESET=${2:-medium}
OUT=$R1/shots/$TAG
mkdir -p "$OUT" "$R1/tmp" "$R1/mesa"
export MESA_SHADER_CACHE_DIR=$R1/mesa TMPDIR=$R1/tmp GFX_ARGS="--gfx-preset=$PRESET"
shift 2 || true
for spec in "$@"; do
	name=${spec%%:*}
	args=${spec#*:}
	# shellcheck disable=SC2086
	tools/ab_shot.sh "$OUT/$name" $args 2>&1 | tail -1
	grep -E "SCRIPT ERROR|SHADER ERROR|^ERROR" "$OUT/${name}_modern.log" | head -5
done
