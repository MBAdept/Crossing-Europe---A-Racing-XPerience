#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
L=$S/ab_var/batch2.log
mkdir -p $S/ab_var
{
$S/tools/ab.sh $S/ab_var medium S1H6 S1H195 S1H22 S2H22 -- --shot-times=2,6
TAG=nofog XGFX="--gfx-debug=cover" MODES=modern $S/tools/ab.sh $S/ab_var medium S1 -- --shot-times=2,6
TAG=low $S/tools/ab.sh $S/ab_var low S1 -- --shot-times=2,6
TAG=high $S/tools/ab.sh $S/ab_var high S1 -- --shot-times=2,6
TAG=gles DRIVER=opengl3_es MODES=modern $S/tools/ab.sh $S/ab_var medium S1 -- --shot-times=2,6
TAG=deck SCREEN=1280x800 $S/tools/ab.sh $S/ab_var deck S1 -- --shot-times=2,6
echo DONE
} > $L 2>&1
