#!/usr/bin/env bash
# QA-ZS1 queue 2 (after the A/B queue): probe of the start props, render check + break tests, golden check, Wine.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-2
cd "$W" || exit 2
echo "== probe $(date -u +%T)"
mkdir -p "$S/xdg_probe"
for sf in "kiel_hamburg kiel" "saragossa_pau pau"; do
	set -- $sf
	XDG_DATA_HOME=$S/xdg_probe nice -n 5 timeout 300 godot --headless --path . -s "$S/probe_start_props.gd" -- --stage=$1 --from=$2 > "$S/probe_$1.log" 2>&1
	echo "probe $1: exit $?"
done
echo "== render check + breaks $(date -u +%T)"
bash "$S/rc_breaks.sh" > "$S/rc_breaks.log" 2>&1
tail -40 "$S/rc_breaks.log"
echo "== golden check $(date -u +%T)"
mkdir -p "$S/xdg_golden"
XDG_DATA_HOME=$S/xdg_golden nice -n 5 tools/golden.sh check > "$S/golden_check.log" 2>&1
echo "golden exit $?"
grep -E "GOLDEN|identisch|FEHLER|abweich" "$S/golden_check.log" | tail -8
echo "== wine $(date -u +%T)"
bash "$S/wine_run.sh" > "$S/wine_run.log" 2>&1
cat "$S/wine_run.log"
echo "== ende $(date -u +%T)"
git status --short
echo Q2DONE
