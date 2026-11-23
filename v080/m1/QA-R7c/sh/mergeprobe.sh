#!/bin/bash
# mergeprobe.sh: git merge-tree of R7c head against the other M2 wave-5 branches (no checkout, nothing written to refs)
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-7 || exit 1
H=bd1803bbde9e1b7ccff6c3512fee8872d6a20103
for b in origin/wip/v080-r7a origin/wip/v080-r7b origin/wip/v080-fix-r7b origin/wip/v080-fix-rint; do
	echo "=== $b ($(git rev-parse --short "$b"))"
	git merge-tree --write-tree --name-only --no-messages "$H" "$b" > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/mt.out 2>&1
	echo "exit $?"
	tail -n +2 /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/mt.out | head -20
done
echo "=== files touched by fix-rint and r7c both"
git diff --name-only 9b02f050d7b078ae321ae83285ef94c6d3bde4bb origin/wip/v080-fix-rint > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/fr.files
git diff --name-only 43a1fcc "$H" > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/r7c.files
comm -12 <(sort /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/fr.files) <(sort /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/r7c.files)
for b in origin/wip/v080-r7a origin/wip/v080-r7b; do
	echo "=== files touched by $b and r7c both"
	git diff --name-only 9b02f050d7b078ae321ae83285ef94c6d3bde4bb "$b" | sort > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/o.files
	comm -12 /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/o.files <(sort /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/r7c.files)
done
