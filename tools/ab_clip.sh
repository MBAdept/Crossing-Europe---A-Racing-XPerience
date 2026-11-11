#!/usr/bin/env bash
# A/B clip of the two graphics modes (v0.8.0, docs/qa-v080.md): the same drive recorded once with the Arcade renderer
# and once with the Modern renderer – Godot's Movie Maker at a fixed frame rate, identical arguments and seed – and
# put side by side with the full HUD into one H.264 video (Arcade left, Modern right).
#
#   tools/ab_clip.sh <out.mp4> [race scene arguments…]
#   tools/ab_clip.sh out/start_tag.mp4 --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine \
#       --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup
#   GFX_ARGS="--gfx-preset=high" tools/ab_clip.sh out/nacht.mp4 --stage=dev_testetappe --start-km=48 --hour=21 …
#
# How the two recordings are aligned: both runs end after the same live game time (a Screenshotter shot at
# CLIP_S + 0.5 s quits the game; its clock stands while Modern prepares the stage, tools/ab_shot.sh). Modern first
# shows its loading picture (an opaque dark cover) – those frames are found by their colour and cut; the clip
# starts with the first frame of the running stage in both modes. The simulation is the same in both runs (Rule 3).
#
# Environment:
#   CLIP_S     seconds of the clip (default 30)          FPS     frame rate of the runs and of the clip (default 60)
#   GFX_ARGS   extra arguments of the Modern run (--gfx-preset=high …)
#   SIDE       size of each half in the clip (default 1280x720 = full size; e.g. 960x540)
#   CRF        H.264 quality to start with (default 21); MAX_MB (default 25): the clip is encoded again with a higher
#              CRF, at last with smaller halves, until it is not larger than that
#   KEEP_AVI=1 keeps the two Movie Maker files next to the clip (<out>_arcade.avi, <out>_modern.avi)
#   GODOT, CLIP_TIMEOUT (seconds per run, default 3600), MESA_SHADER_CACHE_DIR
# Every run has its own empty, absolute XDG_DATA_HOME. Both runs use --sound=arcade (the clip has no sound) and
# --gfx-sync (synchronous chunk builds); Modern without --shot-fast (Movie Maker renders every frame anyway).
# Needs ffmpeg with libx264, python3 with numpy and PIL. Heavy job: one run at a time, nice -n 10.
set -uo pipefail
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
	exit 2
fi
OUT=$1
shift
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
CLIP_S=${CLIP_S:-30}
FPS=${FPS:-60}
SIDE=${SIDE:-1280x720}
CRF=${CRF:-21}
MAX_MB=${MAX_MB:-25}
TIMEOUT=${CLIP_TIMEOUT:-3600}
for a in "$@"; do
	case "$a" in
	--graphics=* | --screenshot=* | --shot-times=* | --shot-fast*)
		echo "==> $a gibt dieses Werkzeug selbst vor" >&2
		exit 2
		;;
	esac
done
mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_ab_clip.XXXXXX")
TMP=$(cd "$TMP" && pwd)
trap 'rm -rf "$TMP"' EXIT
export MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
mkdir -p "$MESA_SHADER_CACHE_DIR"
XDG_DATA_HOME="$TMP/import" "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
END_S=$(awk -v s="$CLIP_S" 'BEGIN { printf "%.2f", s + 0.5 }')
BASE=${OUT%.mp4}

# record <mode> <arguments…>: Movie Maker run of the race scene into $TMP/<mode>.avi
record() {
	local mode=$1
	shift
	local t0=$SECONDS
	mkdir -p "$TMP/xdg_$mode"
	XDG_DATA_HOME="$TMP/xdg_$mode" nice -n 10 timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --write-movie "$TMP/$mode.avi" \
		--fixed-fps "$FPS" res://scenes/race/race.tscn -- "$@" "--graphics=$mode" --sound=arcade --no-watchdog \
		--gfx-sync "--screenshot=$TMP/end_$mode" "--shot-times=$END_S" >"${BASE}_$mode.log" 2>&1
	local code=$?
	printf '    %-7s Exit %d, %4d s, %s\n' "$mode" $code $((SECONDS - t0)) "$(du -h "$TMP/$mode.avi" 2>/dev/null | cut -f1)"
	if [ $code -ne 0 ] || [ ! -s "$TMP/$mode.avi" ] || grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR" "${BASE}_$mode.log"; then
		echo "==> Aufnahme $mode fehlgeschlagen (siehe ${BASE}_$mode.log)" >&2
		return 1
	fi
	if [ "$mode" = modern ] && grep -q "Modus Modern nicht möglich" "${BASE}_$mode.log"; then
		echo "==> Modern ist auf Arcade zurückgefallen (siehe ${BASE}_$mode.log)" >&2
		return 1
	fi
	return 0
}

