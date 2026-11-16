#!/usr/bin/env bash
# Scratch (R1a): ERGEBNIS identity Arcade vs Modern with tests/sim… tests/race/run_stage.gd on two stages.
# Usage: ergebnis.sh <out dir>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a
OUT=${1:-$S/ergebnis}
mkdir -p "$OUT"
for run in "kiel_hamburg --from=kiel --hour=12 --weather=normal --seed=11" "dev_testetappe --hour=21 --weather=rain --seed=3"; do
	set -- $run
	stage=$1
	shift
	for mode in arcade modern; do
		t0=$SECONDS
		"$S/bin/gd.sh" -s res://tests/race/run_stage.gd -- --stage="$stage" "$@" --graphics=$mode >"$OUT/${stage}_$mode.log" 2>&1
		echo "$stage $mode: exit $? ($((SECONDS - t0)) s)"
	done
	python3 "$S/bin/ergebnis_cmp.py" "$OUT/${stage}_arcade.log" "$OUT/${stage}_modern.log"
done
