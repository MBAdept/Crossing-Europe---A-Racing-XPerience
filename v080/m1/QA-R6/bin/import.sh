#!/bin/bash
# import a godot project dir: $1 dir, $2 log
cd "$1" || exit 9
nice -n 10 timeout 900 godot --headless --path . --import > "$2" 2>&1
echo "exit $?" >> "$2"
