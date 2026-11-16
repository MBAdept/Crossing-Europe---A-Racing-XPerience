#!/bin/bash
# AU-R4: heavy truck crashes (KRITIK-R2-MESS method), one run after the other, nice 19; each run analysed and its
# raw captures deleted. usage: run_truck.sh <seed>:<truck dB> ...
M=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R4/mess
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-4
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R4/xdg
cd "$W" || exit 1
for spec in "$@"; do
	seed=${spec%%:*}
	db=${spec##*:}
	tag="truck_${seed}_m${db#-}"
	echo "== $tag $(date +%H:%M:%S)"
	nice -n 19 timeout 900 godot --headless --path . --audio-driver Dummy -s $M/kr_crash.gd -- --graphics=arcade \
		--out=$M/$tag.wav --n=60 --rel=130 --heavy --seed=$seed --truck=$db > $M/$tag.log 2>&1
	echo "godot exit $?"
	grep 'kr_crash: 60' $M/$tag.log
	(cd $M && nice -n 19 python3 ana_crash.py crash $tag.wav $tag.json > $tag.ana.log 2>&1; python3 crash_p95.py $tag.json)
	rm -f $M/${tag}_pre.f32 $M/${tag}_post.f32 $M/$tag.wav
done
echo "== fertig $(date +%H:%M:%S)"
