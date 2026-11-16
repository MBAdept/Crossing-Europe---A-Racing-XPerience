#!/bin/bash
# Menu screens with sample data: v0.7.0 (ref070) vs this tree in Arcade, same command, Xvfb, fixed 60 fps.
# Usage: menu_shots.sh <WxH> <tree: ref|cur> [screens...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
RES=$1; TREE=$2; shift 2
SCREENS=${*:-"title race_select vehicle start_time stage_select route_choice stage_screen result race_result leaderboards ferry options"}
if [ "$TREE" = ref ]; then DIR=$S/ref070; EXTRA=""; else DIR=$WT; EXTRA="--graphics=arcade"; fi
OUT=$S/menus/$RES/$TREE
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/mesa_menus
for sc in $SCREENS; do
	X=$S/xdg_menus_$TREE
	rm -rf "$X"; mkdir -p "$X"
	t0=$SECONDS
	# shellcheck disable=SC2086
	XDG_DATA_HOME=$X nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 ${RES}x24" godot --path "$DIR" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$RES" --fixed-fps 60 -- --screen=$sc --screenshot="$OUT/$sc" --shot-times=1.0,3.0 \
		$EXTRA > "$OUT/$sc.log" 2>&1
	echo "$TREE $RES $sc exit=$? $((SECONDS - t0)) s $(md5sum "$OUT/${sc}_01.png" 2>/dev/null | cut -c1-8)"
done
