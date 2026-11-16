#!/bin/bash
# QA-BILD job queue (one heavy job at a time). Log: queue.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
log "queue start"
until grep -q DONE $S/ab_med/batch1.log 2>/dev/null; do sleep 10; done
log "batch1 done"
if [ -z "$SKIP_B2" ]; then bash $S/tools/batch2.sh; log "batch2 done"; fi
# fairness (headless)
mkdir -p $S/fair $S/xdg_fair
cd $WT || exit 1
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_fair nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $S/fair/sight_full.log 2>&1
log "sight full exit=$? $((SECONDS - t0)) s"
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_fair nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/fair/path_full.log 2>&1
log "path full exit=$? $((SECONDS - t0)) s"
# clips (60 fps fixed, autopilot)
mkdir -p $S/clips
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
A=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120 --start-km=2)
$S/tools/clip.sh $S/clips/s1_modern_high.avi modern 1100 high "${A[@]}" >> $Q 2>&1
$S/tools/clip.sh $S/clips/s1_arcade.avi arcade 840 - "${A[@]}" >> $Q 2>&1
B=(--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80)
$S/tools/clip.sh $S/clips/t4_modern_med.avi modern 960 medium "${B[@]}" >> $Q 2>&1
$S/tools/clip.sh $S/clips/t4_arcade.avi arcade 720 - "${B[@]}" >> $Q 2>&1
C=(--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $FLY --start-speed=100)
$S/tools/clip.sh $S/clips/n1_modern_med.avi modern 960 medium "${C[@]}" >> $Q 2>&1
$S/tools/clip.sh $S/clips/n1_arcade.avi arcade 720 - "${C[@]}" >> $Q 2>&1
log "clips done"
# performance: complete Kiel–Hamburg, real time (timescale 1), per preset + Arcade
P=(--stage=kiel_hamburg --from=kiel --hour=12 --vehicle=limousine --seed=11 --timescale=1 --max-wall=2400 --sample=5)
for pr in low medium high; do
	$S/tools/drive.sh kh_modern_$pr modern $pr "${P[@]}" >> $Q 2>&1
done
$S/tools/drive.sh kh_arcade arcade - "${P[@]}" >> $Q 2>&1
log "perf done"
# memory: 20 min of driving (sim), long stage, time scale 4
DRIVE_TIMEOUT=3000 $S/tools/drive.sh mem_modern_medium modern medium --stage=luettich_paris --from=luettich --hour=12 \
	--vehicle=limousine --seed=21 --timescale=4 --max-steps=32 --max-wall=2700 --sample=10 --quit-sim=1200 >> $Q 2>&1
log "memory done"
log "queue end"
