#!/usr/bin/env bash
# AS3R: the gates on the final head, one after the other (nice 19, one worker)
#   gates.sh geom|keys|det|tests|golden
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
echo "=== $1 HEAD $(git rev-parse --short HEAD) $(date +%H:%M:%S)"
case "$1" in
geom)
	nice -n 19 "$BPY" tools/blender/check_sprite_geometry.py --only props --jobs 1 > "$S/logs/g_geom.log" 2>&1
	echo "geometrie exit $?: $(grep -c ANDERS "$S/logs/g_geom.log") ANDERS"
	tail -3 "$S/logs/g_geom.log"
	;;
keys)
	nice -n 19 "$BPY" tools/blender/export_models.py --check-keys > "$S/logs/g_keys.log" 2>&1
	echo "keys exit $?"
	grep -E "CHECK|FEHLER|Traceback" "$S/logs/g_keys.log" | tail -5
	;;
det)
	t0=$(date +%s)
	for g in "props/tree_*" "props/bush_*" "props/cover_*" "props/heather" "props/rock_*" "props/cliff"; do
		nice -n 19 "$BPY" tools/blender/export_models.py --only="$g" --force --jobs=1 2>&1 | grep -E "^EXPORT|Error|Traceback|FEHLER" | head -40
	done
	t1=$(date +%s)
	for g in "props/tree_*" "props/bush_*" "props/cover_*" "props/heather" "props/rock_*" "props/cliff"; do
		nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" 2>&1 | grep -E "bake_models|FEHLER" | tail -2
	done
	nice -n 19 godot --headless --path . --import > /dev/null 2>&1
	nice -n 19 "$BPY" tools/blender/export_models.py --manifest-only 2>&1 | tail -1
	echo "Export $((t1 - t0)) s, gesamt $(( $(date +%s) - t0 )) s"
	echo "git status (leer = byte-identisch):"
	git status --porcelain | grep -v "tools/kritik" || true
	echo "det fertig"
	;;
tests)
	nice -n 19 tools/run_tests.sh > "$S/logs/g_tests.log" 2>&1
	echo "tests exit $?"
	tail -8 "$S/logs/g_tests.log"
	;;
golden)
	nice -n 19 tools/golden.sh check > "$S/logs/g_golden.log" 2>&1
	echo "golden exit $?"
	tail -4 "$S/logs/g_golden.log"
	;;
esac
echo "=== Ende $1 $(date +%H:%M:%S)"
