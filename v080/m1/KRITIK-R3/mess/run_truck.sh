#!/bin/bash
# KRITIK-R3: heavy truck crashes (KRITIK-R2-MESS method, kr_crash.gd) on the copy heads/r4 WITHOUT a level override
# (config of f253687: truck.heavy -11.5). One run after the other, nice 19; raw captures deleted after the analysis.
# usage: run_truck.sh <seed> ...
M=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3/mess
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3/heads/r4
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3/xdg/crash
mkdir -p $XDG_DATA_HOME
cd "$W" || exit 1
for seed in "$@"; do
	tag="truck_${seed}_r4"
	echo "== $tag $(date +%H:%M:%S)"
	nice -n 19 timeout 900 godot --headless --path . --audio-driver Dummy -s $M/kr_crash.gd -- --graphics=arcade \
		--out=$M/$tag.wav --n=60 --rel=130 --heavy --seed=$seed > $M/$tag.log 2>&1
	echo "godot exit $?"
	grep 'kr_crash:' $M/$tag.log
	(cd $M && nice -n 19 python3 ana_crash.py crash $tag.wav $tag.res.json > $tag.ana.log 2>&1; python3 crash_p95.py $tag.res.json)
	rm -f $M/${tag}_pre.f32 $M/${tag}_post.f32 $M/$tag.wav
done
echo "== fertig $(date +%H:%M:%S)"
