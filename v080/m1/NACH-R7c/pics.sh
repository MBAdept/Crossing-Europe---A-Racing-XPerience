#!/bin/bash
# NACH-R7c: A/B pictures of the head 3b3107b (Arcade | Modern) with tools/ab_shot.sh, the same simulation states as
# QA-R7c's raw pictures (deliver/QA-R7c/raw: base 9b02f05 and R7c bd1803b). Restart-safe: skips a scene whose
# pictures exist.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12
OUTD=$S/shots
mkdir -p "$OUTD" "$S/mesa" "$S/logs"
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
memwait() {
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
}
COMMON="--hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
one() {   # one <name> <preset> <screen> <args...>
	local n=$1 q=$2 scr=$3
	shift 3
	if ls "$OUTD/${n}_modern_"[0-9][0-9].png > /dev/null 2>&1; then
		echo "$(date -u +%H:%M:%S) $n exists" >> "$S/logs/pics.out"
		return 0
	fi
	memwait
	local t0=$SECONDS
	(cd "$WT" && SCREEN=$scr GFX_ARGS="--gfx-preset=$q" nice -n 10 tools/ab_shot.sh "$OUTD/$n" "$@" > "$OUTD/${n}_ab.out" 2>&1)
	echo "$(date -u +%H:%M:%S) $n exit=$? $((SECONDS - t0)) s" >> "$S/logs/pics.out"
}
# QR7c-01: Hamburg Speicher at Deck
# shellcheck disable=SC2086
one hh_deck_h12 deck 1280x800 --stage=kiel_hamburg --from=kiel --start-km=88.2 $COMMON --no-countdown --start-speed=50 --shot-times=2,4
# QR7c-06: countdown Nürnberg – Fulda at Deck (oak in the band)
# shellcheck disable=SC2086
one start_nu_deck_h12 deck 1280x800 --stage=nuernberg_fulda --from=nuernberg --start-km=0 $COMMON --shot-times=1.5
# side effects: Nürnberg at Deck (Barockhaus lod0 back to 60 m) and Hoch (albedo bias)
# shellcheck disable=SC2086
one nu_deck_h12 deck 1280x800 --stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.0 $COMMON --no-countdown --start-speed=50 --shot-times=2,4
echo "PICS DONE $(date -u +%H:%M:%S)" >> "$S/logs/pics.out"
