#!/bin/bash
# RINT-M2 job queue, detached successor of runner.sh (the first one ran under a 2 h limit): waits until no other
# runner runs, re-queues a job the old runner left unfinished, then runs $S/queue/*.sh one after another (sorted).
# Stops when $S/queue/STOP exists or after $1 seconds idle with an empty queue (default 3600).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
IDLE=${1:-3600}
while pgrep -f "runner.sh 6900" > /dev/null; do
	sleep 10
done
last=$(tail -1 $S/queue/runner.log)
case "$last" in
*" start "*)
	b=${last##* start }
	if [ -f $S/queue/done/$b.sh ]; then
		cp $S/queue/done/$b.sh $S/queue/$b.sh
		echo "$(date -u +%H:%M:%S) runner2: re-queued $b (old runner stopped during it)" >> $S/queue/runner.log
	fi
	;;
esac
echo "$(date -u +%H:%M:%S) runner2: started (pid $$)" >> $S/queue/runner.log
idle0=$SECONDS
while true; do
	if [ -f $S/queue/STOP ]; then
		rm -f $S/queue/STOP
		echo "$(date -u +%H:%M:%S) runner2: STOP" >> $S/queue/runner.log
		exit 0
	fi
	j=$(ls $S/queue/*.sh 2> /dev/null | LC_ALL=C sort | head -1)
	if [ -z "$j" ]; then
		if [ $((SECONDS - idle0)) -gt $IDLE ]; then
			echo "$(date -u +%H:%M:%S) runner2: idle limit" >> $S/queue/runner.log
			exit 0
		fi
		sleep 10
		continue
	fi
	b=$(basename $j .sh)
	mv $j $S/queue/done/$b.sh
	echo "$(date -u +%H:%M:%S) start $b" >> $S/queue/runner.log
	bash $S/queue/done/$b.sh > $S/queue/done/$b.log 2>&1
	echo "$(date -u +%H:%M:%S) end $b exit $?" >> $S/queue/runner.log
	idle0=$SECONDS
done
