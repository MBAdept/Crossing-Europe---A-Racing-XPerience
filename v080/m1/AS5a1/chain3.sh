#!/usr/bin/env bash
# AS5a1 scratch (successor 3): tint sheet, measurements, A/B at three arrivals, clip - one heavy job after the other.
#   chain3.sh [steps: tint,texel,lods,spark,ab,clip]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
STEPS=",${1:-tint,texel,lods,spark,ab,clip},"
cd "$S"
OLD=props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock
HAN=props/city_hanse_gabled,props/city_hanse_kontor,props/city_hanse_speicher,props/city_hanse_crane
GER=props/city_german_house,props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_office
waitmem() {
	while true; do
		AV=$(free -g | awk '/^Mem:/{print $7}')
		if [ "${AV:-0}" -ge 3 ]; then break; fi
		sleep 60
	done
}
if [[ $STEPS == *",tint,"* ]]; then
	./k4.sh "$S/shots/tint.png" tint_scene --mode=tint --dist=35 --look=race --hour=12 --preset=high \
	  --items="props/city_german_house@15#e8b8a4;props/city_german_mietshaus@12#e0b09c;props/city_german_mietshaus@12#f6eee2;props/city_german_gruenderzeit@9#f6eedc;props/city_german_gruenderzeit@9#ece4d0" > "$S/tint.log" 2>&1
	convert "$S/shots/tint.png" -quality 88 "$D/toenungen.jpg"
	echo "STEP tint fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",outline,"* ]]; then
	./k4.sh "$S/shots/umriss.png" k4_scene --mode=outline2 --items="${GER//,/;};${OLD//,/;};${HAN//,/;}" --look=race \
		--hour=12 --preset=high > "$S/meas_outline.log" 2>&1
	convert "$S/shots/umriss.png" -quality 88 "$D/umrisse_sprite_gegen_modell.jpg"
	echo "STEP outline fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",texel,"* ]]; then
	./measure.sh texel "$GER,$OLD,$HAN" > "$S/meas_texel.log" 2>&1
	echo "STEP texel fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",lods,"* ]]; then
	./measure.sh lods "$GER" ger > "$S/meas_lods_ger.log" 2>&1
	./measure.sh lods "$OLD" old > "$S/meas_lods_old.log" 2>&1
	./measure.sh lods "$HAN" han > "$S/meas_lods_han.log" 2>&1
	echo "STEP lods fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",spark,"* ]]; then
	./measure.sh spark "props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_hanse_gabled,props/city_hanse_kontor" spk > "$S/meas_spark.log" 2>&1
	echo "STEP spark fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",ab,"* ]]; then
	./ab_all.sh "$S/ab" "${AB_POS:-kh hh kw}" "${AB_PRESETS:-high medium}" "${AB_HOURS:-12 19.5 22}" > "$S/ab_all.log" 2>&1
	echo "STEP ab fertig $(date +%H:%M)"
fi
if [[ $STEPS == *",clip,"* ]]; then
	waitmem
	cd "$WT"
	CLIP_S=10 FPS=60 SIDE=960x540 GFX_ARGS="--gfx-preset=high" MESA_SHADER_CACHE_DIR=$S/mesa nice -n 19 tools/ab_clip.sh \
		"$D/fahrt_wuerzburg_altstadt_50kmh.mp4" --stage=kassel_wuerzburg --from=kassel --start-km=${CLIP_KM:-202.0} --hour=12 \
		--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown \
		--start-speed=50 > "$S/clip.log" 2>&1
	echo "STEP clip fertig $(date +%H:%M) exit $?"
fi
echo "=== chain3 fertig $(date +%H:%M)"
