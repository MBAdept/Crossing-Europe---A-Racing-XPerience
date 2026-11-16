#!/bin/bash
# Does a WM_DELETE_WINDOW from outside end the game? v0.7.0 (ref) and this tree, title screen, own Xvfb :98.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
Xvfb :98 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
XP=$!
sleep 2
export DISPLAY=:98
for tree in ref cur; do
	if [ $tree = ref ]; then D=$S/ref070; A=(--); else D=$WT; A=(-- --no-chooser --graphics=arcade); fi
	X=$S/xdg_xclose_$tree; rm -rf "$X"; mkdir -p "$X"
	XDG_DATA_HOME=$X godot --path "$D" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 "${A[@]}" > "$S/xclose_$tree.log" 2>&1 &
	P=$!
	sleep 15
	echo "== $tree: windows named Crossing:"
	for w in $(xdotool search --name "Crossing" 2>/dev/null); do
		echo "  $w $(xdotool getwindowname $w) pid=$(xprop -id $w _NET_WM_PID 2>/dev/null | awk '{print $3}') map=$(xwininfo -id $w | grep 'Map State' | awk '{print $3}') protocols=$(xprop -id $w WM_PROTOCOLS 2>/dev/null | cut -c1-80)"
	done
	W=$(xdotool search --name "Crossing" | head -1)
	python3 "$S/bin/xclose.py" "$W"
	t=0; while kill -0 $P 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
	if kill -0 $P 2>/dev/null; then echo "  $tree: läuft noch nach $((t / 2)) s"; kill -9 $P; else wait $P; echo "  $tree: beendet exit=$? nach $((t / 2)) s"; fi
	tail -3 "$S/xclose_$tree.log"
done
kill $XP
