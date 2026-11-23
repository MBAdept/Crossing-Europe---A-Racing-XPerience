#!/bin/bash
# QA-R7c queue 4 (after q3): independent far-light measurement (k6_scene lodcol with the shipped far_sun values) and a
# standing start in an old town (the dither band on a still picture)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
until grep -q "Q3 DONE" "$S/logs/q3.out" 2>/dev/null; do sleep 30; done
echo "Q4 start $(date -u +%H:%M:%S)" >> "$S/logs/q4.out"
for p in high medium; do
	"$S/sh/k6.sh" far_haussmann_$p --mode=lodcol "--models=props/city_paris_haussmann" --dists=60,100,140,200,250 --x=20 --look=race \
		--hour=12 --preset=$p --tile=200x160 --far_sun=0.72 --reps=lod1 >> "$S/logs/q4.out" 2>&1
	"$S/sh/k6.sh" far_haussmann_${p}_off --mode=lodcol "--models=props/city_paris_haussmann" --dists=60,100,140,200,250 --x=20 --look=race \
		--hour=12 --preset=$p --tile=200x160 --reps=lod1 >> "$S/logs/q4.out" 2>&1
	"$S/sh/k6.sh" far_gruender_$p --mode=lodcol "--models=props/city_german_gruenderzeit,props/city_hanse_kontor" --dists=60,100,140,200,250 \
		--x=20 --look=race --hour=12 --preset=$p --tile=200x160 --far_sun=0.78 --reps=lod1 >> "$S/logs/q4.out" 2>&1
	"$S/sh/k6.sh" far_gruender_${p}_off --mode=lodcol "--models=props/city_german_gruenderzeit,props/city_hanse_kontor" --dists=60,100,140,200,250 \
		--x=20 --look=race --hour=12 --preset=$p --tile=200x160 --reps=lod1 >> "$S/logs/q4.out" 2>&1
done
echo "Q4 DONE $(date -u +%H:%M:%S)" >> "$S/logs/q4.out"
# --- standing start in Nürnberg's old town during the countdown (the dither band on a still picture), deck + high
for q in deck high; do
	scr=1280x720
	[ "$q" = "deck" ] && scr=1280x800
	SCREEN=$scr "$S/sh/tri.sh" "$D/raw/start_nu_${q}_h12" "$q" --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12 \
		--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5
done
echo "Q4 START DONE $(date -u +%H:%M:%S)" >> "$S/logs/q4.out"
# --- the original shadow-pass bug of R7c (band middle decides) against check_lod_band
python3 "$S/sh/mutate.py" R2b_shadow_band_middle >> "$S/logs/q4.out" 2>&1
echo "Q4 ALL DONE $(date -u +%H:%M:%S)" >> "$S/logs/q4.out"
