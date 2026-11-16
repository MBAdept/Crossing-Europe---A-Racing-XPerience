#!/bin/bash
# Does Godot (this build) take a WM_DELETE_WINDOW from xclose.py without a window manager? Title screen, 12 s, close.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/quit
mkdir -p "$OUT"
DISP=""; for n in $(seq 71 89); do [ -e /tmp/.X11-unix/X$n ] || [ -e /tmp/.X$n-lock ] || { DISP=:$n; break; }; done
Xvfb $DISP -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
XP=$!
sleep 2
export DISPLAY=$DISP
X=$S/xdg_xclose; rm -rf "$X"; mkdir -p "$X/godot/app_userdata/Crossing Europe – A Racing Xperience"
printf '{"settings_version": 3, "graphics_mode": "arcade", "fullscreen": false}\n' > "$X/godot/app_userdata/Crossing Europe – A Racing Xperience/settings.json"
XDG_DATA_HOME=$X nice -n 10 godot --path "$WT" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 > "$OUT/xclose_test.log" 2>&1 &
P=$!
sleep 14
echo "windows of pid $P: $(xdotool search --pid $P 2>/dev/null | tr '\n' ' ')"
echo "windows by name: $(xdotool search --name 'Crossing' 2>/dev/null | tr '\n' ' ')"
for w in $(xdotool search --pid $P 2>/dev/null); do
	echo "  $w: $(xprop -id $w WM_NAME WM_PROTOCOLS 2>/dev/null | tr '\n' ' ')"
	python3 "$S/bin/xclose.py" "$w"
done
t=0; while kill -0 $P 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
if kill -0 $P 2>/dev/null; then echo "NOT CLOSED after 15 s -> TERM"; kill -TERM $P; sleep 3; kill -9 $P 2>/dev/null; wait $P; echo "exit=$?"; else wait $P; echo "closed by WM_DELETE: exit=$? after $((t / 2)) s"; fi
grep -E "ERROR|leaked|still in use" "$OUT/xclose_test.log" | head -5
kill $XP
echo ALLDONE
