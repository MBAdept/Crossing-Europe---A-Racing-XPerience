#!/bin/bash
# pqueue.sh <jobsfile> : perf runs one after another; line: TAG|NAME|MODE|PRESET|ARGS (TAG head|base); .done in $S/perf
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
mkdir -p $S/perf
exec 9>$S/heavy.lock
while IFS='|' read -r TAG NAME MODE PRESET ARGS; do
  [ -z "$TAG" ] && continue
  case "$TAG" in \#*) continue ;; esac
  K=${TAG}_${NAME}_${MODE}_${PRESET}
  [ -e $S/perf/$K.done ] && continue
  flock 9
  ROOT=$W; [ "$TAG" = base ] && ROOT=$S/base
  $S/sh/perf.sh $ROOT $TAG $NAME $MODE $PRESET $ARGS > /dev/null 2>&1
  echo "$K $(tail -1 $S/perf/$K.log) $(date +%H:%M)" >> $S/perf/pqueue.log
  touch $S/perf/$K.done
  flock -u 9
  sleep 2
done < $1
echo "PQUEUE DONE $1 $(date +%H:%M)" >> $S/perf/pqueue.log
