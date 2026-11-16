#!/usr/bin/env bash
# AS5a2 scratch: A/B Arcade|Modern at city arrivals of batch 2, presets x hours.
#   ab_all.sh <outdir> [pos names, default "pa am tl"] [presets, default "high medium"] [hours, default "12 19.5 22"]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
OUT="$1"
NAMES="${2:-pa am tl}"
PRESETS="${3:-high medium}"
HOURS="${4:-12 19.5 22}"
mkdir -p "$OUT"
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=${PA_KM:-387.5}"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=${AM_KM:-357.3}"
POS[tl]="--stage=pau_toulouse --from=pau --start-km=${TL_KM:-192.5}"
POS[br]="--stage=koeln_bruessel --from=koeln --start-km=${BR_KM:-195.5}"
POS[be]="--stage=lyon_bern --from=lyon --start-km=${BE_KM:-302.4}"
POS[mo]="--stage=toulouse_montpellier --from=toulouse --start-km=${MO_KM:-226.0}"
for n in $NAMES; do
	for p in $PRESETS; do
		for h in $HOURS; do
			while true; do
				AV=$(free -g | awk '/^Mem:/{print $7}')
				if [ "${AV:-0}" -ge 3 ]; then break; fi
				echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
			done
			pre="$OUT/${n}_${p}_h${h}"
			GFX_ARGS="--gfx-preset=$p" nice -n 19 tools/ab_shot.sh "$pre" ${POS[$n]} --hour=$h --weather=normal \
				--vehicle=limousine --seed=11 --autopilot --traffic-warmup --no-countdown --start-speed=50 \
				--shot-times=${SHOTS:-2,4} > "$pre.run.log" 2>&1
			code=$?
			errs=$(cat "${pre}_modern.log" "${pre}_arcade.log" 2>/dev/null | grep -c -E "SCRIPT ERROR|Parse Error|ERROR:")
			echo "AB $n $p h$h exit $code Fehlerzeilen $errs"
		done
	done
done
echo "=== ab_all fertig $(date +%H:%M)"
