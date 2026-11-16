#!/usr/bin/env bash
# AS4 scratch: game-camera views (prop_scene) of the AS4 models at the switch distances, day and night, plus the
# level comparison (mode lods, STUFEN lines) - pictures and logs in views/.
#   views.sh <prefix> [group ...]      groups: land stadt bruecke schiffe (default: all)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/views"
cd "$WT"
PREFIX="$1"; shift
GROUPS_ALL="land stadt bruecke schiffe"
[ $# -gt 0 ] && GROUPS_ALL="$*"
DIST="25,59,61,150,199,201,400"
for g in $GROUPS_ALL; do
	case "$g" in
	land) M="props/house_med,props/church,props/factory,props/windmill"; X=22 ;;
	stadt) M="props/building_shop,props/building_oldtown,props/building_block_a,props/building_block_b,props/building_tall"; X=26 ;;
	bruecke) M="props/bridge_lamp,props/bridge_pylon"; X=7.5 ;;
	schiffe) M="props/houseboat,props/ferry_ship"; X=45 ;;
	*) echo "unbekannte Gruppe $g"; continue ;;
	esac
	t0=$SECONDS
	for nm in tag nacht; do
		extra=""
		[ "$nm" = nacht ] && extra="--night"
		# shellcheck disable=SC2086
		nice -n 19 tools/models/prop_scene.sh "$S/views/${PREFIX}_${g}_dist_${nm}.png" --models="$M" --mode=dist \
			--dist="$DIST" --x="$X" --zoom=3 --tile=360x300 $extra > "$S/views/${PREFIX}_${g}_dist_${nm}.log" 2>&1
		grep -E "ERROR|SCRIPT|kein" "$S/views/${PREFIX}_${g}_dist_${nm}.log" | head -3
	done
	nice -n 19 tools/models/prop_scene.sh "$S/views/${PREFIX}_${g}_stufen.png" --models="$M" --mode=lods --x="$X" \
		--zoom=3 --tile=360x300 > "$S/views/${PREFIX}_${g}_stufen.log" 2>&1
	grep -E "ERROR|SCRIPT|kein" "$S/views/${PREFIX}_${g}_stufen.log" | head -3
	echo "$g: $((SECONDS - t0)) s"
done
echo fertig
