# common environment for RINT-A helper scripts (source it)
export WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A
export D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-A
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/logs" "$D"
cd "$WT" || exit 1
