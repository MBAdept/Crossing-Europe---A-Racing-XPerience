#!/usr/bin/env bash
# R4: the gates on the head, one after the other. Summary: gates/summary.txt, logs gates/<step>.log
# usage: gates.sh [step …]   (default: all steps in order). NICE=10 once QA_M2_FERTIG exists, else 19.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
W=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
G=${GATES:-$S/gates}
X=$S/data/gates
N=${NICE:-19}
[ -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && N=${NICE:-10}
mkdir -p "$G" "$X"
cd "$W" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa_gates
mkdir -p "$MESA_SHADER_CACHE_DIR"
SUM=$G/summary.txt
step() {
	local name=$1
	shift
	local t0
	t0=$(date +%s)
	echo "== $name start $(date -u +%T) head $(git -C "$W" rev-parse --short HEAD 2>/dev/null) nice $N" >> "$SUM"
	"$@" > "$G/$name.log" 2>&1
	local code=$?
	echo "== $name exit=$code secs=$(( $(date +%s) - t0 ))" >> "$SUM"
}
xdg() {
	rm -rf "$X/$1"
	mkdir -p "$X/$1"
	echo "$X/$1"
}
want() {
	[ ${#STEPS[@]} -eq 0 ] && return 0
	local s
	for s in "${STEPS[@]}"; do
		[ "$s" = "$1" ] && return 0
	done
	return 1
}
STEPS=("$@")
want import && step import env XDG_DATA_HOME="$(xdg import)" nice -n $N godot --headless --path . --import
want check_scripts && step check_scripts env XDG_DATA_HOME="$(xdg cs)" nice -n $N godot --headless --path . -s res://tests/check_scripts.gd
want run_tests && step run_tests env XDG_DATA_HOME="$(xdg rt)" nice -n $N tools/run_tests.sh
want sight && step sight env XDG_DATA_HOME="$(xdg sight)" nice -n $N godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full
want path && step path env XDG_DATA_HOME="$(xdg path)" nice -n $N godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full
want render_checks && step render_checks env XDG_DATA_HOME="$(xdg rc)" RENDER_CHECK_TIMEOUT=2400 nice -n $N tools/run_render_checks.sh all
want golden_check && step golden_check env KEEP="$G/golden_keep" nice -n $N tools/golden.sh check
want modern_check && step modern_check env KEEP="$G/modern_keep" nice -n $N tools/golden.sh modern-check
want modern_make && step modern_make env KEEP="$G/modern_make_keep" nice -n $N tools/golden.sh modern-make
echo "== fertig $(date -u +%T)" >> "$SUM"
