#!/usr/bin/env bash
# QA-R6 chain B: golden check, then the A/B pictures (head, then base). One heavy job at a time, nice 10.
# Skips a shot whose last jpg exists (restart-safe).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-2
B=$S/base
O=$S/shots
mkdir -p $O $S/gates
LOG=$S/gates/chain_b.txt
stamp() { echo "$(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) $*" >> $LOG; }
SHOT=$S/bin/shot.sh
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
DEVC="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KHC="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
PN="--stage=prag_nuernberg --from=nuernberg --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {
	local name=$1; shift
	if ls "$O/${name}"_ab_*.jpg >/dev/null 2>&1; then stamp "skip $name"; return; fi
	stamp "start $name"
	"$SHOT" "$O/$name" "$@" > "$O/$name.out" 2>&1
	stamp "end $name exit $?"
}
# 1) Arcade identity (gate)
if [ ! -s $S/gates/golden_check.log ] || ! grep -q "GOLDEN arcade-ui" $S/gates/golden_check.log; then
	stamp "golden check start"
	rm -rf $S/xdg/golden; mkdir -p $S/xdg/golden
	(cd $W && XDG_DATA_HOME=$S/xdg/golden MESA_SHADER_CACHE_DIR=$S/mesa nice -n 10 tools/golden.sh check > $S/gates/golden_check.log 2>&1)
	stamp "golden check exit $?"
fi
# 1b) renderer GDScript time at the R6 places (headless, normal speed, scaled by the reference clock): head, base
for pr in mut base; do
	if [ ! -s $S/gates/qa_zeit_$pr.log ] || ! grep -q "CHECKS" $S/gates/qa_zeit_$pr.log; then
		stamp "qa_zeit $pr start"
		rm -rf $S/xdg/qz_$pr; mkdir -p $S/xdg/qz_$pr
		(cd $S/$pr && XDG_DATA_HOME=$S/xdg/qz_$pr nice -n 10 timeout 3600 godot --headless --path . -s res://tests/race3d/check_qa_zeit.gd -- --graphics=modern > $S/gates/qa_zeit_$pr.log 2>&1)
		stamp "qa_zeit $pr exit $?"
	fi
done
# 2) head pictures, high
export WT=$W
run h01_dev_station_day $DEV --hour=12 --start-km=18.5 --start-speed=100 --shot-times=0.5,1.2,1.9,2.6,3.3
run h02_dev_station_night $DEV --hour=21 --start-km=18.5 --start-speed=100 --shot-times=0.5,1.2,1.9,2.6,3.3
run h03_dev_border_day $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0
run h04_dev_border_night $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0
run h05_dev_radar_day $DEV --hour=12 --start-km=11.8 --start-speed=150 --autopilot-speeding --shot-times=0.45,0.55,0.7
run h06_dev_radar_night $DEV --hour=21 --start-km=11.8 --start-speed=150 --autopilot-speeding --shot-times=0.45,0.55,0.7
run h07_dev_city_day $DEV --hour=12 --start-km=111 --start-speed=50 --shot-times=1.5,3
run h08_dev_city_night $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=1.5,3
run h09_dev_start_day $DEVC --hour=12 --start-km=0 --shot-times=1,3.6
run h10_dev_start_night $DEVC --hour=21 --start-km=0 --shot-times=1,3.6
run h11_dev_finish_day $DEV --hour=12 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run h12_dev_finish_night $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run k01_kh_fuel_day $KH --hour=12 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
run k02_kh_fuel_night $KH --hour=21 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
run k03_kh_city_night $KH --hour=21 --start-km=76 --start-speed=50 --shot-times=1,3
run k04_kh_start_day $KHC --hour=12 --start-km=0 --shot-times=1,3.6
run k05_kh_finish_day $KH --hour=12 --start-km=94.2 --start-speed=100 --shot-times=1,1.8
run p01_pn_border_day $PN --hour=15 --start-km=129.3 --start-speed=100 --shot-times=1.0,1.8
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run d01_deck_station_night $DEV --hour=21 --start-km=19.1 --start-speed=100 --shot-times=1.0
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run d02_deck_border_day $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=1.2
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run d03_deck_city_night $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=2
# 3) base pictures (6e48405), same arguments
export WT=$B
run b01_dev_station_day $DEV --hour=12 --start-km=18.5 --start-speed=100 --shot-times=0.5,1.2,1.9,2.6,3.3
run b02_dev_station_night $DEV --hour=21 --start-km=18.5 --start-speed=100 --shot-times=0.5,1.2,1.9,2.6,3.3
run b06_dev_radar_night $DEV --hour=21 --start-km=11.8 --start-speed=150 --autopilot-speeding --shot-times=0.45,0.55,0.7
run b08_dev_city_night $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=1.5,3
run b10_dev_start_night $DEVC --hour=21 --start-km=0 --shot-times=1,3.6
run b12_dev_finish_night $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run bk01_kh_fuel_day $KH --hour=12 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
run bk02_kh_fuel_night $KH --hour=21 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
# 4) whole-stage perf under Xvfb, deck preset: head (worktree) and base
for pr in head base; do
	P=$W; [ $pr = base ] && P=$B
	if ! grep -q "^PERF" $S/perf/deck_$pr.log 2>/dev/null; then
		stamp "perf deck $pr start"
		PRESET=deck $S/bin/perf.sh deck_$pr $P
		stamp "perf deck $pr end"
	fi
done
stamp DONE
