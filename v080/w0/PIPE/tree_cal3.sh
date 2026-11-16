#!/bin/bash
# scratch: lod1 vs impostor of the oak under separate lights (display values, crown box)
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
run() {
	label=$1; shift
	$D/p.sh sheet cs_probe --only="props/tree_oak" --tile=480x400 --cols=3 --lods=lod1 "$@" >/dev/null
	python3 $D/tree_cal4.py "$label"
}
if [ "$1" != "short" ]; then
	run "day ambient only" --sun-energy=0
	for sun in "0,0.5,1" "-0.55,0.92,0.55" "1,0.5,0" "0.3,0.5,-1"; do
		run "day sun only $sun" --ambient-energy=0 --sun=$sun
	done
fi
for sun in "0,0.5,1" "-0.55,0.92,0.55" "1,0.5,0" "0.3,0.5,-1"; do
	run "day $sun" --sun=$sun
done
for sun in "-0.55,0.92,0.55" "0.3,0.5,-1"; do
	run "night $sun" --night --sun=$sun
	run "night x4 $sun" --night --sun=$sun --sun-energy=0.4 --ambient-energy=2.2
done
