#!/usr/bin/env bash
# The Modern half of tools/ab_shot.sh for the R5 worktree (same arguments and order) – quick probes.
#   PRESET=high SCREEN=1280x720 mo.sh <out_prefix> [race scene arguments…]   (EXTRA = more Modern arguments)
set -uo pipefail
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2}
cd "$WT" || exit 1
OUT=$1
shift
SCREEN=${SCREEN:-1280x720}
PRESET=${PRESET:-high}
export MESA_SHADER_CACHE_DIR=$R5/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR" "$R5/tmp"
X=$(mktemp -d "$R5/tmp/xdg_mo.XXXXXX")
mkdir -p "$(dirname "$OUT")"
rm -f "${OUT}"_modern_[0-9][0-9].png
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME="$X" nice -n $NICE timeout ${MO_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=${OUT}_modern" "$@" --gfx-preset=$PRESET ${EXTRA:-} "--graphics=modern" --gfx-sync >"${OUT}_modern.log" 2>&1
code=$?
rm -rf "$X"
n=$(find "$(dirname "$OUT")" -maxdepth 1 -name "$(basename "$OUT")_modern_[0-9][0-9].png" | wc -l)
echo "    modern $n Bild(er), $((SECONDS - t0)) s, exit $code: $OUT"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Modus Modern nicht möglich|ERROR" "${OUT}_modern.log" | head -8
