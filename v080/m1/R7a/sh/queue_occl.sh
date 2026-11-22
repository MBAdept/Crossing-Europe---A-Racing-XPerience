#!/bin/bash
# R7a: occlusion probe at T1–T4, C1, S0, S4 – this tree and the base, Modern "high".
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
pos() {
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
for p in "$@"; do
	for w in mine base; do
		# shellcheck disable=SC2046
		bash "$S/sh/occl.sh" $w "$p" $(pos "$p")
	done
done
