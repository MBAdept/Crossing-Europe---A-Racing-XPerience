#!/bin/bash
# FIX-R7c perf: whole autopilot stages (tests/race/run_stage.gd) under Xvfb with perf_stats, FIX-R7c (this tree) vs
# R7c bd1803b (m1/FIX-R7c/ref, the base of the brief). Steam Deck preset at 1280x800. perf.sh [suffix]
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
SUF=${1:-}
mkdir -p "$S/perf" "$S/mesa_perf"
stage() {   # stage <tag> <tree> <preset> <stage> <from> <hour> <timescale>
	local tag=$1 tree=$2 q=$3 st=$4 from=$5 h=$6 ts=$7
	if grep -q "^RUN " "$S/perf/$tag.log" 2>/dev/null; then
		return 0
	fi
	memwait
	local x=$S/xdg_perf_$tag
	rm -rf "$x"
	mkdir -p "$x"
	local scr=1280x720
	[ "$q" = "deck" ] && scr=1280x800
	local t0=$SECONDS
	(cd "$tree" && XDG_DATA_HOME=$x MESA_SHADER_CACHE_DIR=$S/mesa_perf nice -n 10 timeout 3600 xvfb-run -a -s "-screen 0 ${scr}x24" \
		godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution "$scr" -s res://tests/race/run_stage.gd -- \
		--graphics=modern --gfx-preset="$q" --stage="$st" --from="$from" --vehicle=limousine --hour="$h" --weather=normal --seed=11 \
		--timescale="$ts" --max-seconds=5000 > "$S/perf/$tag.log" 2>&1)
	echo "exit=$? wall=$((SECONDS - t0))" >> "$S/perf/$tag.log"
	rm -rf "$x"
	echo "$(date -u +%H:%M:%S) perf $tag $(tail -1 "$S/perf/$tag.log") err=$(grep -c 'SCRIPT ERROR\|SHADER ERROR' "$S/perf/$tag.log")" >> "$S/logs/perf.out"
}
stage warm_fix$SUF "$WT" deck wuerzburg_nuernberg wuerzburg 12 60
stage warm_ref$SUF "$S/ref" deck wuerzburg_nuernberg wuerzburg 12 60
stage kh_deck_fix_1$SUF "$WT" deck kiel_hamburg kiel 12 20
stage kh_deck_ref_1$SUF "$S/ref" deck kiel_hamburg kiel 12 20
stage kh_deck_fix_2$SUF "$WT" deck kiel_hamburg kiel 12 20
stage kh_deck_ref_2$SUF "$S/ref" deck kiel_hamburg kiel 12 20
echo "PERF DONE $SUF" >> "$S/logs/perf.out"
