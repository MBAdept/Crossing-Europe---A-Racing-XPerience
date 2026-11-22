#!/bin/bash
# R7a: A/B pictures (tools/ab_shot.sh) of the extra positions, on this worktree (mine) or on the base worktree.
#   shots.sh <mine|base> <presets "high medium"> <name>...    (names: S0 Lyon Bern Muenchen Nuernberg Belgrad Hannover R1..R5)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7a
WHICH=$1
PRESETS=$2
shift 2
if [ "$WHICH" = base ]; then WT=$S/base; OUT=$D/basis; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1; OUT=$D/bilder; fi
mkdir -p "$OUT" "$S/mesa" "$S/tmp"
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
args() {
	case "$1" in
	S0) echo "--stage=kiel_hamburg --from=kiel --start-km=0 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5" ;;
	Lyon) echo "--stage=montpellier_lyon --from=montpellier --start-km=297.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Bern) echo "--stage=lyon_bern --from=lyon --start-km=302.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Muenchen) echo "--stage=muenchen_nuernberg --from=nuernberg --start-km=161.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Nuernberg) echo "--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Belgrad) echo "--stage=slavonski_brod_belgrad --from=slavonski_brod --start-km=187.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	Hannover) echo "--stage=hamburg_hannover --from=hamburg --start-km=142.4 --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=50 --shot-times=2,4" ;;
	R*) [ -f "$S/roofs.txt" ] && grep "^$1 " "$S/roofs.txt" | cut -d' ' -f2- ;;
	esac
}
for name in "$@"; do
	a=$(args "$name")
	[ -z "$a" ] && { echo "unknown $name"; continue; }
	for q in $PRESETS; do
		while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
		t0=$SECONDS
		# shellcheck disable=SC2086
		(cd "$WT" && GFX_ARGS="--gfx-preset=$q" AB_TIMEOUT=900 tools/ab_shot.sh "$OUT/${name}_$q" $a > "$OUT/${name}_$q.run.log" 2>&1)
		echo "$(date -u +%H:%M:%S) $WHICH $name $q exit=$? $((SECONDS - t0)) s"
	done
done
