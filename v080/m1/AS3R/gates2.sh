#!/usr/bin/env bash
# AS3R: the rest of the gates after the first background run was stopped by its time limit (tests, golden),
# then the review measurements on the final head - one heavy job after the other
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R
$S/gates.sh tests
$S/gates.sh golden
$S/final2_batch.sh
echo ALL2_DONE
