#!/usr/bin/env bash
# R7c: after the picture queue, the gates (detached; progress in gates/summary.txt)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
until grep -q "queue fertig: lodcheck far078" "$S/gates/summary.txt"; do sleep 20; done
"$S/queue.sh" lodcheck tests golden mcheck render sight perf > "$S/logs/queue2.out" 2>&1
