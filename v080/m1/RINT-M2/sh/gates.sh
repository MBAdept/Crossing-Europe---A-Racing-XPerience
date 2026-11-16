#!/usr/bin/env bash
# RINT-M2 gates (from M2INT's gates.sh), one heavy job after the other; logs in RINT-M2/gates/<step>.log, one summary
# line per step in gates/summary.txt.  usage: gates.sh <step> [<step> ...]
# steps: import tests golden modernkeep render sight validate keys geometry audio determinism ergebnis perf texmem
#        builds smoke smokegles
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
G=$S/gates
mkdir -p "$G"
cd "$WT" || exit 1
N=10
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
summary() { echo "$(date -u +%H:%M) $*" | tee -a "$G/summary.txt"; }
for st in "$@"; do
	t0=$(date +%s)
	export XDG_DATA_HOME=$S/xdg/gate_$st
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"
	case "$st" in
	import)
		nice -n $N godot --headless --path . --import > "$G/import.log" 2>&1
		c=$?
		nice -n $N godot --headless --path . -s res://tests/check_scripts.gd > "$G/check_scripts.log" 2>&1
		summary "import exit $c Fehlerzeilen $(grep -ciE 'error|failed' "$G/import.log"); check_scripts exit $? – $(tail -3 "$G/check_scripts.log" | tr '\n' ' ' | cut -c1-160)"
		;;
	tests|tests2)
		nice -n $N tools/run_tests.sh > "$G/run_$st.log" 2>&1
		summary "run_tests ($st) exit $? – $(grep -E 'Tests, ' "$G/run_$st.log" | tail -1) – $(grep -cE '^CHECK .* OK' "$G/run_$st.log") CHECK OK, $(grep -cE '^CHECK .* FEHLER' "$G/run_$st.log") CHECK FEHLER"
		;;
	golden)
		mkdir -p $S/tmp_golden
		TMPDIR=$S/tmp_golden nice -n $N tools/golden.sh check > "$G/golden.log" 2>&1
		summary "golden check exit $? – $(grep -E 'GOLDEN' "$G/golden.log" | tr '\n' ' ')"
		;;
	modernkeep)
		rm -rf $S/gates/modern_keep
		mkdir -p $S/tmp_golden $S/gates/modern_keep
		KEEP=$S/gates/modern_keep TMPDIR=$S/tmp_golden nice -n $N tools/golden.sh modern-check > "$G/modern_keep.log" 2>&1
		summary "modern-check (KEEP) exit $? – $(grep -E 'GOLDEN' "$G/modern_keep.log" | tr '\n' ' ')"
		;;
	moderncheck)
		mkdir -p $S/tmp_golden
		TMPDIR=$S/tmp_golden nice -n $N tools/golden.sh modern-check > "$G/modern_check.log" 2>&1
		summary "modern-check exit $? – $(grep -E 'GOLDEN' "$G/modern_check.log" | tr '\n' ' ')"
		;;
	moderncheck2)
		mkdir -p $S/tmp_golden
		TMPDIR=$S/tmp_golden nice -n $N tools/golden.sh modern-check > "$G/modern_check2.log" 2>&1
		c=$?
		summary "modern-check (Endstand $(git rev-parse --short HEAD)) exit $c – $(grep -E 'GOLDEN' "$G/modern_check2.log" | tr '\n' ' ')"
		;;
	scripts2)
		nice -n $N godot --headless --path . -s res://tests/check_scripts.gd > "$G/check_scripts2.log" 2>&1
		c=$?
		summary "check_scripts (Endstand $(git rev-parse --short HEAD)) exit $c – $(tail -1 "$G/check_scripts2.log")"
		;;
	render)
		nice -n $N tools/run_render_checks.sh all > "$G/render_checks.log" 2>&1
		summary "render checks exit $? – $(grep -cE 'RENDER-CHECK-DATEI .* OK' "$G/render_checks.log") Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' "$G/render_checks.log") Dateien rot"
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
		summary "check-keys exit $? – $(grep -E 'CHECK' "$G/check_keys.log" | tail -1 | cut -c1-80)"
		;;
	geometry)
		nice -n $N /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --jobs 2 > "$G/sprite_geometry.log" 2>&1
		summary "check_sprite_geometry exit $? – $(grep -E 'CHECK' "$G/sprite_geometry.log" | tail -1)"
		;;
	audio)
		nice -n $N python3 tools/audio/qc/audio_qc.py > "$G/audio_qc.log" 2>&1
		summary "audio_qc exit $? – $(tail -2 "$G/audio_qc.log" | tr '\n' ' ' | cut -c1-200)"
		;;
	determinism)
		bash $S/sh/determinism.sh > "$G/determinism.log" 2>&1
		summary "determinism exit $? – $(tail -1 "$G/determinism.log")"
		;;
	ergebnis)
		: > "$G/ergebnis.log"
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
	perf)
		# the same autopilot runs on this tree and on the base 515dd51 (snap_base): Kiel – Hamburg "mittel" and "deck",
		# Dresden – Leipzig (finish in the city) "mittel"
		: > "$G/perf.log"
		for tree in head base; do
			T=$WT
			[ "$tree" = base ] && T=$S/snap_base
			for spec in "kiel_hamburg:kiel:12:medium" "kiel_hamburg:kiel:12:deck" "dresden_leipzig:dresden:15:medium"; do
				IFS=: read -r stg frm hr pre <<< "$spec"
				(cd "$T" && nice -n $N timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
					--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=$stg --from=$frm \
					--hour=$hr --weather=normal --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=$pre \
					> "$G/perf_${tree}_${stg}_${pre}.log" 2>&1)
				echo "perf $tree $stg $pre exit $? ($(grep -cE 'SCRIPT ERROR|Parse Error' "$G/perf_${tree}_${stg}_${pre}.log") Skriptfehler)" >> "$G/perf.log"
				grep -E '^PERF|^RUN' "$G/perf_${tree}_${stg}_${pre}.log" >> "$G/perf.log"
			done
		done
		summary "perf – $(grep -E '^perf' "$G/perf.log" | tr '\n' ' ')"
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
		mkdir -p "$XDG_DATA_HOME/godot"
		ln -sfn "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
		nice -n $N tools/build_linux.sh > "$G/build_linux.log" 2>&1
		c1=$?
		nice -n $N tools/build_windows.sh > "$G/build_windows.log" 2>&1
		c2=$?
		summary "build_linux exit $c1, build_windows exit $c2"
		;;
	smoke)
		rm -rf $S/smoke
		mkdir -p $S/smoke
		nice -n $N tools/smoke_modern.sh build/CrossingEurope.x86_64 $S/smoke/linux > "$G/smoke_linux.log" 2>&1
		c1=$?
		DRIVER=opengl3_es nice -n $N tools/smoke_modern.sh build/CrossingEurope.x86_64 $S/smoke/gles > "$G/smoke_gles.log" 2>&1
		c2=$?
		exe=$(ls build/*.exe 2> /dev/null | head -1)
		[ -z "$exe" ] && exe=$(ls build/windows/*.exe 2> /dev/null | head -1)
		nice -n $N tools/smoke_modern.sh "$exe" $S/smoke/windows > "$G/smoke_windows.log" 2>&1
		c3=$?
		summary "smoke linux exit $c1, gles exit $c2, windows ($exe) exit $c3 – $(cat $S/smoke/*/smoke.txt 2> /dev/null | grep -E '^SMOKE' | tr '\n' ' ')"
		;;
	esac
	echo "gate $st fertig ($(( $(date +%s) - t0 )) s, nice $N)" >> "$G/summary.txt"
done
