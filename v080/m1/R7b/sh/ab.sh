#!/usr/bin/env bash
# wrapper: ab_shot with own TMPDIR and mesa cache, nice, memory guard
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
cd ${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2}
exec nice -n 10 tools/ab_shot.sh "$@"
