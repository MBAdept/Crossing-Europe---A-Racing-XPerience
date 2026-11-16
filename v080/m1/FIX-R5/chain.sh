#!/usr/bin/env bash
# FIX-R5: after the picture queue, the gates and the two full Kiel–Hamburg runs, detached (survives the 2-h limit of a
# background tool call). Progress in queue.log.
F=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5
until grep -q "QUEUE DONE r4mix" "$F/queue.log"; do sleep 15; done
"$F/queue2.sh" r4mix2 scripts sight path tests golden render modern perf_kh_new perf_kh_base
