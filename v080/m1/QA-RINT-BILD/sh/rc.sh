#!/bin/bash
# rc.sh <filter...> : tools/run_render_checks.sh modern <filter> one after another under the heavy lock; logs $S/rc/<filter>.log
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
mkdir -p $S/rc
exec 9>$S/heavy.lock
for F in "$@"; do
  [ -e $S/rc/$F.done ] && continue
  flock 9
  export XDG_DATA_HOME=$S/xdg/rc_$F; rm -rf $XDG_DATA_HOME; mkdir -p $XDG_DATA_HOME
  t0=$SECONDS
  ( cd $W; nice -n 10 tools/run_render_checks.sh modern $F > $S/rc/$F.log 2>&1 ); c=$?
  echo "exit=$c $((SECONDS-t0))s $(date +%H:%M)" >> $S/rc/$F.log
  touch $S/rc/$F.done
  flock -u 9
  sleep 2
done
