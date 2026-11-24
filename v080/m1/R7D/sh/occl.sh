#!/bin/bash
# A-17 occlusion probe (FIX-M2 qa_occl.gd: red test car in three lanes, 25–270 m): occl.sh <head|base> <POS>...
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
which=$1; shift
wt=$W
[ "$which" = base ] && wt=$S/base
probe=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_occl.gd
o=$S/occl
mkdir -p "$o"
for name in "$@"; do
	case "$name" in
	T1) a="--stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --vehicle=kombi --seed=12" ;;
	T2) a="--stage=kassel_wuerzburg --from=kassel --km=61.9 --hour=15 --vehicle=kombi --seed=12" ;;
	T3) a="--stage=saragossa_pau --from=saragossa --km=172.8 --hour=11 --vehicle=kompakt --seed=4" ;;
	T4) a="--stage=saragossa_pau --from=saragossa --km=198.8 --hour=11 --vehicle=kompakt --seed=4" ;;
	C1) a="--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15" ;;
	S0) a="--stage=kiel_hamburg --from=kiel --km=0.05 --hour=12 --vehicle=limousine --seed=11" ;;
	S4) a="--stage=kiel_hamburg --from=kiel --km=80 --hour=12 --vehicle=limousine --seed=11" ;;
	*) echo "unknown $name"; continue ;;
	esac
	x=$S/xdg/occ_${name}_$which
	rm -rf "$x"; mkdir -p "$x"
	t0=$SECONDS
	# shellcheck disable=SC2086
	(cd "$wt" && XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$probe" -- \
		--graphics=modern --gfx-preset=high --gfx-sync --sound=arcade --out="$o" --tag="${name}_$which" \
		--dists=25,55,85,120,150,200,270 $a > "$o/${name}_$which.log" 2>&1)
	echo "$(date +%H:%M:%S) occl $which $name exit=$? $((SECONDS - t0)) s"
	rm -rf "$x"
done
