#!/usr/bin/env bash
# R5: Modern pictures of the NEW code (worktree) at the places of the brief – Modern only (Arcade is frozen: its
# pictures come from the baseline runs). Usage: new1.sh <out_dir> [name…]  (no names: all of the first batch)
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
MO=$R5/tools/mo.sh
OUT=${1:-$R5/shots/new1}
shift
WANT=" $* "
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {
	local name=$1
	shift
	if [ "$WANT" != "  " ] && [[ "$WANT" != *" $name "* ]]; then
		return
	fi
	bash $MO "$OUT/$name" "$@" $COMMON
}
run kb_rampe --stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4
run holtenau --stage=rostock_kiel --from=rostock --start-km=199.6 --hour=12 --seed=11 --start-speed=100 --shot-times=2,4
run u1_anfahrt --stage=bern_mailand --from=bern --start-km=183.6 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5
run u1_innen --stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 --start-speed=120 --shot-times=2,4
run u1_ausfahrt --stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5
run kb_ende --stage=kiel_hamburg --from=kiel --start-km=79.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4
run b1_koeln --stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4
run elbbruecken --stage=kiel_hamburg --from=kiel --start-km=83.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4
run stein_wuerzburg --stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4
run kb_nacht --stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=22 --seed=11 --start-speed=80 --shot-times=2,4
run dev --stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 --start-speed=120 --shot-times=2,4,6
run somport --stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 --start-speed=100 --shot-times=2,4,6
echo NEW1_DONE
