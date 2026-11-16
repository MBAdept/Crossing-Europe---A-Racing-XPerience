#!/bin/bash
# pics.sh [job…] – Modern pictures of the final head (Arcade of the same state: QA-R4's head pictures, Arcade is frozen)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
export OUTDIR=$S/pics
mkdir -p $OUTDIR
for job in ${@:-N2N N2Ndeck N1 N1deck DEV C1 DUSK TEXIT}; do
	echo "== $job $(date -u +%T)" >> $OUTDIR/pics.log
	case $job in
	N2N) $S/sh/mshot.sh N2N_high N2N high --shot-times=2,4 ;;
	N2Ndeck) SCREEN=1280x800 $S/sh/mshot.sh N2N_deck N2N deck --shot-times=2 ;;
	N1) $S/sh/mshot.sh N1_high N1 high --shot-times=2,4 ;;
	N1deck) SCREEN=1280x800 $S/sh/mshot.sh N1_deck N1 deck --shot-times=2 ;;
	DEV) $S/sh/mshot.sh DEV_high DEV high --shot-times=2 ;;
	C1) $S/sh/mshot.sh C1_high C1 high --shot-times=2 ;;
	DUSK) $S/sh/mshot.sh S1DUSK_high S1DUSK high --shot-times=2 ;;
	TEXIT) $S/sh/mshot.sh TEXIT_high TEXIT high --shot-times=1.0,2.4,3.8 ;;
	esac >> $OUTDIR/pics.log 2>&1
done
echo PICS_DONE >> $OUTDIR/pics.log
