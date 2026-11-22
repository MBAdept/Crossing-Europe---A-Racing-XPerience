#!/bin/bash
# clipq.sh <jobsfile> : A/B clips one after another under the heavy lock; line: ID|SECONDS|ARGS ; out $S/clips/<ID>.mp4
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
mkdir -p $S/clips
exec 9>$S/heavy.lock
while IFS='|' read -r ID SECS ARGS; do
  [ -z "$ID" ] && continue
  case "$ID" in \#*) continue ;; esac
  [ -e $S/clips/$ID.done ] && continue
  flock 9
  t0=$SECONDS
  ( cd $W; CLIP_S=$SECS FPS=60 GFX_ARGS="--gfx-preset=high" tools/ab_clip.sh $S/clips/$ID.mp4 $ARGS > $S/clips/$ID.log 2>&1 < /dev/null ); c=$?
  echo "$ID exit=$c $((SECONDS-t0))s $(date +%H:%M)" >> $S/clips/clipq.log
  touch $S/clips/$ID.done
  flock -u 9
  sleep 2
done < $1
echo "CLIPQ DONE $(date +%H:%M)" >> $S/clips/clipq.log
