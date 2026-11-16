#!/usr/bin/env bash
# AS5a1 scratch: measurements of the city models (texel density, level swap, shimmer) - one heavy job at a time.
#   measure.sh texel|lods|spark|sheets <ids,> [tag]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
WHAT="$1"; IDS="$2"; TAG="${3:-m}"
mkdir -p "$S/meas"
while true; do
	AV=$(free -g | awk '/^Mem:/{print $7}')
	if [ "${AV:-0}" -ge 3 ]; then break; fi
	echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
done
GD="xvfb-run -a -s \"-screen 0 1280x720x24\" godot --path . --rendering-driver opengl3 --audio-driver Dummy"
case "$WHAT" in
texel)
	nice -n 19 godot --headless --path . -s res://tools/kritik/texel_probe.gd -- --models="$IDS" 2>&1 | grep TEXEL
	;;
lods)
	for H in 12 22; do
		nice -n 19 tools/models/prop_scene.sh "$S/meas/${TAG}_lods_h$H.png" --models="$IDS" --mode=lods --look=race \
			--hour=$H --preset=medium --sprite --x=18 2>&1 | grep -E "UMSCHALT|STUFEN|ERROR|SCRIPT"
	done
	;;
spark)
	nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		-s res://tools/kritik/my_scene.gd -- --mode=sparkcam --models="$IDS" --dists=40,60,100,150 --x=18 --sprite \
		--look=race --hour=12 --preset=medium --out="$S/meas/${TAG}_spark.png" 2>&1 | grep -E "SPARK|FLIMMER|ERROR|SCRIPT|my_scene"
	;;
esac
echo "=== $WHAT fertig $(date +%H:%M)"
