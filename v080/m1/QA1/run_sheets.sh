#!/bin/bash
# QA1: A/B sheets of all reference positions, high + the machine's own preset (tools/ab_sheet.sh).
# usage: run_sheets.sh [positions...]   (PRESETS env passes through)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
OUT=$S/m1/QA1/ab
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/m1/QA1/mesa_ab
mkdir -p "$MESA_SHADER_CACHE_DIR"
cd "$WT" || exit 1
t0=$SECONDS
PRESETS=${PRESETS:-high auto} tools/ab_sheet.sh "$OUT" "$@" > "$OUT/sheet_run_$(date +%H%M%S).log" 2>&1
echo "ab_sheet exit=$? $((SECONDS - t0)) s"
cat "$OUT/index.txt"
echo ALLDONE
