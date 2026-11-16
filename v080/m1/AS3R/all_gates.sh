#!/usr/bin/env bash
# AS3R: all gates on the final head, one after the other
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R
$S/gates.sh geom
$S/gates.sh keys
$S/gates.sh det
$S/ab_batch.sh
$S/gates.sh tests
$S/gates.sh golden
echo ALL_GATES_DONE
