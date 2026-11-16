# waits until the station change is in the worktree (flag), then modern-make
n=0; while [ ! -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/FLAG_STATION_DONE ] && [ $n -lt 720 ]; do sleep 10; n=$((n+1)); done
echo "flag: $(cat /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/FLAG_STATION_DONE 2>/dev/null)"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/xdg/gate_modernmake MESA_SHADER_CACHE_DIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/mesa LP_NUM_THREADS=2
rm -rf $XDG_DATA_HOME; mkdir -p $XDG_DATA_HOME /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/tmp_golden
TMPDIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/tmp_golden nice -n 10 tools/golden.sh modern-make > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/gates/modern_make.log 2>&1
echo "modern-make exit $?" | tee -a /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/gates/summary.txt
tail -3 /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/gates/modern_make.log
