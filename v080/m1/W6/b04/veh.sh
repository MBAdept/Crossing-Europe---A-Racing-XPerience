#!/bin/bash
# A-29 B-04: the QA vehicle probe (QA-M2-BILD/probe/qa_vehicles.gd) on the current worktree.  veh.sh <mode> <tag> <args...>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
O=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/b04/veh; mode=$1; tag=$2; shift 2
cd $WT
x=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/xdg/veh_$$; rm -rf $x; mkdir -p $x
XDG_DATA_HOME=$x nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 	--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD/probe/qa_vehicles.gd -- --graphics=$mode --gfx-sync 	--sound=arcade --out=$O --tag=$tag "$@" > $O/$tag.log 2>&1
echo "veh $mode $tag exit=$? pics=$(ls $O/${tag}_*.png 2>/dev/null | wc -l)"
rm -rf $x
