# Environment of the wave-0 integration runs (sourced by every command).
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
export I=$S/w0/INTEG
export L=$I/logs
export D=$S/deliver/INTEG
export W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-5
export XDG_DATA_HOME=$I/xdg
export MESA_SHADER_CACHE_DIR=$I/mesa_cache
mkdir -p "$L" "$D" "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
