#!/bin/bash
# QA-MID: gates of the fix head (resumable): full unit/integration tests, then the render checks
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
head=$(git rev-parse --short HEAD)
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/xdg/fixgates; mkdir -p $XDG_DATA_HOME
if ! grep -q "Tests bestanden" /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/run_tests_$head.log 2>/dev/null; then
	t0=$SECONDS; nice -n 10 timeout 7200 tools/run_tests.sh > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/run_tests_$head.log 2>&1
	echo "$(date +%T) gates run_tests $head exit=$? $((SECONDS - t0)) s" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
fi
if ! grep -q -E "bestanden|OK" /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/render_checks_$head.done 2>/dev/null; then
	t0=$SECONDS; nice -n 10 timeout 7200 tools/run_render_checks.sh > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/render_checks_$head.log 2>&1; rc=$?
	echo "rc=$rc" > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/render_checks_$head.done; [ $rc = 0 ] && echo OK >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/gates/render_checks_$head.done
	echo "$(date +%T) gates render_checks $head exit=$rc $((SECONDS - t0)) s" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
fi
echo "FIXGATES DONE $head $(date +%T)" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
