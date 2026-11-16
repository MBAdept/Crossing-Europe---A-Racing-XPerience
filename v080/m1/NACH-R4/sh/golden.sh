#!/bin/bash
# golden.sh – tools/golden.sh check once in the head worktree (TMPDIR in scratch), summary lines to stdout
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
cd "$WT" || exit 2
TMPDIR=$S/tmp MESA_SHADER_CACHE_DIR=$S/mesa_golden nice -n 10 tools/golden.sh check > $S/gates/golden.log 2>&1
r=$?
grep -E "GOLDEN" $S/gates/golden.log
exit $r
