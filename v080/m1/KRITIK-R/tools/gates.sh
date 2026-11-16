#!/bin/bash
# KRITIK-R: the gates on the AU-R copy, one after the other: tools/run_tests.sh (once), then tools/golden.sh check (once).
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
mkdir -p "$K/xdg_tests" "$K/tmp" "$K/logs"
cd "$K/after" || exit 2
steps=${*:-tests golden}
for s in $steps; do
	case $s in
		tests)
			t0=$(date +%s)
			XDG_DATA_HOME="$K/xdg_tests" TMPDIR="$K/tmp" nice -n 19 bash tools/run_tests.sh > "$K/logs/run_tests.log" 2>&1
			echo "--- run_tests exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
			tail -5 "$K/logs/run_tests.log" ;;
		golden)
			t0=$(date +%s)
			TMPDIR="$K/tmp" nice -n 19 bash tools/golden.sh check > "$K/logs/golden.log" 2>&1
			echo "--- golden exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
			tail -4 "$K/logs/golden.log" ;;
	esac
done
echo "=== gates fertig $(date +%T)"
