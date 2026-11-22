# common environment of QA-RINT-BILD runs
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD
export D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-RINT-BILD
export W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-2
export TMPDIR=$S/tmp
export XDG_DATA_HOME=$S/xdg/default
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mkdir -p "$XDG_DATA_HOME" "$TMPDIR" "$MESA_SHADER_CACHE_DIR"
export AB_TIMEOUT=1500
