#!/usr/bin/env bash
# R6: A/B clips (Movie Maker, 60 fps fixed): refuel at the tutorial stop, radar flash + police stop, countdown with
# LOS, finish banner. Usage: clips.sh [name …]  (default: all)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
export MESA_SHADER_CACHE_DIR=$S/mesa
# "Mittel" (the game's default): Movie Maker at 60 fps with llvmpipe took 1132 s for the 8 s countdown on "Hoch" at load 26
export GFX_ARGS=${GFX_ARGS:---gfx-preset=medium}
export CLIP_TIMEOUT=14400
export TMPDIR=$S/tmp
mkdir -p "$TMPDIR" "$D"
cd "$WT" || exit 1
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup"
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
want() { [ $# -eq 0 ] && return 0; for w in $WANT; do [ "$w" = "$1" ] && return 0; done; return 1; }
WANT="$*"
clip() {
	local name=$1 secs=$2; shift 2
	if [ -n "$WANT" ]; then case " $WANT " in *" $name "*) ;; *) return ;; esac; fi
	echo "== $name ${secs}s $(date +%H:%M)"
	CLIP_S=$secs nice -n "$NICE" tools/ab_clip.sh "$D/clip_$name.mp4" "$@" > "$S/shots/clip_$name.log" 2>&1
	echo "   exit $? $(tail -2 "$S/shots/clip_$name.log" | tr '\n' ' ')"
}
clip countdown_los 8 $KH --autopilot-refuel=never --hour=12 --start-km=0
clip tanken_km15 30 $KH --autopilot-refuel=always --fuel=0.7 --no-countdown --hour=12 --start-km=13.62 --start-speed=90
clip blitz_polizei 32 $DEV --hour=12 --start-km=11.85 --start-speed=150 --autopilot-speeding --autopilot-target=150
clip ziel 8 $KH --autopilot-refuel=never --no-countdown --hour=12 --start-km=94.2 --start-speed=100
echo DONE $(date +%H:%M)
