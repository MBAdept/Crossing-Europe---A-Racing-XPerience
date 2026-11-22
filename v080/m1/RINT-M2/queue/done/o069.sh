S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
# apply the warm-step variant with the lower station collect() max to the worktree – only variants whose jobpath run
# shows 0 differing decisions, whose deck run has no script errors and whose max is below the 2.40 ms of 02051f7
best=""
bestmx=2.40
for v in warm:station_warm.gd:jobpath_warm.log warm07:station_warm07.gd:jobpath_warm07.log; do
	IFS=: read -r tag file jp <<< "$v"
	sum=$(grep JOBPATH-SUMMARY $S/logs/$jp)
	err=$(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/n8_dev_deck_$tag.log)
	mx=$(python3 $S/sh/collectagg.py $S/stage/n8_dev_deck_$tag.log 2>/dev/null | grep ' station ' | sed -n 's/.*max \([0-9.]*\) ms.*/\1/p')
	echo "$tag: $sum; $err script errors; station max $mx"
	case "$sum" in
	*"differing=0;"*) ;;
	*) continue ;;
	esac
	[ "$err" = 0 ] || continue
	if python3 -c "import sys; sys.exit(0 if '$mx' and float('$mx') < float('$bestmx') else 1)"; then
		best=$file
		bestmx=$mx
	fi
done
if [ -n "$best" ]; then
	cp $S/$best $W/scripts/race3d/builders/station.gd
	python3 $S/sh/edit_warm_test.py $W/tests/unit/race3d/test_structures.gd
	echo "APPLIED $best (station max $bestmx ms)"
else
	echo "NOT APPLIED"
fi
