#!/usr/bin/env bash
# FIX-R5 picture batch (Modern only of this worktree; Arcade and the R5 head come from QA-R5's renders, which are
# bit-identical to renders of 5558bdc): shots.sh <outdir-name> [name…]
# PRESET (default high), SCREEN (default 1280x720) from the environment.
set -uo pipefail
F=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6}
SET=$1
shift
WANT=" $* "
PRESET=${PRESET:-high}
SCREEN=${SCREEN:-1280x720}
SUFFIX=${SUFFIX:-}
MODE=${MODE:-modern}
export MESA_SHADER_CACHE_DIR=$F/mesa
export TMPDIR=$F/tmp
mkdir -p "$MESA_SHADER_CACHE_DIR" "$TMPDIR" "$F/shots/$SET"
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
shot() {   # shot <name> <args…>
	local name=$1
	shift
	want "$name" || return 0
	local t0=$SECONDS
	cd "$WT" || exit 1
	local X
	X=$(mktemp -d "$F/tmp/xdg.XXXXXX")
	local OUT=$F/shots/$SET/$name$SUFFIX
	local GA="--gfx-preset=$PRESET"
	[ "$MODE" = "arcade" ] && GA="--shot-fast"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$X" nice -n $NICE timeout 1800 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
		"--screenshot=${OUT}_$MODE" "$@" $COMMON $GA $EXTRA_ARGS "--graphics=$MODE" --gfx-sync >"${OUT}_$MODE.log" 2>&1
	echo "== $SET $name$SUFFIX exit $? $((SECONDS - t0)) s errors: $(grep -cE 'SCRIPT ERROR|SHADER ERROR|Parse Error' "${OUT}_$MODE.log")"
	rm -rf "$X"
}
EXTRA_ARGS=${EXTRA_ARGS:-}
U1A="--stage=bern_mailand --from=bern --start-km=183.6 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1I="--stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 --start-speed=120 --shot-times=2,4"
U1X="--stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5"
U1N="--stage=bern_mailand --from=bern --start-km=183.6 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1NN="--stage=bern_mailand --from=bern --start-km=184.0 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3,4"
SOM="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 --start-speed=100 --shot-times=2,4,6"
SOMN="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=22 --seed=4 --start-speed=100 --shot-times=2,4,6"
KBR="--stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBE="--stage=kiel_hamburg --from=kiel --start-km=79.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBT="--stage=kiel_hamburg --from=kiel --start-km=75.6 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,2.4,2.8,3.2"
KBN="--stage=kiel_hamburg --from=kiel --start-km=76.4 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,3.5,5"
HOL="--stage=rostock_kiel --from=rostock --start-km=199.6 --hour=12 --seed=11 --start-speed=100 --shot-times=2,4"
B1="--stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
ELB="--stage=kiel_hamburg --from=kiel --start-km=83.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
STE="--stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
DEV="--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 --start-speed=120 --shot-times=2,4,6"
shot u1_anfahrt $U1A
shot u1_innen $U1I
shot u1_ausfahrt $U1X
shot u1_nacht $U1N
shot u1_nacht_nah $U1NN
shot kb_rampe $KBR
shot kb_ende $KBE
shot kb_top $KBT
shot kb_nacht $KBN
shot holtenau $HOL
shot b1_koeln $B1
shot somport $SOM
shot somport_nacht $SOMN
shot elbbruecken $ELB
shot stein $STE
shot dev $DEV
echo "SHOTS_DONE $SET"
