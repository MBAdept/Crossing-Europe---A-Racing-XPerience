#!/bin/bash
# ERGEBNIS of run_stage.gd: v0.7.0 reference vs this tree (Arcade), plus one Modern run (Rule 3).
# Sequential, nice 10. Output: $S/ergebnis/<tree>_<case>.log and .json
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
REF=$S/ref070
OUT=$S/ergebnis
mkdir -p "$OUT"
run() { # tree_name tree_dir case args...
	local name=$1 dir=$2 case=$3; shift 3
	local xdg="$S/xdg_erg_${name}_${case}"
	rm -rf "$xdg"; mkdir -p "$xdg"
	local t0=$SECONDS
	XDG_DATA_HOME="$xdg" nice -n 10 timeout 1500 godot --headless --path "$dir" -s res://tests/race/run_stage.gd -- "$@" > "$OUT/${name}_${case}.log" 2>&1
	local code=$?
	grep -m1 '^ERGEBNIS ' "$OUT/${name}_${case}.log" | sed 's/^ERGEBNIS //' > "$OUT/${name}_${case}.json"
	echo "$name $case exit=$code $((SECONDS - t0)) s bytes=$(wc -c < "$OUT/${name}_${case}.json")"
}
CASES=${CASES:-"kh dev hh"}
for c in $CASES; do
	case $c in
	kh)  A=(--stage=kiel_hamburg --hour=12 --weather=normal) ;;
	dev) A=(--stage=dev_testetappe --hour=21 --weather=rain) ;;
	hh)  A=(--stage=hamburg_hannover --hour=22 --weather=snow) ;;
	fk)  A=(--stage=fulda_kassel --hour=7 --weather=normal --vehicle=kompakt) ;;
	esac
	run ref "$REF" "$c" "${A[@]}"
	run cur "$WT" "$c" "${A[@]}" --graphics=arcade
	if [ "$c" = "${MODERN_CASE:-dev}" ]; then
		run curmodern "$WT" "$c" "${A[@]}" --graphics=modern
	fi
done
echo ALLDONE
