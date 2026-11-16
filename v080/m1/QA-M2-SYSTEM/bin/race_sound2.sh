#!/bin/bash
# Sound of real races with the Modern profile (gd/qa_race_sound.gd, headless real time, Arcade picture – Rule 4: the
# picture does not matter for the sound), master volume 1.0. Kiel – Hamburg: concrete slabs (km 25), Köhlbrandbrücke
# with its joints (km 78 – 80.61), Hamburg's old town (cobbles alternating with asphalt, km 87 – finish), a heavy crash
# into the traffic. Sequential. Runs in the scratch copy $S/mut (unmutated at this point).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
M=${TREE:-$S/mut}
OUT=$S/sound
mkdir -p "$OUT"
cap() { # name args...
	local name=$1; shift
	local x=$S/xdg_rs_$name
	rm -rf "$x"; mkdir -p "$x"
	if [ -n "${SEED_CFG:-}" ]; then
		mkdir -p "$x/godot/app_userdata/Crossing Europe – A Racing Xperience"
		printf '%s\n' "$SEED_CFG" > "$x/godot/app_userdata/Crossing Europe – A Racing Xperience/game_config.json"
	fi
	local t0=$SECONDS
	# Movie Maker (fixed 60 fps, audio mixed in lockstep with the frames, 44.1 kHz through $M/override.cfg): the log
	# and the WAV share one clock and the CPU load of the shared machine cannot drop audio
	XDG_DATA_HOME=$x nice -n 10 timeout 2400 xvfb-run -a -s "-screen 0 640x360x24" godot --path "$M" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 320x180 --write-movie "$x/movie.avi" --fixed-fps 60 -s "$S/gd/qa_race_sound.gd" -- \
		--graphics=arcade --audio-sync --movie --out="$OUT/$name.wav" "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s; Fehler/leaked: $(grep -cE 'SCRIPT ERROR|^ERROR|leaked|still in use' "$OUT/$name.log")"
	grep -E "QA-RACE-SOUND|SCRIPT ERROR|^ERROR|leaked|still in use" "$OUT/$name.log" | head -4 | sed 's/^/    /'
	rm -rf "$x"
}
CASES=${CASES:-"concrete koehlbrand cobbles crash"}
for c in $CASES; do
	case $c in
	concrete)   cap rs_concrete --sound=modern --stage=kiel_hamburg --start-km=24.3 --seconds=30 --seed=7 ;;
	koehlbrand) cap rs_koehlbrand --sound=modern --stage=kiel_hamburg --start-km=77.6 --seconds=28 --seed=7 ;;
	cobbles)    cap rs_cobbles --sound=modern --stage=kiel_hamburg --start-km=86.6 --seconds=60 --seed=7 ;;
	crash)      cap rs_crash --sound=modern --stage=kiel_hamburg --start-km=30 --seconds=25 --seed=3 --crash --start-speed=220 --lane=2 --traffic-warmup ;;
	crash2)     cap rs_crash2 --sound=modern --stage=kiel_hamburg --start-km=40 --seconds=25 --seed=11 --crash --start-speed=240 --lane=1 --traffic-warmup ;;
	concrete_nolim) SEED_CFG='{"audio": {"modern": {"limiter": {"enabled": false}}}}' cap rs_concrete_nolim --sound=modern --stage=kiel_hamburg --start-km=24.3 --seconds=30 --seed=7 ;;
	crash_nolim) SEED_CFG='{"audio": {"modern": {"limiter": {"enabled": false}}}}' cap rs_crash_nolim --sound=modern --stage=kiel_hamburg --start-km=30 --seconds=25 --seed=3 --crash --start-speed=220 --lane=2 --traffic-warmup ;;
	crash_music) cap rs_crash_music --sound=modern --stage=kiel_hamburg --start-km=30 --seconds=28 --seed=3 --crash --start-speed=220 --lane=2 --traffic-warmup --music ;;
	fuel_music) cap rs_fuel_music --sound=modern --stage=kiel_hamburg --start-km=30 --seconds=40 --seed=7 --fuel=0.004 --music ;;
	arcade_kb)  cap rs_arcade_koehlbrand --sound=arcade --stage=kiel_hamburg --start-km=77.6 --seconds=28 --seed=7 ;;
	esac
done
python3 "$S/bin/race_sound_analyze.py" /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4/tools/audio/qc $(for c in $CASES; do case $c in arcade_kb) echo "$OUT/rs_arcade_koehlbrand.wav";; *) echo "$OUT/rs_$c.wav";; esac; done) 2>&1 | tee "$OUT/race_sound_analysis.txt"
echo ALLDONE
