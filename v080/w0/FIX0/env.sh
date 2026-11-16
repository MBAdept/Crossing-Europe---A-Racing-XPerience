# Environment of the wave-0 fix runs (sourced by every command).
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
export F=$S/w0/FIX0
export L=$F/logs
export D=$S/deliver/FIX0
export W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-5
export XDG_DATA_HOME=$F/xdg
export MESA_SHADER_CACHE_DIR=$F/mesa_cache
export TMPDIR=$F/tmp
mkdir -p "$L" "$D" "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$TMPDIR"
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
