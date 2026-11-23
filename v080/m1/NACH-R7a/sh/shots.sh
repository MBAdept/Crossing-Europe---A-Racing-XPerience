#!/bin/bash
# NACH-R7a pictures: shots.sh <head|m3> <name> [preset] [hour]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/NACH-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
export XDG_DATA_HOME=$S/xdg/shots
mkdir -p "$S/mesa" "$S/tmp" "$S/xdg/shots" "$D/kopf" "$D/m3"
memwait() { while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done; }
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
pos_args() {
	case "$1" in
	T4) echo "--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80 --shot-times=3" ;;
	T2) echo "--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120 --shot-times=3" ;;
	C1) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $FLY --start-speed=90 --shot-times=3" ;;
	Muenchen) echo "--stage=muenchen_nuernberg --from=nuernberg --start-km=161.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Belgrad) echo "--stage=slavonski_brod_belgrad --from=slavonski_brod --start-km=187.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Hannover) echo "--stage=hamburg_hannover --from=hamburg --start-km=142.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	esac
}
which=$1; name=$2; q=${3:-high}; h=${4:-}
wt=$WT; out=$D/kopf
[ "$which" = m3 ] && { wt=$S/m3; out=$D/m3; }
a=$(pos_args "$name")
[ -n "$h" ] && a="$a --hour=$h"
memwait
t0=$SECONDS
# shellcheck disable=SC2086
(cd "$wt" && GFX_ARGS="--gfx-preset=$q" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh "$out/${name}_$q${h:+_h$h}" $a > "$out/${name}_$q${h:+_h$h}.run.log" 2>&1)
echo "$(date -u +%H:%M:%S) $which $name $q exit=$? $((SECONDS - t0)) s"
