#!/usr/bin/env bash
# FIX-R5: complete Modern autopilot runs under Xvfb with perf_stats – this worktree (new) and the base copy 5558bdc (base),
# same arguments.   perf.sh new|base kh|u1
#   kh  Kiel – Hamburg from km 0 to the finish (Köhlbrandbrücke, Elbbrücken: water, banks, far water, pylons), "Mittel",
#       1280×720 – R5's run (m1/R5/tools/perf.sh)
#   u1  Bern – Mailand from km 183 for 600 s (Gotthard portal and tube), "deck", 1280×800 – QA-R5's QR5-09 run
F=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5
WHICH=${1:-new}
RUN=${2:-kh}
if [ "$WHICH" = base ]; then WT=$F/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6; fi
OUT=$F/perf
mkdir -p "$OUT" "$F/tmp"
X=$(mktemp -d "$F/tmp/xdg_perf.XXXXXX")
export MESA_SHADER_CACHE_DIR=$F/mesa_perf_$WHICH
mkdir -p "$MESA_SHADER_CACHE_DIR"
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
cd "$WT" || exit 1
t0=$SECONDS
if [ "$RUN" = u1 ]; then
	XDG_DATA_HOME="$X" nice -n $NICE timeout 1500 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=bern_mailand --from=bern \
		--start-km=183 --vehicle=limousine --hour=12 --weather=normal --seed=16 --timescale=4 --max-seconds=600 \
		--autopilot-refuel=auto --graphics=modern --gfx-preset=deck > "$OUT/${WHICH}_$RUN.log" 2>&1
else
	XDG_DATA_HOME="$X" nice -n $NICE timeout 6000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel \
		--vehicle=limousine --hour=12 --weather=normal --seed=11 --timescale=4 --max-seconds=5600 --autopilot-refuel=auto \
		--graphics=modern --gfx-preset=medium > "$OUT/${WHICH}_$RUN.log" 2>&1
fi
code=$?
rm -rf "$X"
echo "perf $WHICH $RUN: exit $code, $((SECONDS - t0)) s"
grep -E "^ERGEBNIS|^PERF|^RUN|SCRIPT ERROR|SHADER ERROR|Shader compilation failed|FEHLER" "$OUT/${WHICH}_$RUN.log" | cut -c1-600 | head -8
