#!/usr/bin/env bash
# M2ZS1: the gates on the final head, one after the other (nice 10). Summary: gates/summary.txt, logs gates/<step>.log
# usage: gates.sh [step …]   (default: all steps in order)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-2
G=$S/gates
X=$S/data/gates
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
	echo "== $name start $(date -u +%T) head $(git -C "$W" rev-parse --short HEAD)" >> "$SUM"
	"$@" > "$G/$name.log" 2>&1
	local code=$?
	echo "== $name exit=$code secs=$(( $(date +%s) - t0 ))" >> "$SUM"
}
xdg() {
	rm -rf "$X/$1"
	mkdir -p "$X/$1"
	echo "$X/$1"
}
build_xdg() {
	local d
	d=$(xdg build)
	mkdir -p "$d/godot"
	ln -s "$HOME/.local/share/godot/export_templates" "$d/godot/export_templates"
	echo "$d"
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
want import && step import env XDG_DATA_HOME="$(xdg import)" nice -n 10 godot --headless --path . --import
want check_scripts && step check_scripts env XDG_DATA_HOME="$(xdg cs)" nice -n 10 godot --headless --path . -s res://tests/check_scripts.gd
want run_tests && step run_tests env XDG_DATA_HOME="$(xdg rt)" nice -n 10 tools/run_tests.sh
want sight && step sight env XDG_DATA_HOME="$(xdg sight)" nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full
want path && step path env XDG_DATA_HOME="$(xdg path)" nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full
want render_checks && step render_checks env XDG_DATA_HOME="$(xdg rc)" nice -n 10 tools/run_render_checks.sh all
want golden_check && step golden_check env KEEP="$G/golden_keep" nice -n 10 tools/golden.sh check
want modern_check && step modern_check env KEEP="$G/modern_keep" nice -n 10 tools/golden.sh modern-check
if want build_linux; then
	BX=$(build_xdg)
	step build_linux env XDG_DATA_HOME="$BX" nice -n 10 tools/build_linux.sh
fi
if want build_windows; then
	BX=$(build_xdg)
	step build_windows env XDG_DATA_HOME="$BX" nice -n 10 tools/build_windows.sh
fi
want smoke_linux && step smoke_linux env -u TMPDIR nice -n 10 tools/smoke_modern.sh build/CrossingEurope.x86_64 "$G/smoke_linux"
want smoke_gles && step smoke_gles env -u TMPDIR DRIVER=opengl3_es nice -n 10 tools/smoke_modern.sh build/CrossingEurope.x86_64 "$G/smoke_gles"
want smoke_windows && step smoke_windows env -u TMPDIR nice -n 10 tools/smoke_modern.sh build/CrossingEurope.exe "$G/smoke_windows"
echo "== fertig $(date -u +%T)" >> "$SUM"
