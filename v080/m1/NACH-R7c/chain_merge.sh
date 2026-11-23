#!/bin/bash
# Chain merge probe in the scratch clone: HEAD(fix-r7c) + fix-rint + fix-r7a + fix-r7b, all orders that matter.
set -u
cd /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c/mclone || exit 9
export GIT_AUTHOR_NAME=probe GIT_AUTHOR_EMAIL=probe@local GIT_COMMITTER_NAME=probe GIT_COMMITTER_EMAIL=probe@local
C7=3b3107be4df09c01aff907a026a709ac0195faea
RINT=32482114c98b39c17bc7928f6206d355d4d61366
R7A=4a43944338a47f188a0ff795f95691e507e515da
R7B=c50d58f722291796c685b8ab3d6fd038bb5e67e4
step() { # $1 = commit A, $2 = commit B, $3 = label
	local out tree
	out=$(git merge-tree --write-tree --name-only "$1" "$2")
	local rc=$?
	tree=$(echo "$out" | head -1)
	echo "== $3: exit $rc" >&2
	if [ $rc -ne 0 ]; then echo "$out" | sed -n '2,40p' >&2; fi
	git commit-tree "$tree" -p "$1" -p "$2" -m "$3"
}
for order in "RINT R7A R7B C7" "C7 RINT R7A R7B" "R7A R7B RINT C7"; do
	set -- $order
	cur=${!1}
	shift
	lab=$order
	for b in "$@"; do
		cur=$(step "$cur" "${!b}" "$lab +$b")
	done
	echo "order [$order] -> $cur"
	git ls-tree -r --name-only "$cur" > /dev/null
done
echo "final tree of last order:"
git rev-parse "$cur^{tree}"
echo "$cur" > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c/merge4.sha
