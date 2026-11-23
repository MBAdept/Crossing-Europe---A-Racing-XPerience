#!/usr/bin/env bash
# R7c: the gates on the final head (after perf2): Nürnberg clip again, import, check_scripts, run_tests (2nd full run),
# render checks all, modern-make with kept pictures. Progress in gates/summary.txt.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
G=$S/gates
log() { echo "$(date +%H:%M) $*" >> "$G/summary.txt"; }
until grep -q "perf2" "$G/summary.txt"; do sleep 20; done
cd "$WT"
log "final start $(git log --oneline -1)"
waitmem
CLIPS=nuernberg PREFIX=final_ "$S/clips.sh" > "$G/final_clip.log" 2>&1
log "clip $(tr '\n' ' ' < $G/final_clip.log)"
cd "$WT"
nice -n 10 godot --headless --path . --import > "$G/final_import.log" 2>&1
log "import exit $? – $(grep -ciE 'error|fehler' $G/final_import.log) Zeilen mit error/fehler"
nice -n 10 godot --headless --path . -s res://tests/check_scripts.gd > "$G/final_check_scripts.log" 2>&1
log "check_scripts exit $? – $(grep -a 'Skripte geprüft' $G/final_check_scripts.log | tail -1)"
waitmem
nice -n 10 tools/run_tests.sh > "$G/final_run_tests.log" 2>&1
c=$?
log "run_tests exit $c – $(grep -aE 'Tests, ' $G/final_run_tests.log | tail -1) – $(grep -acE '^CHECK .* OK' $G/final_run_tests.log) CHECK OK, $(grep -acE '^CHECK .* FEHLER' $G/final_run_tests.log) CHECK FEHLER"
waitmem
export XDG_DATA_HOME=$S/xdg_final
mkdir -p "$XDG_DATA_HOME"
nice -n 10 tools/run_render_checks.sh all > "$G/final_render_checks.log" 2>&1
log "render checks exit $? – $(grep -cE 'RENDER-CHECK-DATEI .* OK' $G/final_render_checks.log) Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' $G/final_render_checks.log) Dateien rot"
waitmem
rm -rf "$G/modern_final"
mkdir -p "$S/tmp_golden"
KEEP=$G/modern_final TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-make > "$G/final_modern_make.log" 2>&1
log "modern-make exit $? – $(tail -2 $G/final_modern_make.log | tr '\n' ' ')"
log "final fertig"
