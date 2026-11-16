#!/bin/bash
# All gates of RINT-A on the current head, one after the other (heavy jobs never in parallel).
#   gates.sh [steps...]   steps: import tests golden render path sight validate ergebnis drive warm (default: all)
B=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin
source $B/env.sh
steps=("$@")
[ ${#steps[@]} -eq 0 ] && steps=(import tests golden render path sight validate ergebnis drive warm)
G=$S/gates
mkdir -p "$G"
echo "HEAD $(git rev-parse --short HEAD) $(date +%H:%M:%S)" | tee -a "$G/summary.txt"
for st in "${steps[@]}"; do
	t0=$(date +%s)
	case "$st" in
	import)
		nice -n 10 godot --headless --path . --import > "$G/import.log" 2>&1
		echo "import rc=$? errors: $(grep -ciE '^ERROR|SCRIPT ERROR|failed' "$G/import.log")" | tee -a "$G/summary.txt" ;;
	tests)
		(unset XDG_DATA_HOME; nice -n 10 tools/run_tests.sh > "$G/run_tests.log" 2>&1)
		echo "run_tests rc=$? $(grep -E '==> Tests' "$G/run_tests.log")" | tee -a "$G/summary.txt" ;;
	golden)
		(unset XDG_DATA_HOME; nice -n 10 tools/golden.sh check > "$G/golden.log" 2>&1)
		echo "golden rc=$? $(grep -E 'GOLDEN' "$G/golden.log" | tail -1)" | tee -a "$G/summary.txt" ;;
	render)
		(unset XDG_DATA_HOME; unset MESA_SHADER_CACHE_DIR; nice -n 10 tools/run_render_checks.sh all > "$G/render.log" 2>&1)
		echo "render rc=$? $(grep -E '==>' "$G/render.log" | tail -1)" | tee -a "$G/summary.txt" ;;
	path)
		nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$G/path_full.log" 2>&1
		echo "path_check --full rc=$? $(grep -cE '^CHECK .* OK' "$G/path_full.log") OK, $(grep -cE 'FEHLER' "$G/path_full.log") FEHLER" | tee -a "$G/summary.txt" ;;
	sight)
		nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$G/sight_full.log" 2>&1
		echo "sight --full rc=$? $(grep -cE '^CHECK .* OK' "$G/sight_full.log") OK, $(grep -cE 'FEHLER' "$G/sight_full.log") FEHLER" | tee -a "$G/summary.txt" ;;
	validate)
		python3 tools/blender/validate_models.py --report > "$G/validate.log" 2>&1
		echo "validate rc=$? $(grep -E 'CHECK models' "$G/validate.log" | tail -1)" | tee -a "$G/summary.txt" ;;
	ergebnis)
		for m in arcade modern; do
			nice -n 10 godot --headless --path . -s res://tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel \
				--graphics=$m --seed=11 --timescale=40 > "$G/stage_$m.log" 2>&1
			echo "run_stage $m rc=$?" | tee -a "$G/summary.txt"
		done
		python3 - "$G" << 'EOF' | tee -a "$G/summary.txt"
import json, sys
g = sys.argv[1]
def res(m):
    for line in open(f"{g}/stage_{m}.log"):
        if line.startswith("ERGEBNIS "):
            return json.loads(line[len("ERGEBNIS "):])
    return None
a, m = res("arcade"), res("modern")
if a is None or m is None:
    print("ERGEBNIS fehlt", a is None, m is None)
else:
    keys = sorted(set(a) | set(m))
    diff = [k for k in keys if a.get(k) != m.get(k)]
    print("ERGEBNIS %d Schlüssel, verschieden: %s" % (len(keys), diff))
EOF
		;;
	drive)
		bash $B/drive.sh final > "$G/drive.txt" 2>&1
		echo "drive: $(head -1 "$G/drive.txt")" | tee -a "$G/summary.txt" ;;
	warm)
		bash $B/warm.sh final > "$G/warm.txt" 2>&1
		echo "warm: $(grep -E 'RENDER-CHECK' "$G/warm.txt" | cut -c1-200)" | tee -a "$G/summary.txt" ;;
	esac
	echo "  ($st $(( $(date +%s) - t0 )) s, load $(cut -d' ' -f1 /proc/loadavg))" | tee -a "$G/summary.txt"
done
echo "DONE $(date +%H:%M:%S)" | tee -a "$G/summary.txt"
