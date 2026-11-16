cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export MESA_SHADER_CACHE_DIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/mesa LP_NUM_THREADS=2
PRESETS="high medium" SHOT_TIMES=3 tools/ab_sheet.sh /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/sheet > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/sheet.log 2>&1
echo "ab_sheet high/medium exit $?"
SCREEN=1280x800 PRESETS="deck" SHOT_TIMES=3 tools/ab_sheet.sh /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/deck S1 N2 U1 > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/deck.log 2>&1
echo "ab_sheet deck exit $?"
