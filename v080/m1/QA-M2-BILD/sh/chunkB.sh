#!/bin/bash
# QA-M2-BILD chunk B (< 2 h): Köhlbrandbrücke at 22:00 and 12:00 (Arcade, M2 high, ZS1 high – water under the bridge,
# pylons at night), positions U1 DEV T3 T2 at high (Arcade + M2), then the vehicle probe's traffic rows.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_ab.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
. $SH/jobs.sh
log "chunkB start"
# headless repeat of the City Limits part of the medium drive: is the 1152-ms streamer stall at km 87.1 reproducible
# without GPU load? (headless: no render counters, GDScript timings only)
if ! grep -q "^QA-SUMMARY" $S/perf/kh_m2_medium_city_headless.log 2> /dev/null; then
	X=$S/xdg/hl_city; rm -rf $X; mkdir -p $X
	(cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3 && XDG_DATA_HOME=$X nice -n 10 \
		timeout 2400 godot --headless --path . -s $S/probe/qa_drive.gd -- --graphics=modern --gfx-preset=medium \
		--no-watchdog --no-chooser --sound=arcade --stage=kiel_hamburg --from=kiel --start-km=70 --start-speed=120 \
		--timescale=2 --max-wall=2300 --sample=5 --spike-ms=30 --out=$S/perf/kh_m2_medium_city_headless \
		> $S/perf/kh_m2_medium_city_headless.log 2>&1)
	log "drive headless city exit=$?"
	rm -rf $X
fi
for P in KBN KBT; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_arcade" 1280x720 "" $A --shot-times=2,4
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A --shot-times=2,4
	job zs1 modern "${P}_zs1high" 1280x720 "--gfx-preset=high" $A --shot-times=2,4
done
for P in U1 DEV T3 T2; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_arcade" 1280x720 "" $A --shot-times=3
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A --shot-times=3
done
$SH/vehicles.sh traffic >> $Q 2>&1
log "chunkB end"
