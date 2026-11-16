#!/usr/bin/env bash
# KRITIK-R2-CODE: ERGEBNIS of two stages with the autopilot, headless, one run at a time (nice 19):
#   gA = graphics arcade + sound arcade, gS = graphics arcade + sound modern, gM = graphics modern + sound modern
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE
TREE=$S/heads/r3
OUT=$S/res/ergebnis
mkdir -p "$OUT" "$S/xdg/erg"
cd "$TREE" || exit 2
for st in "kiel_hamburg kiel" "regensburg_nuernberg nuernberg"; do
	set -- $st
	for mode in "gA arcade arcade" "gS arcade modern" "gM modern modern"; do
		set -- $st $mode
		stage=$1; from=$2; tag=$3; gfx=$4; snd=$5
		log="$OUT/${stage}_${tag}.log"
		XDG_DATA_HOME="$S/xdg/erg" nice -n 19 timeout 1500 godot --headless --path . -s res://tests/race/run_stage.gd -- \
			--stage="$stage" --from="$from" --vehicle=limousine --hour=8 --weather=normal --timescale=40 --seed=7 \
			--graphics="$gfx" --sound="$snd" --max-seconds=1400 > "$log" 2>&1
		echo "$stage $tag exit $? $(grep -c '^ERGEBNIS' "$log") ergebnis; $(grep -E '^RUN ' "$log" | cut -c1-160)"
	done
done
