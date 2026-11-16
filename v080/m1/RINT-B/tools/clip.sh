#!/bin/bash
# 20 s side-by-side A/B clip of the start of Kiel–Hamburg (Movie Maker, 30 fps, both modes from the same simulation),
# Modern trimmed to its first race frame (its loading picture is cut off), hstack with labels, Modern's sound.
# usage: clip.sh <outdir>
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
OUT=${1:-$S/clip}
mkdir -p "$OUT"
export XDG_DATA_HOME=$S/xdg_clip
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
cd "$WT" || exit 1
ARGS=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never)
for m in ${MODES:-arcade modern}; do
	EXTRA=()
	[ "$m" = modern ] && EXTRA=(--gfx-preset=high --no-watchdog)   # the watchdog would lower the preset on llvmpipe
	t0=$SECONDS
	nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
		--write-movie "$OUT/$m.avi" --fixed-fps 30 --quit-after 900 res://scenes/race/race.tscn -- \
		"${ARGS[@]}" --graphics=$m --sound=$m "${EXTRA[@]}" > "$OUT/$m.log" 2>&1
	echo "$m exit=$? $((SECONDS - t0)) s"
done
