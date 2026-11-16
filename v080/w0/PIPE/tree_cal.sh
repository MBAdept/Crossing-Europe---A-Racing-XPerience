#!/bin/bash
# measures lod1 vs impostor of the oak for four sun directions (scratch helper)
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
for sun in "0,0.5,1" "-0.55,0.92,0.55" "1,0.5,0" "0.3,0.5,-1"; do
	$D/p.sh sheet cs_tree_sun --only="props/tree_oak" --tile=480x400 --cols=3 --lods=lod1 --sun=$sun >/dev/null
	python3 $D/tree_cal.py "$sun"
done
