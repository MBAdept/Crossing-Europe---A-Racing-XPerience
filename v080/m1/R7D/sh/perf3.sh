#!/bin/bash
# R7D final perf (resumable) on 6092197, alone on the machine: Kiel – Hamburg autopilot runs (gates.sh perf's command), three
# rounds, head and base alternating per preset; then the head without the new sky (graphics.modern.sky2d false)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
G=$S/gates/perf3; mkdir -p $G
one() {   # one <tag> <tree dir> <preset> <override json|->
	local tag=$1 T=$2 pre=$3 ov=$4 out=$G/$1.log
	grep -q '^PERF ' $out 2>/dev/null && return
	local x=$S/xdg/perf_$tag; rm -rf $x; mkdir -p $x
	if [ "$ov" != "-" ]; then
		for app in "Crossing Europe – A Racing Xperience" "Crossing Europe - A Racing Xperience"; do
			mkdir -p "$x/godot/app_userdata/$app"; echo "$ov" > "$x/godot/app_userdata/$app/game_config.json"
		done
	fi
	(cd "$T" && XDG_DATA_HOME=$x nice -n 10 timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel \
		--hour=12 --weather=normal --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=$pre > $out 2>&1)
	echo "$(date +%T) perf3 $tag exit $?" >> $S/logs/perf3.log
	rm -rf $x
}
for r in 1 2 3; do
	for pre in deck medium high; do
		one head_${pre}_r$r $W $pre -
		one base_${pre}_r$r $S/base $pre -
	done
done
for r in 1 2 3; do
	for pre in deck medium; do
		one skyoff_${pre}_r$r $W $pre '{"graphics": {"modern": {"sky2d": false}}}'
	done
done
echo "PERF3 DONE $(date +%T)" >> $S/logs/perf3.log
