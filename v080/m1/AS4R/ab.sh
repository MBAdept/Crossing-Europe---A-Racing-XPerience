#!/usr/bin/env bash
# AS4R scratch: one A/B run (Arcade | Modern) with tools/ab_shot.sh.   ab.sh <name> <preset> <race args...>
# -> $S/ab/<name>_ab_NN.jpg, logs $S/ab/<name>_{arcade,modern}.log; checks the Modern log for script errors
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
OUT=$S/ab
mkdir -p "$OUT" "$S/mesa_ab" "$S/tmp"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export TMPDIR=$S/tmp
cd "$WT"
name=$1; preset=$2; shift 2
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
t0=$(date +%s)
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=$preset" AB_TIMEOUT=1200 nice -n 19 tools/ab_shot.sh "$OUT/$name" "$@" $BASE 2>&1 | tail -3
echo "=== $name $(( $(date +%s) - t0 )) s; Skriptfehler im Modern-Protokoll: $(grep -cE 'SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed' "$OUT/${name}_modern.log" 2>/dev/null)"
ls "$OUT/${name}"_ab_*.jpg 2>/dev/null
