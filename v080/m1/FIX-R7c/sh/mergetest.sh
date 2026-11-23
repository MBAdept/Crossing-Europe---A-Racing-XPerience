#!/bin/bash
# FIX-R7c: test_props (unit) in the merge of this head with another branch – mergetest.sh <tree id> <name>
# (the tree from "git merge-tree --write-tree HEAD <branch>", exported with git archive by the caller to $S/mt_<name>.tar)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
NAME=$1
DIR=$S/mt_$NAME
rm -rf "$DIR"
mkdir -p "$DIR"
tar -xf "$S/mt_$NAME.tar" -C "$DIR" || exit 1
rm -f "$S/mt_$NAME.tar"
cp -a "$WT/.godot" "$DIR/"
cd "$DIR" || exit 1
XDG_DATA_HOME=$S/xdg_mt nice -n 10 timeout 1200 godot --headless --path . --import > "$S/logs/mt_${NAME}_import.log" 2>&1
XDG_DATA_HOME=$S/xdg_mt nice -n 10 timeout 900 godot --headless --path . -s res://tests/check_scripts.gd > "$S/logs/mt_${NAME}_scripts.log" 2>&1
echo "scripts exit=$? $(tail -1 "$S/logs/mt_${NAME}_scripts.log")" > "$S/logs/mt_${NAME}.out"
XDG_DATA_HOME=$S/xdg_mt nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_props > "$S/logs/mt_${NAME}_props.log" 2>&1
echo "test_props exit=$? $(grep -E 'Tests, ' "$S/logs/mt_${NAME}_props.log") $(grep -c '^FAIL' "$S/logs/mt_${NAME}_props.log") FAIL" >> "$S/logs/mt_${NAME}.out"
cd "$S" && rm -rf "$DIR"
cat "$S/logs/mt_${NAME}.out"
