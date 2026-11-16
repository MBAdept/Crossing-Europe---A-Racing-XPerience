#!/usr/bin/env bash
# QA-R5 picture batch: shots.sh <set> [name…]
#   set "new"  : tools/ab_shot.sh of the R5 head (Arcade + Modern), out shots/new
#   set "base" : Modern only of the base tree (6e48405), out shots/base
# PRESET (default high), SCREEN (default 1280x720) from the environment.
set -uo pipefail
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
SET=$1
shift
WANT=" $* "
PRESET=${PRESET:-high}
SCREEN=${SCREEN:-1280x720}
SUFFIX=${SUFFIX:-}
export MESA_SHADER_CACHE_DIR=$Q/mesa
export TMPDIR=$Q/tmp
mkdir -p "$MESA_SHADER_CACHE_DIR" "$TMPDIR" "$Q/shots/new" "$Q/shots/base"
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
shot() {   # shot <name> <args…>
	local name=$1
	shift
	want "$name" || return 0
	local t0=$SECONDS
	if [ "$SET" = "new" ]; then
		cd "$WT" || exit 1
		SCREEN=$SCREEN AB_TIMEOUT=1800 GFX_ARGS="--gfx-preset=$PRESET" nice -n $NICE tools/ab_shot.sh "$Q/shots/new/$name$SUFFIX" "$@" $COMMON
		echo "== new $name$SUFFIX exit $? $((SECONDS - t0)) s"
	else
		cd "$Q/base" || exit 1
		local X
		X=$(mktemp -d "$Q/tmp/xdg.XXXXXX")
		local OUT=$Q/shots/base/$name$SUFFIX
		# shellcheck disable=SC2086
		XDG_DATA_HOME="$X" nice -n $NICE timeout 1800 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
			--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
			"--screenshot=${OUT}_modern" "$@" $COMMON --gfx-preset=$PRESET "--graphics=modern" --gfx-sync >"${OUT}_modern.log" 2>&1
		echo "== base $name$SUFFIX exit $? $((SECONDS - t0)) s"
		rm -rf "$X"
	fi
}
U1A="--stage=bern_mailand --from=bern --start-km=183.6 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1I="--stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 --start-speed=120 --shot-times=2,4"
U1X="--stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5"
U1N="--stage=bern_mailand --from=bern --start-km=183.6 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3.5"
SOM="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 --start-speed=100 --shot-times=2,4,6"
KBR="--stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBE="--stage=kiel_hamburg --from=kiel --start-km=79.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBT="--stage=kiel_hamburg --from=kiel --start-km=75.6 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,2.4,2.8,3.2"
KBN="--stage=kiel_hamburg --from=kiel --start-km=76.4 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,3.5,5"
HOL="--stage=rostock_kiel --from=rostock --start-km=199.6 --hour=12 --seed=11 --start-speed=100 --shot-times=2,4"
B1="--stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
ELB="--stage=kiel_hamburg --from=kiel --start-km=83.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
STE="--stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
DEV="--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 --start-speed=120 --shot-times=2,4,6"
EXTRA1=${EXTRA1:-}
shot u1_anfahrt $U1A
shot u1_innen $U1I
shot u1_ausfahrt $U1X
shot u1_nacht $U1N
shot kb_rampe $KBR
shot kb_ende $KBE
shot kb_top $KBT
shot kb_nacht $KBN
shot holtenau $HOL
shot b1_koeln $B1
shot somport $SOM
shot elbbruecken $ELB
shot stein $STE
shot dev $DEV
if [ -n "$EXTRA1" ]; then
	# shellcheck disable=SC2086
	shot extra $EXTRA1
fi
echo "SHOTS_DONE $SET"
