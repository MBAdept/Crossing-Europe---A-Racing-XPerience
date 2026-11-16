#!/bin/bash
# usage: mkcopy.sh <name> <commit>   (KRITIK-R3: copy of a head via git archive + .godot, imported once)
set -e
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3
NAME=$1
COMMIT=$2
DIR=$S/heads/$NAME
REPO=/home/user/crossing-europe---a-racing-xperience
if [ -d "$DIR" ]; then echo "exists: $DIR"; exit 1; fi
mkdir -p "$DIR"
git -C $REPO archive $COMMIT | tar -x -C "$DIR"
cp -a $REPO/.godot "$DIR/"
mkdir -p $S/xdg/import_$NAME
cd "$DIR"
export XDG_DATA_HOME=$S/xdg/import_$NAME
nice -n 19 timeout 1800 godot --headless --path "$DIR" --import > $S/logs/import_$NAME.log 2>&1 || echo "import exit $?"
tail -5 $S/logs/import_$NAME.log
echo "done $NAME"
