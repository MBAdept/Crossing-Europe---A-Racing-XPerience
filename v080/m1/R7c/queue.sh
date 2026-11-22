#!/usr/bin/env bash
# R7c: the heavy jobs one after the other.  queue.sh <step> ...
#   lodcheck | pics | wald | perf | tests | golden | mcheck | render | sight
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
G=$S/gates
mkdir -p "$G"
log() { echo "$(date +%H:%M) $*" | tee -a "$G/summary.txt"; }
cd "$WT"
for st in "$@"; do
	waitmem
	case $st in
	lodcheck)
		mkdir -p "$S/shots/lodcheck"
		timeout 1200 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
			--fixed-fps 60 -s res://tests/race3d/render/check_lod_band.gd -- --graphics=modern --gfx-sync --audio-sync \
			--save=$S/shots/lodcheck > "$G/lodcheck.log" 2>&1
		log "check_lod_band exit $? $(grep -E 'RENDER-CHECK' $G/lodcheck.log | tr '\n' ' ')" ;;
	far078)
		for p in high medium; do
			"$S/k5.sh" k6_scene far/b078_$p --mode=lodcol "--models=props/city_paris_haussmann,props/city_belgian_terrace,props/city_dutch_canal,props/house_med,props/city_french_sud,props/city_belgian_stone" \
				--dists=60,100,140,200,250 --x=20 --look=race --hour=12 --preset=$p --tile=200x160 --far_sun=0.78 --reps=lod0 > "$G/far078_$p.log" 2>&1
		done
		log "far078 fertig" ;;
	cutout)
		timeout 900 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
			-s res://tools/r7c_tmp/cutout_cost.gd > "$G/cutout.log" 2>&1
		log "cutout $(grep CUTOUT-COST $G/cutout.log | tr '\n' ' ')" ;;
	pics)
		SHOTS=2 "$S/ab_all.sh" "$S/shots/city" "hh:high:12 hh:high:22 hh:medium:19.5 nu:high:12 nu:high:22 nu:medium:19.5 pa:high:12 pa:high:22 pa:medium:19.5 am:high:12 am:high:22 am:medium:19.5 be:high:12 be:high:22 be:medium:19.5 ly_out:high:12 ly_out:high:22 ly_out:medium:19.5 pa:medium:12 nu:medium:12" > "$G/pics.log" 2>&1
		log "pics $(grep -c '^AB' $G/pics.log) Läufe, $(grep -c 'exit 0 Fehlerzeilen 0' $G/pics.log) sauber" ;;
	basepics)
		SHOTS=2 "$S/base_ab.sh" "$S/shots/city_base" "pa:high:12 nu:medium:12 pa:medium:12 ly_out:high:12" > "$G/basepics.log" 2>&1
		log "basepics $(grep -c '^AB' $G/basepics.log) Läufe" ;;
	wald)
		SHOTS=2,5 "$S/ab_all.sh" "$S/shots/wald" "wald:medium:12 wald:high:12 wald:medium:22" > "$G/wald.log" 2>&1
		SHOTS=2,5 "$S/base_ab.sh" "$S/shots/wald_base" "wald:medium:12" >> "$G/wald.log" 2>&1
		log "wald $(grep '^AB' $G/wald.log | tr '\n' ' ')" ;;
	perf)
		"$S/stage.sh" r7c_kh_medium medium kiel_hamburg kiel 12 40 > "$G/perf.log" 2>&1
		BASE=1 "$S/stage.sh" base_kh_medium medium kiel_hamburg kiel 12 40 >> "$G/perf.log" 2>&1
		log "perf $(cat $G/perf.log | tr '\n' ' ')" ;;
	tests)
		rm -rf "$WT/tools/kritik"
		nice -n 10 tools/run_tests.sh > "$G/run_tests.log" 2>&1
		log "run_tests exit $? – $(grep -E 'Tests, ' $G/run_tests.log | tail -1) – $(grep -cE '^CHECK .* OK' $G/run_tests.log) CHECK OK, $(grep -cE '^CHECK .* FEHLER' $G/run_tests.log) CHECK FEHLER" ;;
	golden)
		mkdir -p "$S/tmp_golden"
		TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh check > "$G/golden.log" 2>&1
		log "golden check exit $? – $(grep -E 'GOLDEN|identisch' $G/golden.log | tr '\n' ' ')" ;;
	mcheck)
		mkdir -p "$S/tmp_golden" "$G/modern_keep"
		KEEP=$G/modern_keep TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-check > "$G/modern_check.log" 2>&1
		log "modern-check exit $? – $(grep -E 'GOLDEN|identisch|anders|MODERN' $G/modern_check.log | tr '\n' ' ' | cut -c1-400)" ;;
	render)
		rm -rf "$WT/tools/kritik"
		nice -n 10 tools/run_render_checks.sh all > "$G/render_checks.log" 2>&1
		log "render checks exit $? – $(grep -cE 'RENDER-CHECK-DATEI .* OK' $G/render_checks.log) Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' $G/render_checks.log) Dateien rot" ;;
	sight)
		nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$G/modern_sight_full.log" 2>&1
		c1=$?
		nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$G/modern_path_full.log" 2>&1
		c2=$?
		log "modern_sight --full exit $c1 ($(grep -cE '^CHECK .* OK' $G/modern_sight_full.log) OK, $(grep -cE '^CHECK .* FEHLER' $G/modern_sight_full.log) FEHLER); modern_path_check --full exit $c2 ($(grep -cE '^CHECK .* OK' $G/modern_path_full.log) OK, $(grep -cE '^CHECK .* FEHLER' $G/modern_path_full.log) FEHLER)" ;;
	esac
done
log "queue fertig: $*"
