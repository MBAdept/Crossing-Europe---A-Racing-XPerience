#!/bin/bash
# scratch: how dark tones come out of the rig: lod1 crown, impostor crown and open ground for several energies
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
run() {
	label=$1; shift
	$D/p.sh sheet cs_probe --only="props/tree_oak" --tile=480x400 --cols=3 --lods=lod1 "$@" >/dev/null
	echo "== $label"
	python3 $D/px_mean.py $D/cs_probe.png lod1=170,120,130,100 impostor=1140,120,130,100 ground=20,330,100,40
}
run "night default (sun 0.1, ambient 0.55)" --night
run "night ambient only" --night --sun-energy=0
run "night moon only" --night --ambient-energy=0
run "night moon 0.4, ambient 0.55" --night --sun-energy=0.4
run "night moon 0.1, ambient 2.0" --night --ambient-energy=2.0
