#!/usr/bin/env bash
# Scratch (R1a): the three closing gates, one after the other. Logs in m1/R1a/tmp/, one summary line per gate on stdout.
# Usage: gates.sh [tests] [render] [golden]   (default: all three)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1
cd "$W" || exit 1
export TMPDIR="$S/tmpdir"
mkdir -p "$TMPDIR" "$S/xdg_tests" "$S/xdg_render" "$S/mesa"
WHAT="${*:-tests render golden}"
for g in $WHAT; do
	t0=$SECONDS
	case "$g" in
	tests)
		rm -rf "$S/xdg_tests" && mkdir -p "$S/xdg_tests"
		XDG_DATA_HOME="$S/xdg_tests" nice -n 10 tools/run_tests.sh >"$S/tmp/run_tests.log" 2>&1
		code=$?
		echo "GATE tests exit $code ($((SECONDS - t0)) s): $(tail -1 "$S/tmp/run_tests.log")"
		;;
	render)
		rm -rf "$S/xdg_render" && mkdir -p "$S/xdg_render"
		XDG_DATA_HOME="$S/xdg_render" MESA_SHADER_CACHE_DIR="$S/mesa" tools/run_render_checks.sh all >"$S/tmp/render_checks.log" 2>&1
		code=$?
		echo "GATE render exit $code ($((SECONDS - t0)) s): $(tail -1 "$S/tmp/render_checks.log")"
		;;
	golden)
		MESA_SHADER_CACHE_DIR="$S/mesa" tools/golden.sh check >"$S/tmp/golden.log" 2>&1
		code=$?
		echo "GATE golden exit $code ($((SECONDS - t0)) s): $(grep -E '^GOLDEN' "$S/tmp/golden.log" | tail -1)"
		;;
	esac
done
