#!/bin/bash
# R7a: occlusion probe – T4, T3 on this tree and the base; T1, T2, C1, S0, S4 on this tree.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start"
bash "$S/sh/queue_occl.sh" T4 T3
for p in T1 T2 C1 S0 S4; do
	case "$p" in
	T1) a="--stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --vehicle=kombi --seed=12" ;;
	T2) a="--stage=kassel_wuerzburg --from=kassel --km=61.9 --hour=15 --vehicle=kombi --seed=12" ;;
	C1) a="--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15" ;;
	S0) a="--stage=kiel_hamburg --from=kiel --km=0 --hour=12 --vehicle=limousine --seed=11" ;;
	S4) a="--stage=kiel_hamburg --from=kiel --km=80 --hour=12 --vehicle=limousine --seed=11" ;;
	esac
	# shellcheck disable=SC2086
	bash "$S/sh/occl.sh" mine "$p" $a
done
echo "$(date -u +%H:%M:%S) done"
