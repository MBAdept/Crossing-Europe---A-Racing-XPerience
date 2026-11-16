#!/usr/bin/env bash
# R5 batch 3: the night row of the Köhlbrandbrücke (M2ZS1's measurement: 22:00, from km 77.6 at 80 km/h with traffic,
# preset high and deck) for the new code and the base, then the two 30-s clips (60 fps fixed).
#   batch3.sh [name…]
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WTN=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2
AB=$R5/tools/ab.sh
export AB_TIMEOUT=1500
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
ROW="--stage=kiel_hamburg --from=kiel --hour=22 --vehicle=limousine --seed=11 --autopilot --no-countdown --traffic-warmup --start-km=77.6 --start-speed=80"
if want row_new; then WT=$WTN bash $AB $R5/shots/row new high $ROW --shot-times=0.3,2,4,5.4,6,9.5; fi
if want row_base; then WT=$R5/base bash $AB $R5/shots/row base high $ROW --shot-times=0.3,2,4,5.4,6,9.5; fi
if want row_new_deck; then SCREEN=1280x800 WT=$WTN bash $AB $R5/shots/row new_deck deck $ROW --shot-times=0.3,2,4; fi
if want row_base_deck; then SCREEN=1280x800 WT=$R5/base bash $AB $R5/shots/row base_deck deck $ROW --shot-times=0.3,2,4; fi
if want b1_new; then
	bash $R5/tools/mo.sh $R5/shots/new2/b1_koeln --stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 \
		--start-speed=80 --shot-times=2,4 --weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown
fi
if want u1_innen_deck; then
	SCREEN=1280x800 WT=$WTN bash $AB $R5/shots/deck u1_innen deck --stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 \
		--start-speed=120 --shot-times=2,4 --weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown
fi
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
echo BATCH3_DONE
