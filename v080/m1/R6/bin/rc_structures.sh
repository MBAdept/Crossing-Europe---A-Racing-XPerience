#!/usr/bin/env bash
# R6: the render checks of the structures alone, pictures kept in shots/rc/.
# Usage: rc_structures.sh [file stem: check_structures | check_structures_licht] [--only list]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
mkdir -p "$S/shots/rc" "$S/xdg/rc"
export MESA_SHADER_CACHE_DIR=$S/mesa
export XDG_DATA_HOME=$S/xdg/rc
cd "$WT" || exit 1
FILE=${1:-check_structures}
ONLY=${2:-}
EXTRA=()
[ -n "$ONLY" ] && EXTRA=("--only=$ONLY")
T0=$SECONDS
nice -n "$NICE" timeout 5400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s "res://tests/race3d/render/$FILE.gd" -- --graphics=modern --gfx-sync --audio-sync \
	"--save=$S/shots/rc" "${EXTRA[@]}"
echo "exit $? ($((SECONDS - T0)) s)"
