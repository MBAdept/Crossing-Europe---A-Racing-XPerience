#!/bin/bash
# shot.sh <head|base> <out_dir> <preset> <shot_times> <POS>... : tools/ab_shot.sh per position (one at a time)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
TREE=$1; OUT=$2; PRESET=$3; ST=$4; shift 4
case "$TREE" in base) WT=$S/base ;; *) WT=$W ;; esac
mkdir -p "$OUT"
export XDG_DATA_HOME=$S/xdg/ab
mkdir -p $XDG_DATA_HOME
for P in "$@"; do
	a=$($S/sh/pos.sh $P) || continue
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
	t0=$SECONDS
	scr=""
	[ "$PRESET" = deck ] && scr="SCREEN=1280x800"
	# shellcheck disable=SC2086
	(cd "$WT" && env $scr GFX_ARGS="--gfx-preset=$PRESET" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh "$OUT/${P}_$PRESET" $a --shot-times=$ST > "$OUT/${P}_$PRESET.run.log" 2>&1)
	echo "$(date +%H:%M:%S) $TREE $P $PRESET exit=$? $((SECONDS - t0)) s"
done
