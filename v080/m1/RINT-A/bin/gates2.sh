#!/bin/bash
# Final gates of RINT-A on the current head, one after the other (heavy jobs never in parallel); every run with a
# FRESH absolute XDG_DATA_HOME under the scratch folder (no stored settings).
#   gates2.sh [steps...]   steps: import render tests warm drive
B=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin
source $B/env.sh
steps=("$@")
G=$S/gates2
mkdir -p "$G" "$S/tmp"
export TMPDIR=$S/tmp
echo "HEAD $(git rev-parse --short HEAD) $(date +%H:%M:%S)" | tee -a "$G/summary.txt"
for st in "${steps[@]}"; do
	t0=$(date +%s)
	case "$st" in
	import)
		nice -n 10 godot --headless --path . --import > "$G/import.log" 2>&1
		echo "import rc=$? errors: $(grep -ciE '^ERROR|SCRIPT ERROR|failed' "$G/import.log")" | tee -a "$G/summary.txt" ;;
	render)
		rm -rf "$S/xdg_render"; mkdir -p "$S/xdg_render"
		(export XDG_DATA_HOME=$S/xdg_render; unset MESA_SHADER_CACHE_DIR; nice -n 10 tools/run_render_checks.sh all > "$G/render.log" 2>&1)
		echo "render rc=$? $(grep -E '==>' "$G/render.log" | tail -1)" | tee -a "$G/summary.txt"
		rm -rf "$S/xdg_render" ;;
	tests)
		rm -rf "$S/xdg_tests"; mkdir -p "$S/xdg_tests"
		(export XDG_DATA_HOME=$S/xdg_tests; nice -n 10 tools/run_tests.sh > "$G/run_tests.log" 2>&1)
		echo "run_tests rc=$? $(grep -E '==> Tests' "$G/run_tests.log")" | tee -a "$G/summary.txt"
		rm -rf "$S/xdg_tests" ;;
	warm)
		bash $B/warm.sh final2 > "$G/warm.txt" 2>&1
		echo "warm: $(grep -E 'RENDER-CHECK' "$G/warm.txt" | cut -c1-260)" | tee -a "$G/summary.txt" ;;
	drive)
		rm -rf "$S/xdg_drive"; mkdir -p "$S/xdg_drive"
		XDG_DATA_HOME=$S/xdg_drive bash $B/drive.sh final2 > "$G/drive.txt" 2>&1
		echo "drive: $(head -1 "$G/drive.txt")" | tee -a "$G/summary.txt"
		rm -rf "$S/xdg_drive" ;;
	esac
	echo "  ($st $(( $(date +%s) - t0 )) s, load $(cut -d' ' -f1 /proc/loadavg))" | tee -a "$G/summary.txt"
done
echo "DONE $(date +%H:%M:%S)" | tee -a "$G/summary.txt"
