#!/usr/bin/env bash
# Underruns of the engine generator under Xvfb (software rendering, Dummy audio): N runs per profile of the last
# 3.5 km of the test stage. Usage: skiploop.sh <runs>
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
N="${1:-4}"
OUT="$W/logs/skiploop.txt"
: >"$OUT"
for i in $(seq 1 "$N"); do
	for p in arcade modern; do
		"$W/xstage.sh" "skip_${p}_$i" 0 res://tests/race/run_stage.gd --stage=dev_testetappe "--sound=$p" --timescale=1 --start-km=126.5 --seed=7 --weather=rain --perf >/dev/null 2>&1
		echo "$p $i $(grep -E '^AUDIO_PERF' "$W/logs/x_skip_${p}_$i.log" | sed -E 's/.*"engine":\{([^}]*)\}.*/\1/') $(grep -cE 'ERROR|SCRIPT' "$W/logs/x_skip_${p}_$i.log") Fehlerzeilen" >>"$OUT"
	done
done
cat "$OUT"
