#!/usr/bin/env bash
# R5: a complete Modern autopilot run of Kiel – Hamburg (Köhlbrandbrücke, Elbbrücken: water, banks, far water, pylons) under Xvfb with
# perf_stats – the worktree and the base copy, same arguments.   perf.sh new|base
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WHICH=${1:-new}
if [ "$WHICH" = base ]; then WT=$R5/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2; fi
OUT=$R5/perf
mkdir -p "$OUT" "$R5/tmp"
X=$(mktemp -d "$R5/tmp/xdg_perf.XXXXXX")
export MESA_SHADER_CACHE_DIR=$R5/mesa
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
cd "$WT" || exit 1
t0=$SECONDS
XDG_DATA_HOME="$X" nice -n $NICE timeout 5400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel \
	--vehicle=limousine --hour=12 --weather=normal --seed=11 --timescale=4 --max-seconds=5000 --autopilot-refuel=auto \
	--graphics=modern --gfx-preset=medium > "$OUT/$WHICH.log" 2>&1
code=$?
rm -rf "$X"
echo "perf $WHICH: exit $code, $((SECONDS - t0)) s"
grep -E "^ERGEBNIS|^PERF|^RUN|SCRIPT ERROR|SHADER ERROR|Shader compilation failed|FEHLER" "$OUT/$WHICH.log" | cut -c1-600 | head -8
