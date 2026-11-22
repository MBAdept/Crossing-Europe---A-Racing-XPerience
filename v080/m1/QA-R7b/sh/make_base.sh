#!/usr/bin/env bash
# QA-R7b: a plain copy of the base 9b02f05 (RINT-M2) for A/B against the base – no git, own import cache.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
B=$S/base
rm -rf $B
mkdir -p $B
cd $W || exit 1
git archive 9b02f050d7b078ae321ae83285ef94c6d3bde4bb | tar -x -C $B
cp -a $W/.godot $B/
echo BASE_COPIED
ls $B | head
