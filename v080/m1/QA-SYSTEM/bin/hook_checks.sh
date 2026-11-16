#!/bin/bash
# The generic v0.8.0 hook of tools/run_tests.sh (every tests/race3d/check_*.gd and tests/sim/modern_*.gd, headless,
# same pass rule), run on its own because run_tests.sh skips it after any earlier failure.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/hook
mkdir -p "$OUT"
export XDG_DATA_HOME=$S/xdg_hook
rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
cd "$WT" || exit 2
FAIL=0
for f in $(ls tests/race3d/check_*.gd tests/sim/modern_*.gd 2>/dev/null | sort); do
	n=$(basename "$f" .gd)
	t0=$SECONDS
	nice -n 10 timeout 600 godot --headless --path . -s "res://$f" > "$OUT/$n.log" 2>&1
	code=$?
	okl=$(grep -cE "^CHECK +[^ ]+ +OK" "$OUT/$n.log")
	fl=$(grep -cE "^CHECK +[^ ]+ +FEHLER" "$OUT/$n.log")
	se=$(grep -cE "SCRIPT ERROR|Parse Error" "$OUT/$n.log")
	verdict=OK
	if [ $code -ne 0 ] || [ "$fl" -gt 0 ] || [ "$se" -gt 0 ] || [ "$okl" -eq 0 ]; then verdict=FEHLER; FAIL=1; fi
	echo "$verdict $n exit=$code ok=$okl fehler=$fl scripterr=$se $((SECONDS - t0)) s"
	[ "$verdict" = FEHLER ] && grep -E "^CHECK +[^ ]+ +FEHLER|SCRIPT ERROR" "$OUT/$n.log" | head -5 | cut -c1-250 | sed 's/^/    /'
done
echo "HOOK $([ $FAIL -eq 0 ] && echo bestanden || echo FEHLGESCHLAGEN)"
