#!/usr/bin/env bash
# R7c: run a command in the worktree with the scratch environment (nice 10, memory guard)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
cd "$WT"
waitmem
exec nice -n 10 "$@"
