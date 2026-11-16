#!/usr/bin/env bash
# usage: ab.sh <name> [race args…]   (env SCREEN, GFX_ARGS as for tools/ab_shot.sh)
# A/B pictures of the merged tree into shots/<name>_*, nice 10, own Mesa cache, log in logs/ab_<name>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2
name=$1; shift
mkdir -p "$S/shots" "$S/logs" "$S/mesa"
cd "$W" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa
start=$(date +%s)
AB_TIMEOUT=${AB_TIMEOUT:-900} nice -n 10 tools/ab_shot.sh "$S/shots/$name" "$@" > "$S/logs/ab_$name.log" 2>&1
code=$?
echo "== $name exit=$code secs=$(( $(date +%s) - start ))" | tee -a "$S/logs/ab_$name.log"
