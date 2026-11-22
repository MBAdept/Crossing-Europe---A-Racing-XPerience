#!/usr/bin/env bash
# QA-R7b: picture batches in priority order (one Godot run at a time), log in pics.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
GROUP=flood $S/sh/batch_pics.sh
GROUP=flood2 $S/sh/batch_pics.sh
GROUP=arr $S/sh/batch_pics.sh
GROUP=near $S/sh/batch_pics.sh
GROUP=deck $S/sh/batch_pics.sh
GROUP=sky $S/sh/batch_pics.sh
GROUP=dusk SKIP_BASE=1 $S/sh/batch_pics.sh
echo MASTER_PICS_DONE
