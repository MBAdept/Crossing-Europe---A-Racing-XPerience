# AS5aR1 scratch environment (source me)
export S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
export WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-6
export DL=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR2
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$TMPDIR" "$S/shots" "$S/logs" "$DL"
waitmem() { while true; do AV=$(free -g | awk '/^Mem:/{print $7}'); [ "${AV:-0}" -ge 3 ] && break; echo "wenig Speicher ($AV GB) - warte 60 s"; sleep 60; done; }
