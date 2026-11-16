#!/usr/bin/env bash
# R3 helper (scratch, not in the repo): only the Modern run of tools/ab_shot.sh, for quick look iterations.
#   mshot.sh <out_prefix> [S1..S5] [args…]   (GFX_ARGS, SCREEN as in ab_shot.sh)
set -uo pipefail
OUT=$1
shift
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-1
SCRATCH=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3
cd "$WT"
SCREEN=${SCREEN:-1280x720}
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120"
ARGS=()
case "${1:-}" in
S1) ARGS=($SLICE --start-km=2) ;;
S2) ARGS=($SLICE --start-km=13.6) ;;
S3) ARGS=($SLICE --start-km=60) ;;
S4) ARGS=($SLICE --start-km=80 --start-speed=50) ;;
S5) ARGS=($SLICE --start-km=94) ;;
esac
[ ${#ARGS[@]} -gt 0 ] && shift
ARGS+=("$@")
HAS=0
for a in "${ARGS[@]}"; do case "$a" in --shot-times=*) HAS=1 ;; esac; done
[ $HAS -eq 0 ] && ARGS+=(--shot-times=2)
export MESA_SHADER_CACHE_DIR=$SCRATCH/mesa
X=$SCRATCH/xdg_mshot
rm -rf "$X"
mkdir -p "$X" "$(dirname "$OUT")"
rm -f "${OUT}"_modern_[0-9][0-9].png
t0=$SECONDS
XDG_DATA_HOME="$X" nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=${OUT}_modern" \
	"${ARGS[@]}" --graphics=modern --gfx-sync ${GFX_ARGS:-} >"${OUT}_modern.log" 2>&1
echo "exit $? in $((SECONDS - t0)) s"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|^ERROR|nicht möglich" "${OUT}_modern.log" | head -12
ls "${OUT}"_modern_[0-9][0-9].png 2>/dev/null
