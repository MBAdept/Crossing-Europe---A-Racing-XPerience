#!/bin/bash
# QA-MID media (resumable): A/B pictures, A/B clips, then the built-in benchmark per preset – one heavy job
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
O=$S/ab; mkdir -p $O $S/clips
export XDG_DATA_HOME=$S/xdg/media; mkdir -p $XDG_DATA_HOME
while read -r tag args; do
	[ -f $O/${tag}_ab_00.jpg ] && continue
	t0=$SECONDS
	# shellcheck disable=SC2086
	(cd $W && GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh $O/$tag --shot-times=3 $args > $O/$tag.run.log 2>&1)
	echo "$(date +%T) ab $tag exit=$? $((SECONDS - t0)) s" >> $S/logs/media.log
done < $S/media_pos.txt
while read -r tag args; do
	[ -s $S/clips/$tag.mp4 ] && continue
	t0=$SECONDS
	# shellcheck disable=SC2086
	(cd $W && CLIP_S=20 FPS=30 GFX_ARGS="--gfx-preset=high" CLIP_TIMEOUT=5400 nice -n 10 tools/ab_clip.sh $S/clips/$tag.mp4 $args > $S/clips/$tag.log 2>&1)
	echo "$(date +%T) clip $tag exit=$? $((SECONDS - t0)) s" >> $S/logs/media.log
done < $S/clips_pos.txt
for pre in deck low medium high; do
	[ -s $S/bench/bench_$pre.json ] && continue
	BS=20 $S/sh/bench.sh bench_$pre $pre - all >> $S/logs/media.log 2>&1
done
echo "MEDIA DONE $(date +%T)" >> $S/logs/media.log
