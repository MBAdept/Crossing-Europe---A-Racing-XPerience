#!/bin/bash
# ERGEBNIS identity Arcade vs Modern (RINT-B gate): tests/race/run_stage.gd headless, the whole stage at time scale 40,
# per stage once with --graphics=arcade and once with --graphics=modern; prints both ERGEBNIS lines and whether they
# are equal.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
OUT=$S/ergebnis
mkdir -p "$OUT"
cd "$WT" || exit 1
run() {
	local name=$1
	shift
	for m in arcade modern; do
		export XDG_DATA_HOME=$OUT/xdg_${name}_$m
		mkdir -p "$XDG_DATA_HOME"
		local t0=$SECONDS
		nice -n 10 timeout 1800 godot --headless --path . -s res://tests/race/run_stage.gd -- --graphics=$m --timescale=40 "$@" \
			> "$OUT/${name}_$m.log" 2>&1
		echo "$name $m exit=$? $((SECONDS - t0)) s"
		grep -E "^ERGEBNIS" "$OUT/${name}_$m.log" | head -1 > "$OUT/${name}_$m.ergebnis"
	done
	if cmp -s "$OUT/${name}_arcade.ergebnis" "$OUT/${name}_modern.ergebnis" && [ -s "$OUT/${name}_arcade.ergebnis" ]; then
		echo "$name GLEICH: $(cut -c1-300 "$OUT/${name}_arcade.ergebnis")"
	else
		echo "$name VERSCHIEDEN"
		cat "$OUT/${name}_arcade.ergebnis" "$OUT/${name}_modern.ergebnis" | cut -c1-400
	fi
}
run kiel_hamburg --stage=kiel_hamburg --from=kiel
run dev_nacht_regen --stage=dev_testetappe --hour=21 --weather=rain
run saragossa_schnee --stage=saragossa_pau --from=saragossa --weather=snow
