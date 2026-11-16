#!/bin/bash
# Last chain on the final commit, one job after the other: Modern A/B captures of all five cars (the shift thump law
# changed), Movie Maker sync probe, the complete test run (second and last), the Arcade golden check (once).
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
mkdir -p "$W/ab/ab_f5" /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/xdg_full2
cp "$W"/ab/ab_f1/*_arcade.wav "$W"/ab/ab_f1/*_arcade.wav.json "$W/ab/ab_f5/"
PROFILES=modern bash "$W/ab_all.sh" ab_f5 > "$W/ab_f5.log" 2>&1
echo "AB FERTIG $(date -u +%H:%M:%S)"
bash "$W/movie_probe.sh" gran_turismo --audio-sync > "$W/movie_final2.log" 2>&1
echo "MOVIE FERTIG $(date -u +%H:%M:%S)"
cd "$R" || exit 1
XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/xdg_full2 nice -n 5 tools/run_tests.sh > "$W/tests_full_2.log" 2>&1
echo "RUN_TESTS EXIT $? $(date -u +%H:%M:%S)"
nice -n 5 tools/golden.sh check > "$W/golden_final.log" 2>&1
echo "GOLDEN EXIT $? $(date -u +%H:%M:%S)"
echo "KETTE6 FERTIG"
