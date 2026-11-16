#!/usr/bin/env bash
# QA lens 1: Arcade identity beyond the 20 golden frames – menus, GameFlow path, Steam Deck size.
W=$(cd "$(dirname "$0")" && pwd)
OUT=$W/extra_identity; mkdir -p $OUT/ref $OUT/new
export MESA_SHADER_CACHE_DIR=$W/xdg_rc/mesa_shader_cache
one() { # tree, outdir, id, screen, scene ("" = main), times, extra args...
	local tree=$1 out=$2 id=$3 screen=$4 scene=$5 times=$6; shift 6
	local X=$W/xdg_extra; rm -rf $X; mkdir -p $X
	XDG_DATA_HOME=$X nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 ${screen}x24" godot --path $tree --rendering-driver opengl3 --audio-driver Dummy --resolution $screen --fixed-fps 60 $scene -- --screenshot=$out/$id --shot-times=$times "$@" > $out/$id.log 2>&1
}
pair() { # id, screen, scene, times, args...
	local id=$1 screen=$2 scene=$3 times=$4; shift 4
	one $W/ref070 $OUT/ref $id $screen "$scene" $times "$@"
	one $W/tree $OUT/new $id $screen "$scene" $times "$@" --graphics=arcade
	local n=0 same=0 worst=0
	for f in $OUT/ref/${id}_*.png; do
		n=$((n+1)); b=$OUT/new/$(basename $f)
		if [ -s "$b" ] && [ "$(md5sum < $f)" = "$(md5sum < $b)" ]; then same=$((same+1)); else d=$(compare -metric AE $f $b null: 2>&1 | awk '{print $1}'); worst="$worst,$d"; fi
	done
	printf '%-26s %-9s %d von %d identisch%s\n' "$id" "$screen" $same $n "$([ $same -ne $n ] && echo "  PIXEL VERSCHIEDEN: $worst")"
}
RACE=res://scenes/race/race.tscn
pair title          1280x720 "" 1.5,4 --no-attract
pair title_deck     1280x800 "" 2 --no-attract
pair options        1280x720 "" 1.5 --screen=options --no-attract
pair vehicle        1280x720 "" 2.5 --screen=vehicle --no-attract
pair vehicle_deck   1280x800 "" 2.5 --screen=vehicle --no-attract
pair race_select    1280x720 "" 1.5 --screen=race_select --no-attract
pair stage_screen   1280x720 "" 1.5 --screen=stage_screen --no-attract
pair result         1280x720 "" 1.5 --screen=result --no-attract
pair race_result    1280x720 "" 1.5 --screen=race_result --no-attract
pair leaderboards   1280x720 "" 1.5 --screen=leaderboards --no-attract
pair flow_stage     1280x720 "" 2.2,7 --stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup
pair deck_race_n1   1280x800 $RACE 4 --stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 --autopilot --traffic-warmup
pair pause_menu     1280x720 $RACE 3 --stage=dev_testetappe --start-km=48 --hour=21 --pause-demo
pair attract_flow   1280x720 "" 6,12 --attract-after=1 --attract-scene=regen
pair wide_race      1680x720 $RACE 5 --stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 --autopilot --traffic-warmup
