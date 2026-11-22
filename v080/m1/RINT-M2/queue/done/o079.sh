S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
sum=$(grep JOBPATH-SUMMARY $S/logs/jobpath_warm12.log)
err=$(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/n8_dev_deck_warm12.log)
mx=$(python3 $S/sh/collectagg.py $S/stage/n8_dev_deck_warm12.log 2>/dev/null | grep ' station ' | sed -n 's/.*max \([0-9.]*\) ms.*/\1/p')
echo "warm12: $sum; $err script errors; station max $mx"
grep -a 'STATDBG' $S/stage/n8_dev_deck_warm12.log | head -40
case "$sum" in
*"differing=0;"*) ok1=1 ;;
*) ok1=0 ;;
esac
if [ "$ok1" = 1 ] && [ "$err" = 0 ] && python3 -c "import sys; sys.exit(0 if '$mx' and float('$mx') < 2.076 else 1)"; then
	cp $S/station_warm12.gd $W/scripts/race3d/builders/station.gd
	echo "APPLIED station_warm12.gd (station max $mx ms)"
else
	echo "NOT APPLIED – station_warm.gd stays"
fi
