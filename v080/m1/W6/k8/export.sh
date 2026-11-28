#!/bin/bash
# K8: export (only tools/blender/_cache3d) - city_paris_haussmann first (no far_shift: must stay byte-equal except the
# key), then city_paris_corner (far_shift). Log $S/logs/k8.log, ends with "K8 EXPORT DONE".
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
export CE_THREADS=3
cd $WT
for id in props/city_paris_haussmann props/city_paris_corner; do
	n=$(basename $id)
	waitmem
	t0=$(date +%s)
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 > $S/logs/k8_exp_$n.log 2>&1
	rc=$?
	echo "$(date +%T) EXPORT $id rc $rc $(( $(date +%s) - t0 )) s: $(grep -E '^EXPORT|Traceback|Error' $S/logs/k8_exp_$n.log | grep -v CUEW | tail -2 | tr '\n' ' ')" >> $S/logs/k8.log
done
echo "$(date +%T) K8 EXPORT DONE" >> $S/logs/k8.log
