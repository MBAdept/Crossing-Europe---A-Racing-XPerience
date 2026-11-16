#!/usr/bin/env bash
# AS5a1 scratch (successor 3): reduced A/B set (one shot per run), the clip, the two audio timing tests again.
#   chain6.sh [steps: ab,clip,retest]   (waits for chain5)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
STEPS=",${1:-ab,clip,retest},"
cd "$S"
until grep -q "=== chain5 fertig" "$S/chain5.out" 2>/dev/null; do sleep 15; done
export SHOTS=2 AB_TIMEOUT=1500
if [[ $STEPS == *",ab,"* ]]; then
	./ab_all.sh "$S/ab" "kh" "high" "22" > "$S/ab_all_1.log" 2>&1
	./ab_all.sh "$S/ab" "hh kw" "high" "12 22" > "$S/ab_all_2.log" 2>&1
	./ab_all.sh "$S/ab" "kh hh kw" "medium" "19.5" > "$S/ab_all_3.log" 2>&1
	echo "STEP ab fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",clip,"* ]]; then
	./chain3.sh clip
	echo "STEP clip fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",retest,"* ]]; then
	cd "$WT"
	XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh engine3_checks > "$S/gate_retest_engine.log" 2>&1
	echo "STEP retest engine exit $? $(date +%H:%M)"
	XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh music_checks > "$S/gate_retest_music.log" 2>&1
	echo "STEP retest music exit $? $(date +%H:%M)"
fi
echo "=== chain6 fertig $(date +%H:%M)"
