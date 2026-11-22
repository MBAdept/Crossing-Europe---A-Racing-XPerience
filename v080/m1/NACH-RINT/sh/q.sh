#!/bin/bash
# q.sh <jobsfile> : heavy jobs one after another. line: KIND|ID|PRESET|SCREEN|TIMES|ARGS
#   KIND ab   -> tools/ab_shot.sh in W (head) -> $S/ab/<ID>
#   KIND abB  -> tools/ab_shot.sh in base worktree -> $S/ab/<ID>_base
#   KIND clip -> tools/ab_clip.sh CLIP_S=TIMES -> $S/clips/<ID>.mp4
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
exec 9>$S/heavy.lock
while IFS='|' read -r KIND ID PRESET SCREEN TIMES ARGS; do
  [ -z "$KIND" ] && continue
  case "$KIND" in \#*) continue ;; esac
  flock 9
  t0=$SECONDS
  case "$KIND" in
  ab|abB)
    WD=$HEAD_W; OUT=$S/ab/$ID
    [ "$KIND" = abB ] && { WD=$BASE_W; OUT=$S/ab/${ID}_base; }
    [ -e $OUT.done ] && { flock -u 9; continue; }
    ( cd $WD; SCREEN=$SCREEN GFX_ARGS="--gfx-preset=$PRESET" nice -n 10 tools/ab_shot.sh $OUT $ARGS --shot-times=$TIMES > $OUT.tool.log 2>&1 < /dev/null ); c=$?
    touch $OUT.done ;;
  clip)
    OUT=$S/clips/$ID
    [ -e $OUT.done ] && { flock -u 9; continue; }
    ( cd $HEAD_W; CLIP_S=$TIMES FPS=60 GFX_ARGS="--gfx-preset=$PRESET" SCREEN=$SCREEN nice -n 10 tools/ab_clip.sh $OUT.mp4 $ARGS > $OUT.log 2>&1 < /dev/null ); c=$?
    touch $OUT.done ;;
  cmd)
    OUT=$S/logs/$ID
    [ -e $OUT.done ] && { flock -u 9; continue; }
    ( bash $ARGS > $OUT.log 2>&1 < /dev/null ); c=$?
    touch $OUT.done ;;
  esac
  echo "$KIND $ID exit=$c $((SECONDS-t0))s $(date +%H:%M)" >> $S/q.log
  flock -u 9
  sleep 1
done < $1
echo "Q DONE $1 $(date +%H:%M)" >> $S/q.log
