#!/usr/bin/env bash
# M2INT gates, one heavy job after the other; logs in m1/M2INT/gates/<step>.log, one summary line per step in
# gates/summary.txt.  usage: gates.sh <step> [<step> ...]
# steps: import tests golden render sight validate keys bake geometry audio ergebnis autopilot texmem builds
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
G=$S/gates
mkdir -p "$G"
cd "$WT" || exit 1
nicev() { if [ -f "$LEAD/ZS1_FERTIG" ]; then echo 10; else echo 19; fi; }
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
summary() { echo "$(date -u +%H:%M) $*" | tee -a "$G/summary.txt"; }
for st in "$@"; do
	t0=$(date +%s)
	N=$(nicev)
	export XDG_DATA_HOME=$S/xdg_gate_$st
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"
	case "$st" in
	import)
		nice -n $N godot --headless --path . --import > "$G/import.log" 2>&1
		summary "import exit $? Fehlerzeilen $(grep -ciE 'error|failed' "$G/import.log")"
		;;
	tests)
		nice -n $N tools/run_tests.sh > "$G/run_tests.log" 2>&1
		summary "run_tests exit $? – $(grep -E '==> Tests' "$G/run_tests.log" | tail -1) – $(grep -E 'Tests, ' "$G/run_tests.log" | tail -1)"
		;;
	golden)
		TMPDIR=$S/tmp_golden nice -n $N tools/golden.sh check > "$G/golden.log" 2>&1
		summary "golden check exit $? – $(grep -E 'GOLDEN' "$G/golden.log" | tr '\n' ' ')"
		;;
	render)
		nice -n $N tools/run_render_checks.sh all > "$G/render_checks.log" 2>&1
		summary "render checks exit $? – $(grep -cE 'RENDER-CHECK-DATEI .* OK' "$G/render_checks.log") Dateien OK, $(grep -cE 'FEHLER' "$G/render_checks.log") FEHLER-Zeilen"
		;;
	sight)
		nice -n $N timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$G/modern_sight_full.log" 2>&1
		c1=$?
		nice -n $N timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$G/modern_path_full.log" 2>&1
		c2=$?
		summary "modern_sight --full exit $c1 ($(grep -cE '^CHECK .* OK' "$G/modern_sight_full.log") OK, $(grep -cE '^CHECK .* FEHLER' "$G/modern_sight_full.log") FEHLER); modern_path_check --full exit $c2 ($(grep -cE '^CHECK .* OK' "$G/modern_path_full.log") OK, $(grep -cE '^CHECK .* FEHLER' "$G/modern_path_full.log") FEHLER)"
		;;
	validate)
		nice -n $N python3 tools/blender/validate_models.py --report > "$G/validate.log" 2>&1
		summary "validate exit $? – $(grep -E 'CHECK' "$G/validate.log" | tail -1)"
		;;
	keys)
		nice -n $N /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > "$G/check_keys.log" 2>&1
		summary "check-keys exit $? – $(grep -E 'CHECK' "$G/check_keys.log" | tail -1 | cut -c1-60)"
		;;
	bake)
		nice -n $N godot --headless --path . -s res://tools/models/bake_models.gd -- --only="*" > "$G/bake_all.log" 2>&1
		c=$?
		python3 tools/blender/export_models.py --manifest-only >> "$G/bake_all.log" 2>&1
		summary "zweiter Bake aller Modelle exit $c – $(tail -3 "$G/bake_all.log" | head -1) – git status: $(git status --porcelain assets/models | wc -l) geänderte Dateien unter assets/models"
		;;
	geometry)
		nice -n $N /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --jobs 1 > "$G/sprite_geometry.log" 2>&1
		summary "check_sprite_geometry exit $? – $(grep -E 'CHECK' "$G/sprite_geometry.log" | tail -1)"
		;;
	audio)
		nice -n $N python3 tools/audio/qc/audio_qc.py > "$G/audio_qc.log" 2>&1
		summary "audio_qc exit $? – $(grep -cE '^QC .* OK' "$G/audio_qc.log") OK, $(grep -cE '^QC .* FEHLER' "$G/audio_qc.log") FEHLER – $(tail -2 "$G/audio_qc.log" | tr '\n' ' ' | cut -c1-200)"
		;;
	ergebnis)
		for spec in "kiel_hamburg::12:normal" "dev_testetappe::21:rain" "saragossa_pau:saragossa:10:snow"; do
			IFS=: read -r stg frm hr wx <<< "$spec"
			for m in arcade modern; do
				args=(--stage=$stg --hour=$hr --weather=$wx --seed=7 --timescale=40 --max-seconds=1800 --graphics=$m)
				[ -n "$frm" ] && args+=(--from=$frm)
				nice -n $N timeout 2000 godot --headless --path . -s res://tests/race/run_stage.gd -- "${args[@]}" \
					> "$G/ergebnis_${stg}_$m.log" 2>&1
				echo "run_stage $stg $m exit $?" >> "$G/ergebnis.log"
			done
			python3 - "$G/ergebnis_${stg}_arcade.log" "$G/ergebnis_${stg}_modern.log" >> "$G/ergebnis.log" <<'EOF'
