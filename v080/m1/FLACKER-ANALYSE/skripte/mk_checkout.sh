#!/bin/bash
# Scratch checkout of a build (no git metadata, no branch): git archive + import cache copy + headless import.
# usage: mk_checkout.sh <commit> <dir>
set -e
REPO=/home/user/crossing-europe---a-racing-xperience
C="$1"
D="$2"
case "$D" in /*) ;; *) echo "absolute dir needed"; exit 2;; esac
mkdir -p "$D"
cd "$REPO"
git archive "$C" | tar -x -C "$D"
cp -a "$REPO/.godot" "$D/.godot"
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/xdg
mkdir -p "$XDG_DATA_HOME"
cd "$D"
nice -n 19 godot --headless --path "$D" --import > "$D/../import_$(basename "$D").log" 2>&1 || true
tail -3 "$D/../import_$(basename "$D").log"
echo DONE
