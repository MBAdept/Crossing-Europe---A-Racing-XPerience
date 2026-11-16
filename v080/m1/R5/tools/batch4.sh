#!/usr/bin/env bash
# R5 batch 4 (successor 3): pylon top with the aviation light at 22:00, U1 at night, Steam Deck pictures (1280 x 800,
# preset deck) – Arcade + Modern R5 of the worktree each.   batch4.sh [name…]
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
if want kb_beacon; then WT=$WTN bash $AB $OUT kb_beacon high $KBB $COMMON; fi
if want u1_nacht; then WT=$WTN bash $AB $OUT u1_nacht high $U1N $COMMON; fi
export SCREEN=1280x800
if want kb_nacht_deck; then WT=$WTN bash $AB $OUT kb_nacht_deck deck $KBN $COMMON; fi
if want u1_innen_deck; then WT=$WTN bash $AB $OUT u1_innen_deck deck $U1I $COMMON; fi
if want kb_rampe_deck; then WT=$WTN bash $AB $OUT kb_rampe_deck deck $KBR $COMMON; fi
echo BATCH4_DONE
