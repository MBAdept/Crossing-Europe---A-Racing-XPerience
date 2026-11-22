#!/bin/bash
# golden.sh : tools/golden.sh check (Arcade identity) once, under the heavy lock; log $S/logs/golden_check.log
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
[ -e $S/logs/golden.done ] && exit 0
exec 9>$S/heavy.lock
flock 9
export XDG_DATA_HOME=$S/xdg/golden; rm -rf $XDG_DATA_HOME; mkdir -p $XDG_DATA_HOME
cd $W
git status --short > $S/logs/golden_gitstatus.txt
t0=$SECONDS
nice -n 10 tools/golden.sh check > $S/logs/golden_check.log 2>&1 < /dev/null
echo "exit=$? $((SECONDS-t0))s $(date +%H:%M)" >> $S/logs/golden_check.log
touch $S/logs/golden.done
flock -u 9
