#!/usr/bin/env bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
until grep -q BATCH3_DONE $S/batch3.log 2>/dev/null; do sleep 30; done
echo "start gates $(date -u +%H:%M)"
$S/sh/gates.sh import scripts tests golden modern render sight path perf
echo GATES_DONE
