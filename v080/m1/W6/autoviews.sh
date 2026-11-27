#!/bin/bash
# W6: render the review views of every C1 model as soon as its real.sh round is finished (one at a time)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
for s in vienna_zinshaus spanish_casa spanish_block italian_block vienna_palais italian_palazzo spanish_ladrillo italian_venezia vienna_kirche; do
	[ -f $W6/shots/r1_$s/lods_h22.png ] && continue
	# real.sh prints "=== real fertig" once per id; the n-th line belongs to the n-th id of the queue
	n=$(grep -n "^$s$" <(printf '%s\n' vienna_zinshaus spanish_casa spanish_block italian_block vienna_palais italian_palazzo spanish_ladrillo italian_venezia vienna_kirche) | cut -d: -f1)
	until [ "$(grep -c '=== real fertig' $W6/logs/queue_c1.log)" -ge "$n" ]; do sleep 20; done
	bash $W6/views.sh r1_$s props/city_$s 9 >> $W6/logs/autoviews.log 2>&1
done
echo "AUTOVIEWS DONE $(date +%T)" >> $W6/logs/autoviews.log
