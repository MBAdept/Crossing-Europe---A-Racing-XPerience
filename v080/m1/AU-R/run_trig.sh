#!/usr/bin/env bash
# AU-R: trigger logs (autopilot, headless, timescale 8) – one after the other, nice 19
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
NEW=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1
OLD=$S/old
mkdir -p "$S/trig" "$S/xdg_trig"
t() {   # tree name stage from startkm
	(cd "$1" && XDG_DATA_HOME="$S/xdg_trig" nice -n 19 timeout 1200 godot --headless --path . -s "$S/trigger_log2.gd" -- \
		--graphics=arcade --sound=modern --stage="$3" --from="$4" --start-km="$5" --timescale=8 --max-seconds=900 \
		> "$S/trig/$2.log" 2>&1)
	echo "$2 exit $? $(grep -c '^ROW' "$S/trig/$2.log") rows"
}
t "$OLD" kh_old kiel_hamburg kiel 0
t "$NEW" kh_new kiel_hamburg kiel 0
t "$NEW" mv_new mailand_venedig mailand 255
t "$NEW" lp_new luettich_paris luettich 375
t "$OLD" mv_old mailand_venedig mailand 255
t "$OLD" lp_old luettich_paris luettich 375
echo "=== trig fertig"
