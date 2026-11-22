#!/bin/bash
# R7a: the render checks that guard the fixes of test build 1 and the corridor's consumers, one file at a time.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
mkdir -p "$S/rc" "$S/xdg/rc"
export TMPDIR=$S/tmp
for f in "$@"; do
	t0=$SECONDS
	(cd "$WT" && XDG_DATA_HOME=$S/xdg/rc nice -n 10 tools/run_render_checks.sh modern "$f" > "$S/rc/$f.log" 2>&1)
	echo "$(date -u +%H:%M:%S) $f exit=$? $((SECONDS - t0)) s: $(grep -E 'RENDER-CHECK-DATEI' "$S/rc/$f.log" | tr '\n' ' ')"
done
