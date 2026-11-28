#!/bin/bash
# AU-E: run one check scenario with config overrides in separate user folders.
#   variants.sh <scenario> <name>=<json override>|<extra args> ...
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AUE/env.sh
cd $WT
SC=$1; shift
for v in "$@"; do
	name=${v%%=*}; rest=${v#*=}
	X=$S/xdg_exp/$name; rm -rf $X; U="$X/godot/app_userdata/Crossing Europe – A Racing Xperience"; mkdir -p "$U"
	extra=""
	case "$rest" in
		ARGS:*) extra=${rest#ARGS:} ;;
		*) [ -n "$rest" ] && echo "$rest" > "$U/game_config.json" ;;
	esac
	XDG_DATA_HOME=$X timeout 1200 nice -n 10 xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 320x180 --fixed-fps 60 --write-movie $S/rec/v_$name.avi -s res://tests/race/check_audio_modern.gd -- --graphics=arcade --sound=modern --audio-sync --only=$SC ${CARS:+--cars=$CARS} --out=$S/var/$name $extra > $S/logs/var_$name.log 2>&1
	echo "== $name: $(grep -E '^AUDIO-CHECK ' $S/logs/var_$name.log | cut -c1-260)"
	grep -E "SCRIPT ERROR|Config: Overrides" $S/logs/var_$name.log | head -2
done
