#!/bin/bash
# 20 × the game quits while the engine mixer thread feeds the generator (check_engine3.gd --only=quit).
# Per run: exit code, wall time, and every output line that is an error or warning other than the two notices the
# engine prints whenever a process ends while a sound is still playing.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
export XDG_DATA_HOME=$W/../xdg_quit
mkdir -p "$XDG_DATA_HOME"
cd "$R" || exit 1
ok=0
for i in $(seq 1 ${1:-20}); do
	t0=$(date +%s.%N)
	out=$(timeout -s KILL 60 godot --headless --path . -s res://tests/unit/audio_modern/check_engine3.gd -- --graphics=arcade --only=quit 2>&1)
	code=$?
	t1=$(date +%s.%N)
	bad=$(echo "$out" | grep -E 'SCRIPT ERROR|ERROR|WARNING|FEHLER|Parse Error' | grep -vE 'ObjectDB instances were leaked at exit|resources still in use at exit' | head -3)
	chk=$(echo "$out" | grep -c 'CHECK quit     OK')
	printf "Lauf %2d: Exit %d, %.2f s, CHECK quit OK %d%s\n" "$i" "$code" "$(echo "$t1 - $t0" | bc)" "$chk" "${bad:+, AUFFÄLLIG: $bad}"
	if [ "$code" -eq 0 ] && [ "$chk" -eq 1 ] && [ -z "$bad" ]; then ok=$((ok + 1)); fi
done
echo "sauber beendet: $ok von ${1:-20}"
