#!/usr/bin/env bash
# waits for chain A to finish, then runs chain B
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
while ! grep -q " done$" $S/gates/chain_a.txt 2>/dev/null; do sleep 30; done
# also wait for the network scan (a Godot process at nice 19) to end
while pgrep -f qa_r6_scan_tmp.gd >/dev/null; do sleep 20; done
chmod +x $S/bin/chain_b.sh $S/bin/shot.sh
exec $S/bin/chain_b.sh
