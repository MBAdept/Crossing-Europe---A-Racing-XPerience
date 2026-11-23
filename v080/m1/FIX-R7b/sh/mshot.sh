#!/usr/bin/env bash
# FIX-R7b: one Modern picture of the worktree (Arcade comes from QA-R7b raw, unchanged).
#   mshot.sh <out prefix> <preset> <screen> <race args…>   -> <out>_modern_00.png (+ _modern.log)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b
W=${TREE:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-6}
OUT=$1; PRESET=$2; SCREEN=$3; shift 3
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p $TMPDIR $MESA_SHADER_CACHE_DIR "$(dirname "$OUT")"
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
X=$S/xdg_run_$$
rm -rf $X; mkdir -p $X
if [ -n "${OVERRIDE:-}" ]; then mkdir -p "$X/godot/app_userdata/Crossing Europe – A Racing Xperience"; cp "$OVERRIDE" "$X/godot/app_userdata/Crossing Europe – A Racing Xperience/game_config.json"; fi
T0=$SECONDS
(cd $W && XDG_DATA_HOME=$X nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=${OUT}_modern" "$@" \
	--graphics=modern --gfx-sync "--gfx-preset=$PRESET" > "${OUT}_modern.log" 2>&1) || echo "FEHLER $OUT"
grep -qE "SCRIPT ERROR|SHADER ERROR|Modus Modern nicht" "${OUT}_modern.log" && echo "LOGFEHLER $OUT"
rm -rf $X
echo "$(basename "$OUT") $((SECONDS - T0)) s"
