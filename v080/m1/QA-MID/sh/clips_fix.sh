#!/bin/bash
# QA-MID: the clips that the fixes change (snow: Q-02 spruces; tunnel: Q-04 exit), rendered again with the fix head F.
# Starts after the ZS2 goldens (same slot). Resumable: an existing mp4 is skipped.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
F=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
until grep -q "ZS2 GOLDEN DONE" $S/logs/zs2.log; do sleep 30; done
export XDG_DATA_HOME=$S/xdg/clipsfix; mkdir -p $XDG_DATA_HOME
while read -r -u 3 tag args; do
	[ -s $S/clips/$tag.mp4 ] && continue
	t0=$SECONDS
	# shellcheck disable=SC2086
	(cd $F && CLIP_S=20 FPS=30 GFX_ARGS="--gfx-preset=high" CLIP_TIMEOUT=5400 nice -n 10 tools/ab_clip.sh $S/clips/$tag.mp4 $args > $S/clips/$tag.log 2>&1 < /dev/null); rc=$?
	echo "$(date +%T) clip $tag ($(cd $F && git rev-parse --short HEAD)) exit=$rc $((SECONDS - t0)) s" >> $S/logs/media.log
done 3< $S/clips_fix_pos.txt
echo "CLIPSFIX DONE $(date +%T)" >> $S/logs/media.log