import json, sys
def res(p):
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith("ERGEBNIS "):
            return json.loads(line[9:])
    return None
a, m = res(sys.argv[1]), res(sys.argv[2])
if a is None or m is None:
    print("ERGEBNIS fehlt:", sys.argv[1] if a is None else sys.argv[2])
else:
    keys = sorted(set(a) | set(m))
    diff = [k for k in keys if k not in ("gfx", "gfx_fallback") and a.get(k) != m.get(k)]
    print("ERGEBNIS %s: %d Schlüssel, %s" % (sys.argv[1].split("ergebnis_")[1].rsplit("_", 1)[0], len(keys),
        "identisch (außer gfx)" if not diff else "VERSCHIEDEN: " + ", ".join(diff)))
EOF
		done
		summary "ergebnis – $(grep -E '^ERGEBNIS' "$G/ergebnis.log" | tr '\n' ' ')"
		;;
	autopilot)
		for spec in "kiel_hamburg:kiel:12" "dresden_leipzig:dresden:15"; do
			IFS=: read -r stg frm hr <<< "$spec"
			nice -n $N timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
				--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=$stg --from=$frm \
				--hour=$hr --weather=normal --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=medium \
				> "$G/autopilot_${stg}.log" 2>&1
			echo "autopilot $stg exit $? ($(grep -cE 'SCRIPT ERROR|Parse Error' "$G/autopilot_${stg}.log") Skriptfehler)" >> "$G/autopilot.log"
			grep -E '^PERF|^RUN' "$G/autopilot_${stg}.log" >> "$G/autopilot.log"
		done
		summary "autopilot – $(grep -E '^autopilot' "$G/autopilot.log" | tr '\n' ' ')"
		;;
	texmem)
		for m in arcade modern; do
			for pos in "kiel_hamburg kiel 2 12" "dortmund_frankfurt dortmund 221 19.5"; do
				set -- $pos
				nice -n $N timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
					--audio-driver Dummy --resolution 1280x720 -s "$S/probe/texmem_probe.gd" -- --graphics=$m --mode=$m \
					--stage=$1 --from=$2 --km=$3 --hour=$4 --secs=20 2>&1 | grep -E "^TEXMEM|SCRIPT ERROR"
			done
		done > "$G/texmem.log" 2>&1
		summary "texmem – $(grep -c '^TEXMEM' "$G/texmem.log") Messungen"
		;;
	builds)
		# the export reads its templates from $XDG_DATA_HOME/godot/export_templates: link the installed ones in
		mkdir -p "$XDG_DATA_HOME/godot"
		ln -sfn "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
		nice -n $N tools/build_linux.sh > "$G/build_linux.log" 2>&1
		c1=$?
		nice -n $N tools/build_windows.sh > "$G/build_windows.log" 2>&1
		c2=$?
		summary "build_linux exit $c1, build_windows exit $c2"
		;;
	esac
	echo "gate $st fertig ($(( $(date +%s) - t0 )) s, nice $N)" >> "$G/summary.txt"
done
