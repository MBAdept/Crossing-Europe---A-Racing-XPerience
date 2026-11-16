#!/usr/bin/env bash
# M2INT: tools/ab_shot.sh with niceness (19 until ZS1_FERTIG, then 10), a warm shared Mesa cache, logs in scratch.
# usage: ab.sh <out_prefix_abs> [position] [args...]   (GFX_ARGS / SCREEN pass through)
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$MESA_SHADER_CACHE_DIR" "$(dirname "$1")"
cd "$WT"
t0=$(date +%s)
nice -n $NICE tools/ab_shot.sh "$@"
code=$?
echo "ab_shot exit $code ($(( $(date +%s) - t0 )) s, nice $NICE)"
grep -hE "SCRIPT ERROR|ERROR:|Fehler|fiel zurück" "$1"_arcade.log "$1"_modern.log 2>/dev/null | head -10
exit $code
