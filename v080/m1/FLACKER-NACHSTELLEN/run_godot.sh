#!/bin/bash
# Runs Godot under Xvfb in the FLACKER-NACHSTELLEN worktree (nice 19, own XDG_DATA_HOME and Mesa shader cache).
#   run_godot.sh <log file> <timeout s> <godot args…>
# Waits while less than 3 GB of memory are available.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN
W=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_17007edf-ec9-1}
LOG=$1; shift
TO=$1; shift
for i in $(seq 1 30); do
	avail=$(free -g | awk '/^Mem:/ {print $7}')
	if [ "${avail:-0}" -ge 3 ]; then break; fi
	echo "waiting for memory (available ${avail} GB)" >> "$LOG.wait"
	sleep 60
done
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$W" || exit 1
SCREEN=${SCREEN:-1280x720}
nice -n 19 timeout "$TO" xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy "$@" > "$LOG" 2>&1
echo "EXIT $?" >> "$LOG"
