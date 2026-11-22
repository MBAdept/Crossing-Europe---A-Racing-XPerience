S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
# apply the warm-step station builder to the worktree only when: jobpath 0 differing, the deck run without script
# errors and the station's collect() max below 2.0 ms
sum=$(grep JOBPATH-SUMMARY $S/logs/jobpath_warm.log)
echo "jobpath: $sum"
case "$sum" in
*"differing=0;"*) ok1=1 ;;
*) ok1=0 ;;
esac
err=$(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/n8_dev_deck_warm.log)
st=$(python3 $S/sh/collectagg.py $S/stage/n8_dev_deck_warm.log 2>/dev/null | grep -i ' station ')
echo "deck: $err script errors; $st"
mx=$(echo "$st" | sed -n 's/.*max \([0-9.]*\) ms.*/\1/p')
ok2=$(python3 -c "print(1 if '$mx' and float('$mx') < 2.0 else 0)")
if [ "$ok1" = 1 ] && [ "$err" = 0 ] && [ "$ok2" = 1 ]; then
	cp $S/station_warm.gd $W/scripts/race3d/builders/station.gd
	python3 $S/sh/edit_warm_test.py $W/tests/unit/race3d/test_structures.gd
	echo "APPLIED station_warm.gd (max $mx ms)"
else
	echo "NOT APPLIED (ok1=$ok1 err=$err max=$mx)"
fi
