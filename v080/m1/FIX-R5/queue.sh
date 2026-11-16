#!/usr/bin/env bash
# FIX-R5 heavy-job queue: one job after the other (contract rule 8); log in queue.log.  queue.sh <step…>
F=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6
export XDG_DATA_HOME=$F/xdg_gates
mkdir -p "$XDG_DATA_HOME" "$F/gates"
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$F/queue.log"; }
for step in "$@"; do
	t0=$SECONDS
	cd "$WT" || exit 1
	case "$step" in
	r4mix)
		WT=$F/r4mix "$F/shots.sh" r4mix u1_ausfahrt u1_nacht >> "$F/queue.log" 2>&1 ;;
	pics_day)
		"$F/shots.sh" fix2 u1_anfahrt u1_ausfahrt u1_innen somport >> "$F/queue.log" 2>&1 ;;
	pics_night)
		"$F/shots.sh" fix2 somport_nacht kb_nacht >> "$F/queue.log" 2>&1 ;;
	pics_deck)
		PRESET=deck SCREEN=1280x800 SUFFIX=_deck "$F/shots.sh" fix2 u1_nacht u1_anfahrt >> "$F/queue.log" 2>&1 ;;
	pics_arcade_somport_nacht)
		MODE=arcade "$F/shots.sh" fix2 somport_nacht >> "$F/queue.log" 2>&1 ;;
	pics_arcade_deck)
		MODE=arcade SCREEN=1280x800 SUFFIX=_deck "$F/shots.sh" fix2 u1_nacht u1_anfahrt >> "$F/queue.log" 2>&1 ;;
	sight)
		nice -n $NICE timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$F/gates/sight.log" 2>&1
		log "sight exit $? $(grep -E 'OK|FEHLER' "$F/gates/sight.log" | tail -2 | tr '\n' ' ' | cut -c1-300)" ;;
	path)
		nice -n $NICE timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$F/gates/path.log" 2>&1
		log "path exit $? $(grep -E 'OK|FEHLER' "$F/gates/path.log" | tail -2 | tr '\n' ' ' | cut -c1-300)" ;;
	scripts)
		nice -n $NICE timeout 600 godot --headless --path . -s res://tests/check_scripts.gd > "$F/gates/check_scripts.log" 2>&1
		log "check_scripts exit $? $(tail -1 "$F/gates/check_scripts.log")" ;;
	tests)
		nice -n $NICE timeout 3600 tools/run_tests.sh > "$F/gates/run_tests.log" 2>&1
		log "run_tests exit $? $(tail -3 "$F/gates/run_tests.log" | tr '\n' ' ' | cut -c1-400)" ;;
	render)
		XDG_DATA_HOME=$F/xdg_render nice -n $NICE timeout 7200 tools/run_render_checks.sh all > "$F/gates/render_checks.log" 2>&1
		log "render_checks exit $? $(tail -3 "$F/gates/render_checks.log" | tr '\n' ' ' | cut -c1-400)" ;;
	golden)
		nice -n $NICE timeout 3600 tools/golden.sh check > "$F/gates/golden_check.log" 2>&1
		log "golden check exit $? $(grep -E 'GOLDEN' "$F/gates/golden_check.log" | tr '\n' ' ' | cut -c1-400)" ;;
	modern)
		KEEP=$F/gates/modern_keep nice -n $NICE timeout 5400 tools/golden.sh modern-check > "$F/gates/golden_modern.log" 2>&1
		log "golden modern-check exit $? $(grep -E 'GOLDEN|identisch|anders' "$F/gates/golden_modern.log" | tail -4 | tr '\n' ' ' | cut -c1-400)" ;;
	perf_kh_new)
		"$F/perf.sh" new kh >> "$F/queue.log" 2>&1 ;;
	perf_kh_base)
		"$F/perf.sh" base kh >> "$F/queue.log" 2>&1 ;;
	*)
		log "unknown step $step" ;;
	esac
	log "STEP $step done in $((SECONDS - t0)) s"
done
log "QUEUE DONE $*"
