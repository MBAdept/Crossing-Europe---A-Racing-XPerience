#!/usr/bin/env bash
# AS5a1 scratch: review pictures of models in the game camera (race look), day / dusk / night, with the sprite.
#   views.sh <tag> <models> <x> [dist list] [extra prop_scene args]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
TAG="$1"; MODELS="$2"; X="$3"; DIST="${4:-10,30,100,250}"
shift 4 || shift $#
mkdir -p "$S/shots"
while true; do
	AV=$(free -g | awk '/^Mem:/{print $7}')
	if [ "${AV:-0}" -ge 3 ]; then break; fi
	echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
done
for H in 12 19.5 22; do
	nice -n 19 tools/models/prop_scene.sh "$S/shots/${TAG}_dist_h${H}.png" --models="$MODELS" --mode=dist --dist="$DIST" \
		--x="$X" --look=race --hour="$H" --preset=high --sprite --tile=420x300 "$@" 2>&1 | grep -E "ERROR|SCRIPT|Parse|kein" | head -5
done
echo "=== views fertig $(date +%H:%M)"
