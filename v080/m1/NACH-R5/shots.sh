#!/usr/bin/env bash
# NACH-R5 A/B pictures: shots.sh <set> [name…]   (set = new|base; env PRESET, SCREEN)
set -uo pipefail
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8
SET=$1; shift
WANT=" $* "
PRESET=${PRESET:-high}
export SCREEN=${SCREEN:-1280x720}
export MESA_SHADER_CACHE_DIR=$N/mesa
export TMPDIR=$N/tmp
export GFX_ARGS="--gfx-preset=$PRESET"
export AB_TIMEOUT=1500
mkdir -p "$N/shots/$SET" "$MESA_SHADER_CACHE_DIR" "$TMPDIR"
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
shot() {
  local name=$1; shift
  want "$name" || return 0
  local t0=$SECONDS
  cd "$WT" || exit 1
  # shellcheck disable=SC2086
  nice -n 10 tools/ab_shot.sh "$N/shots/$SET/$name" "$@" $COMMON > "$N/shots/$SET/$name.ab.log" 2>&1
  local rc=$?
  echo "== $SET $name exit $rc $((SECONDS - t0)) s errors: $(cat "$N/shots/$SET/${name}"_*.log 2>/dev/null | grep -cE 'SCRIPT ERROR|SHADER ERROR|Parse Error')"
}
U1A="--stage=bern_mailand --from=bern --start-km=183.6 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1X="--stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5"
U1N="--stage=bern_mailand --from=bern --start-km=183.6 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1NN="--stage=bern_mailand --from=bern --start-km=184.0 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3,4"
SOMN="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=22 --seed=4 --start-speed=100 --shot-times=2,4,6"
STE="--stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
DEV="--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 --start-speed=120 --shot-times=2,4,6"
shot u1_nacht $U1N
shot dev $DEV
shot u1_anfahrt $U1A
shot u1_ausfahrt $U1X
shot u1_nacht_nah $U1NN
shot somport_nacht $SOMN
shot stein $STE
echo "SHOTS_DONE $SET"
