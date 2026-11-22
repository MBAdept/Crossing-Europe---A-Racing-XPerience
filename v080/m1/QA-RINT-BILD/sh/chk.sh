#!/bin/bash
# chk.sh <file.gd in sh/> : compile check of a QA script in the head worktree (copy, check, remove)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
export XDG_DATA_HOME=$S/xdg/chk
mkdir -p $XDG_DATA_HOME
cp $S/sh/$1 $W/qa_chk_tmp.gd
cd $W
timeout 120 godot --headless --path . --check-only -s res://qa_chk_tmp.gd 2>&1 | grep -v "^Godot\|^$" | head -8
rm -f $W/qa_chk_tmp.gd $W/qa_chk_tmp.gd.uid
echo "checked $1"
