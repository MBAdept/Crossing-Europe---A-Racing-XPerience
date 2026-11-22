#!/usr/bin/env bash
# QA-R7b: a plain copy of the package head 2c154bc for mutation tests (no git), with the import cache of the worktree.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
M=$S/mut
rm -rf $M
mkdir -p $M
cd $W || exit 1
git archive 2c154bc | tar -x -C $M
cp -a $W/.godot $M/
echo MUT_COPIED
