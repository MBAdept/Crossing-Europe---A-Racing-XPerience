#!/bin/bash
# ab.sh <out_prefix> [ab_shot args...] : tools/ab_shot.sh of the head worktree with QA env
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
cd $W
t0=$SECONDS
tools/ab_shot.sh "$@" > $1.tool.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $1.tool.log
tail -2 $1.tool.log
