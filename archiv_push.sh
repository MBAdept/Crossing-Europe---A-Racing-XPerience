#!/bin/bash
# commit the staged archive as a commit on origin/wip/v080-lead-archiv (orphan; parent = previous archive if any) and push
set -e
SCR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad
ST=$SCR/archiv_stage
cp $SCR/v080/m1/lead/WIEDERAUFNAHME.md $SCR/v080/m1/lead/m2_integration_notes.md $SCR/v080/m1/lead/contract_11_3.md $ST/v080/m1/lead/
cp $SCR/v080/m1/lead/WIEDERAUFNAHME.md $ST/README.md
cd /home/user/crossing-europe---a-racing-xperience
export GIT_INDEX_FILE=$SCR/archiv.index
rm -f $GIT_INDEX_FILE
git --work-tree=$ST add -A .
TREE=$(git write-tree)
PARENT=""
if git fetch -q origin wip/v080-lead-archiv 2>/dev/null; then PARENT="-p $(git rev-parse FETCH_HEAD)"; fi
printf 'v0.8.0 Leitung: Archiv der Berichte, Notizen, Arbeitsstände und Workflow-Protokolle (Sicherung vor Abo-Ende 22.11.)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' > $SCR/archiv_msg.txt
C=$(git commit-tree $TREE $PARENT -F $SCR/archiv_msg.txt)
unset GIT_INDEX_FILE
echo "commit $C"
for i in 1 2 3 4; do git push origin $C:refs/heads/wip/v080-lead-archiv && break; sleep $((i*4)); done
git ls-remote origin wip/v080-lead-archiv
