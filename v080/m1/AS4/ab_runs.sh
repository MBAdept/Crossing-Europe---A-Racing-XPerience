#!/usr/bin/env bash
# AS4 scratch: A/B pictures Arcade | Modern at the AS4 positions.
#   ab_runs.sh <pos>:<preset>:<hour> [...]     e.g. P1:high:19.5 P2:medium:12
#   P1 Kiel-Hamburg km 75.8 (Pylone, Fähren, Altstadt, Haus), P2 km 82.9 (Fachwerkportale),
#   P3 Bremen-Dortmund ab Dortmund km 0.3 (Fabrik, Blöcke)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
OUT=$S/ab
mkdir -p "$OUT" "$S/mesa_ab" "$S/tmp"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export TMPDIR=$S/tmp     # ab_shot.sh puts its absolute XDG_DATA_HOME folders below TMPDIR
cd "$WT"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
for spec in "$@"; do
	IFS=: read -r pos preset hour <<<"$spec"
	case "$pos" in
	P1) A="--stage=kiel_hamburg --from=kiel --start-km=75.8 --start-speed=50 --shot-times=1,6" ;;
	P2) A="--stage=kiel_hamburg --from=kiel --start-km=82.9 --start-speed=50 --shot-times=1,5" ;;
	P3) A="--stage=bremen_dortmund --from=dortmund --start-km=${P3_KM:-1.9} --start-speed=${P3_V:-100} --shot-times=${P3_T:-1,3}" ;;
	*) echo "unbekannte Position $pos"; continue ;;
	esac
	tag="${pos}_${preset}_$(echo "$hour" | tr -d .)"
	echo "=== $tag $(date +%H:%M)"
	# shellcheck disable=SC2086
	GFX_ARGS="--gfx-preset=$preset" nice -n 19 tools/ab_shot.sh "$OUT/$tag" $A $BASE --hour="$hour" 2>&1 | tail -4
done
echo "=== fertig $(date +%H:%M)"
