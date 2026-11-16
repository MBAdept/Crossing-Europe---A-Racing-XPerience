#!/bin/bash
# waits for the orphaned h_N1deck run, marks it done, then continues the queue with a fresh queue.sh
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
until grep -q 'ab.sh head N1_deck exit=' $S/logs/h_N1deck.log 2>/dev/null; do sleep 10; done
echo "rc=0 (orphan)" > $S/done/h_N1deck
echo "=== $(date +%H:%M:%S) h_N1deck finished (orphan)"
exec $S/sh/queue.sh "$@"
