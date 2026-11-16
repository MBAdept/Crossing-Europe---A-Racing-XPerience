#!/usr/bin/env bash
# QA-ZS1 queue 4: menu walk (options, Leistungstest) and the Köhlbrandbrücke claim of was_neu.md, both with the
# delivered Linux export.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
NEW=$S/lin/CrossingEurope-ZS1.x86_64
echo "== probe $(date -u +%T)"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-2 || exit 2
for sf in "kiel_hamburg kiel" "saragossa_pau pau" "paris_tours paris" "hamburg_hannover hamburg"; do
	set -- $sf
	XDG_DATA_HOME=$S/xdg_probe nice -n 5 timeout 300 godot --headless --path . -s "$S/probe_start_props.gd" -- --stage=$1 --from=$2 > "$S/probe_$1.log" 2>&1
	echo "probe $1: exit $?"
done
echo "== walk options $(date -u +%T)"
bash $S/walk_options.sh > $S/walk_opt.log 2>&1
tail -20 $S/walk_opt.log
echo "== koehlbrand $(date -u +%T)"
bash $S/ab_export.sh "$NEW" "$S/ab/koehlbrand" "arcade modern" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine \
	--seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic --start-km=78.0 --gfx-preset=medium --shot-times=2.5
echo "== deck 1280x800 $(date -u +%T)"
SCREEN=1280x800 bash $S/ab_export.sh "$NEW" "$S/ab/deck800" "arcade modern" --stage=kiel_hamburg --from=kiel --hour=8 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --gfx-preset=deck --shot-times=1,4.5
echo "== ende $(date -u +%T)"
echo Q4DONE
