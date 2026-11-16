#!/bin/bash
# ERGEBNIS of run_stage.gd: v0.7.0 reference (git archive main) vs this tree (Arcade), plus Modern runs (Rule 3).
# Sequential, nice 10. Output: $S/ergebnis/<tree>_<case>.log and .json
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
REF=$S/ref070
OUT=$S/ergebnis
mkdir -p "$OUT"
run() { # tree_name tree_dir case args...
	local name=$1 dir=$2 case=$3; shift 3
	local xdg="$S/xdg_erg_${name}_${case}"
	rm -rf "$xdg"; mkdir -p "$xdg"
	local t0=$SECONDS
	XDG_DATA_HOME="$xdg" nice -n 10 timeout 2400 godot --headless --path "$dir" -s res://tests/race/run_stage.gd -- "$@" > "$OUT/${name}_${case}.log" 2>&1
	local code=$?
	grep -m1 '^ERGEBNIS ' "$OUT/${name}_${case}.log" | sed 's/^ERGEBNIS //' > "$OUT/${name}_${case}.json"
	echo "$name $case exit=$code $((SECONDS - t0)) s bytes=$(wc -c < "$OUT/${name}_${case}.json") errors=$(grep -cE 'SCRIPT ERROR|^ERROR' "$OUT/${name}_${case}.log")"
	rm -rf "$xdg"
}
CASES=${CASES:-"kh bm df"}
for c in $CASES; do
	case $c in
	kh)  A=(--stage=kiel_hamburg --hour=12 --weather=normal --seed=7) ;;
	bm)  A=(--stage=bern_mailand --hour=22 --weather=snow --start-km=150 --vehicle=kompakt --seed=3) ;;
	df)  A=(--stage=dortmund_frankfurt --hour=19.5 --weather=rain --start-km=170 --vehicle=gran_turismo --seed=5) ;;
	esac
	run ref "$REF" "$c" "${A[@]}"
	run cur "$WT" "$c" "${A[@]}" --graphics=arcade
	if [[ " ${MODERN_CASES:-kh} " == *" $c "* ]]; then
		run curmodern "$WT" "$c" "${A[@]}" --graphics=modern
	fi
done
python3 - "$OUT" <<'EOF'
import json, os, sys
out = sys.argv[1]
for c in ["kh", "bm", "df"]:
    p = os.path.join(out, "ref_%s.json" % c)
    if not os.path.exists(p) or os.path.getsize(p) == 0:
        continue
    ref = json.load(open(p))
    for t in ["cur", "curmodern"]:
        q = os.path.join(out, "%s_%s.json" % (t, c))
        if not os.path.exists(q) or os.path.getsize(q) == 0:
            continue
        cur = json.load(open(q))
        diff = {k: (ref.get(k), cur.get(k)) for k in set(ref) | set(cur) if ref.get(k) != cur.get(k)}
        print(c, t, "keys ref", len(ref), "cur", len(cur), "differences:", json.dumps(diff, ensure_ascii=False)[:400])
EOF
echo ALLDONE
