#!/usr/bin/env bash
# R6: the three real-time audio tests that failed in the full run (load ~25, nice 19) again, alone, on the head and
# on the base copy – to show whether they depend on R6 code or on the load of the machine.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
G=$S/gates
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
for where in head base; do
	if [ $where = head ]; then P=$WT; else P=$S/base; fi
	for t in test_engine3_checks test_modern_checks test_music_checks; do
		mkdir -p "$S/xdg/audio_$where"
		cd "$P" || exit 1
		T0=$SECONDS
		XDG_DATA_HOME=$S/xdg/audio_$where nice -n "$NICE" tools/run_tests.sh "$t" > "$G/audio_${where}_$t.log" 2>&1
		echo "$where $t exit $? ($((SECONDS - T0)) s) load $(cut -d' ' -f1 /proc/loadavg): $(grep -E '^[0-9]+ Tests,' "$G/audio_${where}_$t.log")"
		grep -E "^FAIL" "$G/audio_${where}_$t.log" | cut -c1-160
	done
done
echo "AUDIO_RETEST DONE $(date +%H:%M)"
