#!/bin/bash
# kills the C1 FIX-M2 shot of mt_queue.sh as soon as it starts (time)
for i in $(seq 1 600); do
	p=$(pgrep -f 'screenshot=.*C1_fxhigh')
	if [ -n "$p" ]; then kill $p; echo "killed C1_fxhigh"; exit 0; fi
	sleep 5
done
