#!/bin/bash
# bench.sh <name> <preset> <override-json|-> [scene] : the built-in Leistungstest (--bench) of one scene under Xvfb
# (llvmpipe), with an optional user://game_config.json override; prints the scene's numbers.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
name=$1 preset=$2 ov=$3 scene=${4:-autobahn}
x=$S/xdg/bench_$name; rm -rf $x; mkdir -p $x
if [ "$ov" != "-" ]; then
	for app in "Crossing Europe – A Racing Xperience" "Crossing Europe - A Racing Xperience"; do
		mkdir -p "$x/godot/app_userdata/$app"; echo "$ov" > "$x/godot/app_userdata/$app/game_config.json"
	done
fi
mkdir -p $S/bench
(cd ${WT:-$W} && XDG_DATA_HOME=$x nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -- --bench=$scene --bench-out=$S/bench/$name.json --bench-seconds=${BS:-20} \
	--gfx-preset=$preset > $S/bench/$name.log 2>&1)
echo "bench $name rc=$?"
python3 -c "
import json,sys
d=json.load(open('$S/bench/$name.json'))
for s in d['scenes']: print('$name', s['id'], 'avg_fps=%.1f'%s['avg_fps'], 'p95=%.1f'%s['frame_ms_p95'], 'script_ms=%.2f'%s['script_ms'], 'draw=%s'%s['draw_calls'])
" 2>&1 | tail -3
