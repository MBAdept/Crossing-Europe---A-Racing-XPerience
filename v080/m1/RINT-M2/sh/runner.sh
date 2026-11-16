#!/bin/bash
# RINT-M2 job queue: runs $S/queue/*.sh one after another (sorted), moves each to done/ with its log.
# Stops when $S/queue/STOP exists or after $1 seconds (default 7000) of total runtime with an empty queue.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
LIMIT=${1:-7000}
mkdir -p $S/queue/done
t0=$SECONDS
while true; do
	if [ -f $S/queue/STOP ]; then
		rm -f $S/queue/STOP
		echo "runner: STOP"
		exit 0
	fi
	if pgrep -f rc_merged.sh > /dev/null; then
		sleep 15
		continue
	fi
	j=$(ls $S/queue/*.sh 2> /dev/null | sort | head -1)
	if [ -z "$j" ]; then
		if [ $((SECONDS - t0)) -gt $LIMIT ]; then
			echo "runner: idle limit"
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
done
