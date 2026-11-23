#!/bin/bash
# FIX-R7a common settings (positions as QA-R7a/sh/common.sh)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8
PFIX=$S/pfix
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
export XDG_DATA_HOME=$S/xdg
mkdir -p "$S/mesa" "$S/tmp" "$S/xdg" "$D" "$S/logs"
memwait() {
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
}
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120"
pos_args() {
	local h=${2:-}
	local a=""
	case "$1" in
	T1) a="--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120 --shot-times=3" ;;
	T2) a="--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120 --shot-times=3" ;;
	T3) a="--stage=saragossa_pau --from=saragossa --start-km=172.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80 --shot-times=3" ;;
	T4) a="--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80 --shot-times=3" ;;
	C1) a="--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $FLY --start-speed=90 --shot-times=3" ;;
	S4) a="$SLICE --start-km=80 --start-speed=50 --shot-times=3" ;;
	S0) a="--stage=kiel_hamburg --from=kiel --start-km=0 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5" ;;
	Lyon) a="--stage=montpellier_lyon --from=montpellier --start-km=297.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Bern) a="--stage=lyon_bern --from=lyon --start-km=302.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Muenchen) a="--stage=muenchen_nuernberg --from=nuernberg --start-km=161.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Nuernberg) a="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Belgrad) a="--stage=slavonski_brod_belgrad --from=slavonski_brod --start-km=187.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Hannover) a="--stage=hamburg_hannover --from=hamburg --start-km=142.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	esac
	[ -n "$h" ] && [ -n "$a" ] && a="$a --hour=$h"
	echo "$a"
}
# shot <head|pushB> <name> <preset> [hour] [tag]
shot() {
	local which=$1 name=$2 q=$3 h=${4:-} tag=${5:-}
	local wt=$WT out=$D/kopf
	[ "$which" = pushB ] && { wt=$PFIX; out=$D/hinausschieben; }
	mkdir -p "$out"
	local a
	a=$(pos_args "$name" "$h")
	[ -z "$a" ] && { echo "unknown $name"; return 1; }
	memwait
	local t0=$SECONDS
	# shellcheck disable=SC2086
	(cd "$wt" && GFX_ARGS="--gfx-preset=$q" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh "$out/${name}${tag}_$q" $a > "$out/${name}${tag}_$q.run.log" 2>&1)
	echo "$(date -u +%H:%M:%S) $which $name$tag $q exit=$? $((SECONDS - t0)) s"
}
occ_args() {
	case "$1" in
	T1) echo "--stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --vehicle=kombi --seed=12" ;;
	T2) echo "--stage=kassel_wuerzburg --from=kassel --km=61.9 --hour=15 --vehicle=kombi --seed=12" ;;
	T3) echo "--stage=saragossa_pau --from=saragossa --km=172.8 --hour=11 --vehicle=kompakt --seed=4" ;;
	T4) echo "--stage=saragossa_pau --from=saragossa --km=198.8 --hour=11 --vehicle=kompakt --seed=4" ;;
	C1) echo "--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15" ;;
	S0) echo "--stage=kiel_hamburg --from=kiel --km=0 --hour=12 --vehicle=limousine --seed=11" ;;
	S4) echo "--stage=kiel_hamburg --from=kiel --km=80 --hour=12 --vehicle=limousine --seed=11" ;;
	esac
}
# occl <head|pushB> <name>: occlusion probe of FIX-M2 (test car in three lanes, 25-270 m), Modern "high"
occl() {
	local which=$1 name=$2
	local wt=$WT
	[ "$which" = pushB ] && wt=$PFIX
	local probe=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_occl.gd
	local o=$S/occl
	mkdir -p "$o"
	local x=$S/xdg/occ_$$
	rm -rf "$x"; mkdir -p "$x"
	memwait
	local t0=$SECONDS
	local a
	a=$(occ_args "$name")
	# shellcheck disable=SC2086
	(cd "$wt" && XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$probe" -- \
		--graphics=modern --gfx-preset=high --gfx-sync --sound=arcade --out="$o" --tag="${name}_$which" \
		--dists=25,55,85,120,150,200,270 $a > "$o/${name}_$which.log" 2>&1)
	echo "$(date -u +%H:%M:%S) occl $which $name exit=$? $((SECONDS - t0)) s"
	rm -rf "$x"
}
