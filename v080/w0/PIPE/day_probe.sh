#!/bin/bash
# scratch: is the shadow-casting light added in sRGB or in linear space in this rig (post path on)?
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
run() {
	label=$1; shift
	$D/p.sh sheet cs_probe --only="props/tree_oak" --tile=480x400 --cols=3 --lods=lod1 "$@" >/dev/null
	echo "== $label"
	python3 $D/px_mean.py $D/cs_probe.png lod1=170,120,130,100 impostor=1140,120,130,100 ground=20,330,100,40
}
run "day both (sun 0.8, ambient 1.0)"
run "day ambient only" --sun-energy=0
run "day sun only" --ambient-energy=0
