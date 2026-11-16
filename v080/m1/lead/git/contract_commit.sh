#!/bin/bash
# Lead: fast-forward v0.8.0 to QA1's head and create the contract commit §11.2 on a side branch via plumbing
set -euo pipefail
REPO=/home/user/crossing-europe---a-racing-xperience
SP=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
BASE=92ece73fc8bca9782a1e72f3f71b007ed96641f7
cd "$REPO"
git merge --ff-only "$BASE"
git push origin v0.8.0
W=$SP/m1/lead/git
git show "$BASE":docs/dev/v080_contract.md > "$W/contract_base.md"
cat "$W/contract_base.md" > "$W/contract_new.md"
printf '\n' >> "$W/contract_new.md"
cat "$SP/m1/lead/contract_11_2_final.md" >> "$W/contract_new.md"
BLOB=$(git hash-object -w "$W/contract_new.md")
export GIT_INDEX_FILE="$W/idx"
rm -f "$GIT_INDEX_FILE"
git read-tree "$BASE"
git update-index --cacheinfo 100644,"$BLOB",docs/dev/v080_contract.md
TREE=$(git write-tree)
unset GIT_INDEX_FILE
cat > "$W/msg.txt" <<'MSG'
Bauvertrag v0.8.0: Nachträge §11.2 (A-9 bis A-16) aus M1 und den frühen M2-Paketen

Leitungsentscheidungen mit Belegen: Ersatzbilder, Look-Gesetze, Messregeln, Plan, Modelle,
Messkriterien des Modern-Klangs, Testbuilds und QA nach QA1 (Start bei km 0 als Position S0,
Schilder in F1, Kurvenkamera), Umgebungsmodelle nach AS3R/AS4R.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq
MSG
C=$(git commit-tree "$TREE" -p "$BASE" -F "$W/msg.txt")
echo "contract commit $C"
git push origin "$C":refs/heads/wip/v080-vertrag
git diff --stat "$BASE" "$C"
