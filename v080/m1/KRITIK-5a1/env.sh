# KRITIK-5a1 scratch environment (source me)
export K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
export T=$K/tree
export DL=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-5a1
export XDG_DATA_HOME=$K/xdg
export MESA_SHADER_CACHE_DIR=$K/mesa
export TMPDIR=$K/tmp
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$TMPDIR" "$K/shots" "$K/logs" "$DL"
waitmem() { while true; do AV=$(free -g | awk '/^Mem:/{print $7}'); [ "${AV:-0}" -ge 3 ] && break; echo "wenig Speicher ($AV GB) - warte 60 s"; sleep 60; done; }
