#!/usr/bin/env bash
# QA-R6: wait until shot $1 has ended (or was skipped), then stack its frames
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
until grep -qE "(end|skip) $1" $S/gates/chain_b.txt; do sleep 10; done
grep -E "(end|skip) $1" $S/gates/chain_b.txt | tail -1
$S/bin/stack.sh $1 ${2:-1400}
