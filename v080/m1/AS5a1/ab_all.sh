#!/usr/bin/env bash
# AS5a1 scratch: A/B Arcade|Modern at the three city arrivals of the batch, high + medium, noon / dusk / 22:00.
#   ab_all.sh <outdir> [pos names, default "kh hh kw"] [presets, default "high medium"] [hours, default "12 19.5 22"]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
OUT="$1"
NAMES="${2:-kh hh kw}"
PRESETS="${3:-high medium}"
HOURS="${4:-12 19.5 22}"
mkdir -p "$OUT"
declare -A POS
POS[kh]="--stage=kiel_hamburg --from=kiel --start-km=${KH_KM:-87.6}"
POS[hh]="--stage=hamburg_hannover --from=hamburg --start-km=${HH_KM:-141.7}"
POS[kw]="--stage=kassel_wuerzburg --from=kassel --start-km=${KW_KM:-201.7}"
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
