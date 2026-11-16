#!/usr/bin/env bash
# AS3 scratch: the heavy gates on the final head, one after the other (nice 19): sprite geometry, tests, golden.
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
echo "=== HEAD $(git rev-parse --short HEAD) $(date +%H:%M:%S)"
# contact sheets again with the variants (contact_sheet.gd now builds models without a set of their own)
for g in "props/tree_*" "props/bush_*"; do
	n=$(echo "$g" | tr -d '/*' | sed 's/props//')
	echo "=== kontakt $g $(date +%H:%M:%S)"
	nice -n 19 tools/models_contact_sheet.sh $S/shots/f_kontakt_${n}_tag.png --only="$g" --cols=6 --tile=300x240 > $S/logs/f_kontakt_${n}_tag.txt 2>&1
	nice -n 19 tools/models_contact_sheet.sh $S/shots/f_kontakt_${n}_nacht.png --only="$g" --cols=6 --tile=300x240 --night > $S/logs/f_kontakt_${n}_nacht.txt 2>&1
done
echo "=== geometrie $(date +%H:%M:%S)"
nice -n 19 "$BPY" tools/blender/check_sprite_geometry.py --only props --jobs 1 > "$S/logs/f_geom.log" 2>&1
echo "geometrie exit $?: $(grep -c ANDERS "$S/logs/f_geom.log") ANDERS"
tail -3 "$S/logs/f_geom.log"
echo "=== tests $(date +%H:%M:%S)"
nice -n 19 tools/run_tests.sh > "$S/logs/f_tests.log" 2>&1
echo "tests exit $?"
tail -6 "$S/logs/f_tests.log"
echo "=== golden $(date +%H:%M:%S)"
nice -n 19 tools/golden.sh check > "$S/logs/f_golden.log" 2>&1
echo "golden exit $?"
tail -4 "$S/logs/f_golden.log"
echo "=== Ende $(date +%H:%M:%S)"
