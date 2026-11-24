#!/bin/bash
# mshot.sh <out_dir> <preset> <shot_times> <POS>... : Modern only (no Arcade run, no import) – quick looks while building
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
OUT=$1; PRESET=$2; ST=$3; shift 3
mkdir -p "$OUT"
for P in "$@"; do
	a=$($S/sh/pos.sh $P) || continue
	x=$S/xdg/m_$P; rm -rf $x; mkdir -p $x
	t0=$SECONDS
	scr=1280x720; [ "$PRESET" = deck ] && scr=1280x800
	# shellcheck disable=SC2086
	(cd ${WT:-$W} && XDG_DATA_HOME=$x nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 ${scr}x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution $scr --fixed-fps 60 res://scenes/race/race.tscn -- --screenshot=$OUT/${P}_$PRESET $a \
		--shot-times=$ST --graphics=modern --gfx-sync --gfx-preset=$PRESET > $OUT/${P}_$PRESET.log 2>&1)
	echo "$(date +%T) $P $PRESET exit=$? $((SECONDS - t0)) s $(grep -cE 'SHADER ERROR|SCRIPT ERROR|Shader compilation failed' $OUT/${P}_$PRESET.log) Fehler"
done
