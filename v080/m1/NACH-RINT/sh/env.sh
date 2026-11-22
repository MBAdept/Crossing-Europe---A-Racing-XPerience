# common environment of NACH-RINT runs
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT
export DL=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/NACH-RINT
export HEAD_W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-5
export BASE_W=$S/base
export W=${W:-$HEAD_W}
export TMPDIR=$S/tmp
export XDG_DATA_HOME=$S/xdg/default
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mkdir -p "$XDG_DATA_HOME" "$TMPDIR" "$MESA_SHADER_CACHE_DIR"
export AB_TIMEOUT=1800
