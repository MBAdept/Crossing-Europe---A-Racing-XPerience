#!/usr/bin/env bash
# AS5a1 scratch: delivery pictures of one style (contact sheets day/night, game camera with the sprite at three hours,
# close-ups of the street facades day/night). One heavy job after the other.
#   deliver_style.sh <tag> <ids,> <x> [parts: kontakt,kamera,nah]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
TAG="$1"; IDS="$2"; X="$3"; PARTS="${4:-kontakt,kamera,nah}"
mkdir -p "$D" "$S/shots"
waitmem() {
	while true; do
		AV=$(free -g | awk '/^Mem:/{print $7}')
		if [ "${AV:-0}" -ge 3 ]; then break; fi
		echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
	done
}
jpg() { convert "$1" -quality 88 "$2" && echo "  -> $(basename "$2")"; }
if [[ ",$PARTS," == *",kontakt,"* ]]; then
	waitmem
	nice -n 19 tools/models_contact_sheet.sh "$S/shots/k_${TAG}_tag.png" --only="$IDS" --tile=480x360 --cols=4 | tail -1
	jpg "$S/shots/k_${TAG}_tag.png" "$D/kontaktbogen_${TAG}_tag.jpg"
	waitmem
	nice -n 19 tools/models_contact_sheet.sh "$S/shots/k_${TAG}_nacht.png" --only="$IDS" --night --tile=480x360 --cols=4 | tail -1
	jpg "$S/shots/k_${TAG}_nacht.png" "$D/kontaktbogen_${TAG}_nacht.jpg"
fi
if [[ ",$PARTS," == *",kamera,"* ]]; then
	for H in 12 19.5 22; do
		waitmem
		nice -n 19 tools/models/prop_scene.sh "$S/shots/c_${TAG}_h${H}.png" --models="$IDS" --mode=dist --dist=8,30,100,250 \
			--x="$X" --look=race --hour="$H" --preset=high --sprite --tile=420x300 2>&1 | grep -E "ERROR|SCRIPT|kein" | head -3
		case "$H" in 12) N=mittag ;; 19.5) N=daemmerung ;; *) N=nacht ;; esac
		jpg "$S/shots/c_${TAG}_h${H}.png" "$D/spielkamera_${TAG}_${N}.jpg"
	done
fi
if [[ ",$PARTS," == *",nah,"* ]]; then
	ITEMS="${IDS//,/;}"
	for H in 12 22; do
		waitmem
		"$S/k4.sh" "$S/shots/n_${TAG}_h${H}.png" k4_scene --mode=close --items="$ITEMS" --views=oblique,road \
			--look=race --hour="$H" --preset=high
		case "$H" in 12) N=tag ;; *) N=nacht ;; esac
		jpg "$S/shots/n_${TAG}_h${H}.png" "$D/nahansicht_${TAG}_${N}.jpg"
	done
fi
echo "=== deliver $TAG fertig $(date +%H:%M)"
