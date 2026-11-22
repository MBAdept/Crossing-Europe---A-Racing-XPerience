#!/bin/bash
# queue.sh <jobsfile> : runs A/B jobs one after another; line: ID|PRESET|SCREEN|BASE|TIMES|ARGS
# outputs into $S/ab/<ID>_*; skips a job whose <ID>.done exists (restart safe); every job holds $S/heavy.lock
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
JOBS=$1
mkdir -p $S/ab
while pgrep -f "tools/ab_shot.sh" > /dev/null; do sleep 5; done
exec 9>$S/heavy.lock
while IFS='|' read -r ID PRESET SCREEN BASE TIMES ARGS; do
  [ -z "$ID" ] && continue
  case "$ID" in \#*) continue ;; esac
  [ -e $S/ab/$ID.done ] && continue
  flock 9
  t0=$SECONDS
  GA=""; [ "$PRESET" != "auto" ] && GA="--gfx-preset=$PRESET"
  ( cd $W; SCREEN=$SCREEN GFX_ARGS="$GA" tools/ab_shot.sh $S/ab/$ID $ARGS --shot-times=$TIMES > $S/ab/$ID.tool.log 2>&1 ); c=$?
  if [ "$BASE" = "1" ]; then
    SCREEN=$SCREEN GFX_ARGS="$GA" $S/sh/mshot.sh $S/base $S/ab/${ID}_base $ARGS --shot-times=$TIMES > /dev/null 2>&1
  fi
  echo "$ID exit=$c $((SECONDS-t0))s $(date +%H:%M)" >> $S/ab/queue.log
  touch $S/ab/$ID.done
  flock -u 9
  sleep 2
done < $JOBS
echo "QUEUE DONE $JOBS $(date +%H:%M)" >> $S/ab/queue.log
