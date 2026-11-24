#!/bin/bash
# QA-MID: A/B pictures of the fix worktree (resumable) for the tags given; positions from media_pos.txt
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/xdg/fixab; mkdir -p $XDG_DATA_HOME
for tag in "$@"; do
	[ -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/ab/${tag}_ab_00.jpg ] && continue
	args=$(grep "^$tag " /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/media_pos.txt | cut -d' ' -f2-)
	t0=$SECONDS
	(cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix && GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/ab/$tag --shot-times=3 $args > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/ab/$tag.run.log 2>&1)
	echo "$(date +%T) fixab $tag exit=$? $((SECONDS - t0)) s" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
done
echo "FIXAB DONE $(date +%T)" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
