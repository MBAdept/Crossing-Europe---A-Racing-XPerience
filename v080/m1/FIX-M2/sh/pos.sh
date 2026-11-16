#!/bin/bash
# reference positions (same args as tools/ab_sheet.sh)
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120"
case "$1" in
S0) echo "--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --start-km=0" ;;
S1) echo "$SLICE --start-km=2" ;;
S2) echo "$SLICE --start-km=13.6" ;;
S3) echo "$SLICE --start-km=60" ;;
S4) echo "$SLICE --start-km=80 --start-speed=50" ;;
S5) echo "$SLICE --start-km=94" ;;
T1) echo "--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120" ;;
T2) echo "--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120" ;;
T3) echo "--stage=saragossa_pau --from=saragossa --start-km=172.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80" ;;
T4) echo "--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80" ;;
N1) echo "--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $FLY --start-speed=100" ;;
N2) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --weather=rain --vehicle=gran_turismo --seed=14 $FLY --start-speed=110" ;;
C1) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $FLY --start-speed=90" ;;
U1) echo "--stage=bern_mailand --from=bern --start-km=186 --hour=12 --weather=normal --vehicle=limousine --seed=16 $FLY --start-speed=100" ;;
DEV) echo "--stage=dev_testetappe --start-km=48 --hour=21 --weather=normal --vehicle=limousine --seed=17 $FLY --start-speed=100" ;;
KBN) echo "--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6 --hour=22" ;;
KBT) echo "--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6 --hour=12" ;;
*) echo "" ;;
esac
