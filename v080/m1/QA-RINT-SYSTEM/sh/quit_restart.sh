#!/bin/bash
# Quit (window close) in every screen, then restart: no crash, no leak/error lines, the crash-guard marker is gone and
# the next start keeps Modern. Usage: quit_restart.sh [case ...]   (default: all cases)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
OUT=$S/out/quit
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa_quit
mkdir -p "$MESA_SHADER_CACHE_DIR"
# case = name|seconds|pause_at|game args
CASES=(
	"title|4|-1|--graphics=modern --no-chooser"
	"chooser|4|-1|--graphics=modern --screen=graphics_choice"
	"options|4|-1|--graphics=modern --screen=options"
	"vehicle_showroom|8|-1|--graphics=modern --screen=vehicle"
	"stage_select|4|-1|--graphics=modern --screen=stage_select"
	"leaderboards|4|-1|--graphics=modern --screen=leaderboards"
	"benchmark_screen|5|-1|--graphics=modern --screen=benchmark"
	"result|4|-1|--graphics=modern --screen=result"
	"race_loading|1.5|-1|--graphics=modern --stage=kiel_hamburg --gfx-preset=medium"
	"race_countdown|7|-1|--graphics=modern --stage=kiel_hamburg --gfx-preset=medium"
	"race_running|25|-1|--graphics=modern --stage=kiel_hamburg --gfx-preset=medium --autopilot"
	"race_paused|25|18|--graphics=modern --stage=kiel_hamburg --gfx-preset=medium --autopilot"
	"race_arcade|8|-1|--graphics=arcade --stage=kiel_hamburg"
	"race_paused_late|200|170|--graphics=modern --stage=kiel_hamburg --gfx-preset=medium --autopilot"
)
want="$*"
for c in "${CASES[@]}"; do
	IFS='|' read -r name secs pause args <<<"$c"
	if [ -n "$want" ] && [[ " $want " != *" $name "* ]]; then continue; fi
	home=$S/xdg/quit_$name
	rm -rf "$home"
	ud="$home/godot/app_userdata/Crossing Europe – A Racing Xperience"
	mkdir -p "$ud"
	printf '{"settings_version": 3, "graphics_mode": "modern", "language": "de", "fullscreen": false}\n' > "$ud/settings.json"
	cd "$W" || exit 1
	XDG_DATA_HOME=$home nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -s "$S/sh/quit_probe.gd" -- --qp-mode=run --qp-after="$secs" \
		--qp-pause-at="$pause" $args > "$OUT/$name.run.log" 2>&1
	rc=$?
	marker=no; [ -e "$ud/modern_start.lock" ] && marker=YES
	strikes=no; [ -e "$ud/modern_start.strikes" ] && strikes=YES
	bad=$(grep -cE "leaked|still in use|SCRIPT ERROR|Parse Error|^ERROR:|Segmentation|signal 11|crash" "$OUT/$name.run.log")
	# restart: what a fresh start decides (no --graphics here: the stored choice and the crash guard decide)
	XDG_DATA_HOME=$home nice -n 10 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -s "$S/sh/quit_probe.gd" -- --qp-mode=check > "$OUT/$name.check.log" 2>&1
	rc2=$?
	echo "$name rc=$rc errlines=$bad marker_after_quit=$marker strikes=$strikes | $(grep -m1 QP-RUN "$OUT/$name.run.log") | restart rc=$rc2 $(grep -m1 QP-CHECK "$OUT/$name.check.log")"
done
