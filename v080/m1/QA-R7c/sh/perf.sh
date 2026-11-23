#!/bin/bash
# QA-R7c perf: whole autopilot stages (tests/race/run_stage.gd) under Xvfb with perf_stats, R7c vs 43a1fcc (base +
# AS5aR2, the fair reference for R7c's own code) vs 9b02f05 (the base of the brief). Steam Deck preset at 1280x800.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
mkdir -p "$S/perf"
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
	echo "$(date -u +%H:%M:%S) perf $tag $(tail -1 "$S/perf/$tag.log") err=$(grep -c 'SCRIPT ERROR\|SHADER ERROR' "$S/perf/$tag.log")" >> "$S/logs/q3.out"
}
mkdir -p "$S/mesa_perf"
# warm-up of the shader cache for both trees (discarded)
stage warm_r7c "$WT" deck wuerzburg_nuernberg wuerzburg 12 60
stage warm_merge "$S/merge" deck wuerzburg_nuernberg wuerzburg 12 60
stage warm_base "$S/base" deck wuerzburg_nuernberg wuerzburg 12 60
stage kh_deck_r7c_1 "$WT" deck kiel_hamburg kiel 12 20
stage kh_deck_merge_1 "$S/merge" deck kiel_hamburg kiel 12 20
stage kh_deck_base_1 "$S/base" deck kiel_hamburg kiel 12 20
stage kh_deck_r7c_2 "$WT" deck kiel_hamburg kiel 12 20
stage kh_deck_merge_2 "$S/merge" deck kiel_hamburg kiel 12 20
stage wn_deck_r7c_1 "$WT" deck wuerzburg_nuernberg wuerzburg 12 20
stage wn_deck_merge_1 "$S/merge" deck wuerzburg_nuernberg wuerzburg 12 20
stage kh_high_r7c_1 "$WT" high kiel_hamburg kiel 12 20
stage kh_high_merge_1 "$S/merge" high kiel_hamburg kiel 12 20
