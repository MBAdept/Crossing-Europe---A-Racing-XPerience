#!/bin/bash
# Secure the lead's scratch state (reports, notes, scripts, STAND files, workflow journals) on an orphan wip branch.
set -e
SCR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad
SP=$SCR/v080
W=/root/.claude/projects/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/subagents/workflows
ST=$SCR/archiv_stage
rm -rf $ST; mkdir -p $ST/v080 $ST/_journals
cd $SP
EXCL='-not -path */tmp/* -not -path *cache* -not -path */godot_src/* -not -path */xdg/* -not -path */.godot/* -not -path */runs*/*'
{ find . -type f -name '*.md' $EXCL
  find ./m1/lead -type f -size -1M
  find . -type f \( -name '*.py' -o -name '*.sh' -o -name '*.gd' -o -name '*.js' -o -name '*.mjs' \) -size -300k $EXCL
  find . -type f \( -name '*.json' -o -name '*.txt' -o -name '*.csv' \) -size -100k $EXCL
} | sort -u > $SCR/arch_list2.txt
tr '\n' '\0' < $SCR/arch_list2.txt | xargs -0 cp --parents -t $ST/v080
for j in $W/*/journal.jsonl; do r=$(basename $(dirname $j)); mkdir -p $ST/_journals/$r; cp $j $ST/_journals/$r/; done
cp $SCR/*.sh $ST/ 2>/dev/null || true
du -sh $ST; find $ST -type f | wc -l
