#!/bin/bash
# start zs2_golden.sh in the clip slot as soon as the clips are done
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID
until grep -q "CLIPS DONE" $Q/logs/media.log; do sleep 30; done
bash $Q/sh/zs2_golden.sh
