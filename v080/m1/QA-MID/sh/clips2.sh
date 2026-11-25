#!/bin/bash
# QA-MID: the A/B clips (resumable). media.sh's loop read clips_pos.txt on stdin, and ab_clip.sh (ffmpeg) swallowed the
# rest of it after the first clip – here the list comes on fd 3 and every clip gets </dev/null.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
export XDG_DATA_HOME=$S/xdg/clips2; mkdir -p $XDG_DATA_HOME $S/clips
while read -r -u 3 tag args; do
	[ -s $S/clips/$tag.mp4 ] && continue
	t0=$SECONDS
	# shellcheck disable=SC2086
	(cd $W && CLIP_S=20 FPS=30 GFX_ARGS="--gfx-preset=high" CLIP_TIMEOUT=5400 nice -n 10 tools/ab_clip.sh $S/clips/$tag.mp4 $args > $S/clips/$tag.log 2>&1 < /dev/null)
	echo "$(date +%T) clip $tag exit=$? $((SECONDS - t0)) s" >> $S/logs/media.log
done 3< $S/clips_pos.txt
echo "CLIPS DONE $(date +%T)" >> $S/logs/media.log