record arcade "$@" || exit 1
# shellcheck disable=SC2086
record modern "$@" ${GFX_ARGS:-} || exit 1

# first frame of the running stage per recording: the loading cover of the race session is Color(0.015, 0.02, 0.07)
# (scripts/race/race_session.gd) – a frame whose pixels are mostly that colour is a loading frame
first_live() {
	python3 -I - "$1" "$TMP/probe_$2" <<'EOF'
import os, subprocess, sys
import numpy as np
from PIL import Image
avi, tmp = sys.argv[1], sys.argv[2]
os.makedirs(tmp, exist_ok=True)
# the first 40 s of the file at a small size are enough to find the end of the loading picture
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi, "-t", "40", "-vf", "scale=160:90", os.path.join(tmp, "%05d.png")],
               check=True)
files = sorted(os.listdir(tmp))
cover = np.array([0.015 * 255, 0.02 * 255, 0.07 * 255])
first = 0
for i, f in enumerate(files):
    im = np.asarray(Image.open(os.path.join(tmp, f)).convert("RGB")).astype(float)
    near = (np.abs(im - cover) <= 8).all(axis=2).mean()
    if near < 0.5:
        first = i
        break
print(first)
EOF
}
FA=$(first_live "$TMP/arcade.avi" arcade) || exit 1
FM=$(first_live "$TMP/modern.avi" modern) || exit 1
echo "    erstes Bild der laufenden Etappe: Arcade $FA, Modern $FM (Ladebild davor abgeschnitten)"
FRAMES=$((CLIP_S * FPS))
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
encode() {
	local side=$1 crf=$2
	local w=${side%x*} h=${side#*x}
	local fs=$((h / 24))
	local lab="drawtext=fontfile=$FONT:text='%s':x=(w-tw)/2:y=10:fontsize=$fs:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=8"
	# shellcheck disable=SC2059
	local filt="[0:v]trim=start_frame=$FA:end_frame=$((FA + FRAMES)),setpts=PTS-STARTPTS,scale=$w:$h,$(printf "$lab" Arcade)[a];[1:v]trim=start_frame=$FM:end_frame=$((FM + FRAMES)),setpts=PTS-STARTPTS,scale=$w:$h,$(printf "$lab" Modern)[m];[a][m]hstack=inputs=2[v]"
	nice -n 10 ffmpeg -v error -y -threads 2 -i "$TMP/arcade.avi" -i "$TMP/modern.avi" -filter_complex "$filt" -map "[v]" \
		-r "$FPS" -c:v libx264 -preset slow -crf "$crf" -pix_fmt yuv420p -movflags +faststart -threads 2 "$OUT"
}
side=$SIDE
crf=$CRF
for attempt in 1 2 3 4 5; do
	encode "$side" "$crf" || { echo "==> ffmpeg fehlgeschlagen" >&2; exit 1; }
	mb=$(( ($(stat -c %s "$OUT") + 999999) / 1000000 ))
	echo "    Versuch $attempt: ${side} je Seite, CRF $crf -> $mb MB"
	[ "$mb" -le "$MAX_MB" ] && break
	if [ $attempt -ge 3 ]; then
		side=960x540
	else
		crf=$((crf + 3))
	fi
done
if [ "${KEEP_AVI:-0}" = 1 ]; then
	cp "$TMP/arcade.avi" "${BASE}_arcade.avi"
	cp "$TMP/modern.avi" "${BASE}_modern.avi"
fi
dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT" 2>/dev/null)
echo "$OUT ($(du -h "$OUT" | cut -f1), ${dur%.*} s)"
mb=$(( ($(stat -c %s "$OUT") + 999999) / 1000000 ))
[ "$mb" -le "$MAX_MB" ]
