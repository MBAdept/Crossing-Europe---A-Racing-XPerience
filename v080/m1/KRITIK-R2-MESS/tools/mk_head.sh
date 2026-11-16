#!/bin/bash
# usage: mk_head.sh <name> <commit>
set -e
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS
D=$W/heads/$1
mkdir -p $D
git -C /home/user/crossing-europe---a-racing-xperience archive $2 | tar -x -C $D
cp -a /home/user/crossing-europe---a-racing-xperience/.godot $D/
echo "$2" > $D/.commit
export XDG_DATA_HOME=$W/xdg/import_$1
mkdir -p $XDG_DATA_HOME
cd $D
nice -n 19 godot --headless --path $D --import > $W/logs/import_$1.log 2>&1 || echo "import exit $?"
echo "done $1 $2"
