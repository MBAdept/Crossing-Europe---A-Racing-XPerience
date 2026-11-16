#!/bin/bash
# wprobe.sh <id> <args…> – the instrumented cold-cache warm-up probe (tests/race3d/render/warm_probe_tmp.gd, NOT committed)
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
N=${NICE:-10}
ID=$1
shift
mkdir -p "$R4/warm"
cd "$WT" || exit 2
rm -rf "$R4/warm/mesa_$ID" "$R4/warm/xdg_$ID"
mkdir -p "$R4/warm/mesa_$ID" "$R4/warm/xdg_$ID"
MESA_SHADER_CACHE_DIR=$R4/warm/mesa_$ID XDG_DATA_HOME=$R4/warm/xdg_$ID nice -n $N timeout 1500 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s "${PROBE:-res://tests/race3d/render/warm_probe_tmp.gd}" -- --graphics=modern "$@" > "$R4/warm/$ID.log" 2>&1
echo "exit=$?" >> "$R4/warm/$ID.log"
grep -a "RENDER-CHECK\|SCRIPT ERROR\|PROBE NEW" "$R4/warm/$ID.log" | cut -c1-400 | head -12
[ -z "${KEEP_XDG:-}" ] && rm -rf "$R4/warm/xdg_$ID"
