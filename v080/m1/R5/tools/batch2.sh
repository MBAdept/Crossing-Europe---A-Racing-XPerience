#!/usr/bin/env bash
# R5 batch 2: the remaining base pictures (Arcade + Modern of the base copy) and the new code's Modern pictures.
#   batch2.sh [name…]   (no names: all, in this order)
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
AB=$R5/tools/ab.sh
MO=$R5/tools/mo.sh
BASE_OUT=$R5/shots/base
NEW_OUT=$R5/shots/new2
export AB_TIMEOUT=1500
export MO_TIMEOUT=1500
WANT=" $* "
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
base() {   # base <name> <preset> <args…>: Arcade + Modern of the base copy
	local name=$1 preset=$2
	shift 2
	want "base_$name" || return 0
	WT=$R5/base bash $AB $BASE_OUT "$name" "$preset" "$@" $COMMON
}
new() {    # new <name> <args…>: Modern of the worktree
	local name=$1
	shift
	want "new_$name" || return 0
	bash $MO "$NEW_OUT/$name" "$@" $COMMON
}
U1A="--stage=bern_mailand --from=bern --start-km=183.6 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5"
U1I="--stage=bern_mailand --from=bern --start-km=188 --hour=12 --seed=16 --start-speed=120 --shot-times=2,4"
U1X="--stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5"
SOM="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 --start-speed=100 --shot-times=2,4,6"
B1="--stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
ELB="--stage=kiel_hamburg --from=kiel --start-km=83.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
STE="--stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBN="--stage=kiel_hamburg --from=kiel --start-km=76.4 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,3.5,5"
DEV="--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 --start-speed=120 --shot-times=2,4,6"
KBR="--stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBE="--stage=kiel_hamburg --from=kiel --start-km=79.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
HOL="--stage=rostock_kiel --from=rostock --start-km=199.6 --hour=12 --seed=11 --start-speed=100 --shot-times=2,4"
new u1_ausfahrt $U1X
new somport $SOM
new b1_koeln $B1
base elbbruecken high $ELB
new elbbruecken $ELB
base stein_wuerzburg high $STE
new stein_wuerzburg $STE
base kb_nacht2 high $KBN
new kb_nacht2 $KBN
base dev high $DEV
new dev $DEV
base somport high $SOM
new kb_rampe $KBR
new u1_anfahrt $U1A
new holtenau $HOL
new kb_ende $KBE
new u1_innen $U1I
# Steam Deck (1280 x 800, preset deck)
export SCREEN=1280x800
base kb_nacht2_deck deck $KBN
PRESET=deck new kb_nacht2_deck $KBN
base u1_innen_deck deck $U1I
PRESET=deck new u1_innen_deck $U1I
echo BATCH2_DONE
