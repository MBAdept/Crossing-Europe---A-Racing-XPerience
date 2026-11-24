#!/bin/bash
# QA-MID: the runs of plan.txt (resumable – a run with a RUN line is done). qrun.sh <slot> <of>: every <of>-th line from <slot>
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
slot=$1; of=$2
i=0
while read -r tag stage from hour weather gfx preset shots; do
	i=$((i + 1))
	[ $(( (i - 1) % of )) -eq $((slot)) ] || continue
	log=$S/runs/$tag.log
	grep -q '^RUN ' $log 2>/dev/null && continue
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
	x=$S/xdg/q_$slot; rm -rf $x; mkdir -p $x $S/shots/$tag
	args="--stage=$stage --from=$from --hour=$hour --weather=$weather --seed=7 --timescale=40 --max-seconds=6000 --graphics=$gfx --gfx-preset=$preset"
	[ "$shots" != "-" ] && args="$args --shot-km=$shots --out=$S/shots/$tag/s"
	t0=$SECONDS
	(cd $W && XDG_DATA_HOME=$x nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -s $S/sh/stage_shots.gd -- $args > $log 2>&1)
	rc=$?
	echo "$(date +%T) $tag exit=$rc $((SECONDS - t0)) s $(grep -E '^ERRORS' $log) shots=$(ls $S/shots/$tag | wc -l)" >> $S/logs/qrun.log
done < $S/plan.txt
echo "QRUN $slot DONE $(date +%T)" >> $S/logs/qrun.log
