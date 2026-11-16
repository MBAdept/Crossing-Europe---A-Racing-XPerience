#!/bin/bash
# kern.sh <rounds> – check_modern_stage --only=kern_zeit on head and base, alternating (headless, nice 19); kern.log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
mkdir -p "$R4/data/kern"
for i in $(seq 1 "${1:-2}"); do
	for tag in head base; do
		tree=$WT
		[ "$tag" = base ] && tree=$R4/base
		cd "$tree" || exit 2
		XDG_DATA_HOME=$R4/data/kern nice -n 19 timeout 900 godot --headless --path . -s res://tests/race3d/check_modern_stage.gd \
			-- --only=kern_zeit > "$R4/data/kern/${tag}_$i.out" 2>&1
		echo "$tag $i $(date -u +%T) load $(cut -d' ' -f1 /proc/loadavg) $(grep -a 'CHECK kern_zeit' "$R4/data/kern/${tag}_$i.out" | cut -c1-330)" >> "$R4/kern.log"
	done
done
echo KERN_DONE >> "$R4/kern.log"
