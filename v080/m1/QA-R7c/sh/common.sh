#!/bin/bash
# QA-R7c common settings
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-7
BASE=$S/base
MUT=$S/mut
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
export XDG_DATA_HOME=$S/xdg
mkdir -p "$S/mesa" "$S/tmp" "$S/xdg" "$D" "$S/gates" "$S/logs"
memwait() {
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
}
