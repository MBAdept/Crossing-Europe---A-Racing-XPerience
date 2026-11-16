#!/bin/bash
# Exit-leak probe: N short race-scene runs with a screenshot (the Screenshotter quits), --verbose; counts leak lines.
#   leak.sh <mode arcade|modern> <runs>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
mode=$1; runs=${2:-3}
mkdir -p "$S/leak"
for i in $(seq 1 "$runs"); do
	nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 --verbose res://scenes/race/race.tscn -- "--screenshot=$S/leak/${mode}_$i" \
		--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup \
		--no-countdown --start-speed=120 --start-km=2 --shot-times=1 --graphics=$mode --gfx-sync --shot-fast > "$S/leak/${mode}_$i.log" 2>&1
	echo "run $i rc=$? leak lines: $(grep -c 'leaked at exit\|still in use at exit' "$S/leak/${mode}_$i.log")"
	grep -E "Leaked instance|leaked at exit|still in use|Resource still in use" "$S/leak/${mode}_$i.log" | sort | uniq -c | sort -rn | head -12
done
