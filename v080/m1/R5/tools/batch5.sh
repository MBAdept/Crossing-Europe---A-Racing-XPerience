#!/usr/bin/env bash
# R5 batch 5 (successor 4): the rest of batch 4 (aviation light at 22:00, U1 at night, Steam Deck pictures), the canal
# and causeway types, then the two 30-s clips (60 fps fixed).   batch5.sh [name…]
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WTN=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2
AB=$R5/tools/ab.sh
OUT=$R5/shots/new3
mkdir -p $OUT
export AB_TIMEOUT=1500
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KBB="--stage=kiel_hamburg --from=kiel --start-km=73.2 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,2.4,2.8,3.2,4.4"
U1N="--stage=bern_mailand --from=bern --start-km=183.6 --hour=22 --seed=16 --start-speed=120 --shot-times=2,3.5"
KBN="--stage=kiel_hamburg --from=kiel --start-km=76.4 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,3.5,5"
U1I="--stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 --start-speed=120 --shot-times=2,4"
KBR="--stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
CSW="--stage=mailand_venedig --from=mailand --start-km=267.9 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
CNL="--stage=bremen_amsterdam --from=bremen --start-km=361.3 --hour=12 --seed=11 --start-speed=60 --shot-times=1.5,3"
if want kb_beacon; then WT=$WTN bash $AB $OUT kb_beacon high $KBB $COMMON; fi
if want u1_nacht; then WT=$WTN bash $AB $OUT u1_nacht high $U1N $COMMON; fi
if want damm; then WT=$WTN bash $AB $OUT damm_venedig high $CSW $COMMON; fi
if want gracht; then WT=$WTN bash $AB $OUT gracht_amsterdam high $CNL $COMMON; fi
if want kb_nacht_deck; then SCREEN=1280x800 WT=$WTN bash $AB $OUT kb_nacht_deck deck $KBN $COMMON; fi
if want u1_innen_deck; then SCREEN=1280x800 WT=$WTN bash $AB $OUT u1_innen_deck deck $U1I $COMMON; fi
if want kb_rampe_deck; then SCREEN=1280x800 WT=$WTN bash $AB $OUT kb_rampe_deck deck $KBR $COMMON; fi
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
mkdir -p $R5/clips $R5/tmp
export MESA_SHADER_CACHE_DIR=$R5/mesa TMPDIR=$R5/tmp
if want clip_u1; then
	(cd $WTN && GFX_ARGS="--gfx-preset=high" nice -n $NICE tools/ab_clip.sh $R5/clips/u1_gotthard.mp4 --stage=bern_mailand --from=bern \
		--start-km=184.4 --hour=12 --seed=16 --weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never \
		--traffic-warmup --no-countdown --start-speed=120) > $R5/clips/u1.log 2>&1
	echo "clip u1: $?"
fi
if want clip_kb; then
	(cd $WTN && GFX_ARGS="--gfx-preset=high" nice -n $NICE tools/ab_clip.sh $R5/clips/koehlbrand.mp4 --stage=kiel_hamburg --from=kiel \
		--start-km=77.2 --hour=12 --seed=11 --weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never \
		--traffic-warmup --no-countdown --start-speed=80 --fuel=1) > $R5/clips/kb.log 2>&1
	echo "clip kb: $?"
fi
echo BATCH5_DONE
