# common environment of QA-MID runs
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID
W=${W:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_a71eeb2e-3b7-1}
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
export LP_NUM_THREADS=2
mkdir -p $TMPDIR $MESA_SHADER_CACHE_DIR $S/logs $S/xdg
