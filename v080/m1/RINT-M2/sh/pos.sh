#!/bin/bash
# RINT-M2 positions: pos.sh <ID> -> race scene arguments (contract §4.9.2 + the assembly's extra places)
F="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KH="--stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 $F"
case "$1" in
S0) echo "--stage=kiel_hamburg --from=kiel --start-km=0 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup" ;;
S1) echo "$KH --start-km=2 --hour=12 --weather=normal --start-speed=120" ;;
S2) echo "$KH --start-km=13.6 --hour=12 --weather=normal --start-speed=120" ;;
S3) echo "$KH --start-km=60 --hour=12 --weather=normal --start-speed=120" ;;
S4) echo "$KH --start-km=80 --hour=12 --weather=normal --start-speed=50" ;;
S5) echo "$KH --start-km=94 --hour=12 --weather=normal --start-speed=120" ;;
T1) echo "--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 $F --start-speed=120" ;;
T2) echo "--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $F --start-speed=120" ;;
T3) echo "--stage=saragossa_pau --from=saragossa --start-km=172.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $F --start-speed=80" ;;
T4) echo "--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $F --start-speed=80" ;;
N1) echo "--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $F --start-speed=120" ;;
N2) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --weather=rain --vehicle=gran_turismo --seed=14 $F --start-speed=120" ;;
N2N) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=22 --weather=rain --vehicle=gran_turismo --seed=14 $F --start-speed=120" ;;
C1) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $F --start-speed=100" ;;
U1) echo "--stage=bern_mailand --from=bern --start-km=186 --hour=12 --weather=normal --vehicle=limousine --seed=16 $F --start-speed=100" ;;
U1N) echo "--stage=bern_mailand --from=bern --start-km=186 --hour=22 --weather=normal --vehicle=limousine --seed=16 $F --start-speed=100" ;;
DEV) echo "--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --weather=normal --vehicle=limousine --seed=17 $F --start-speed=120" ;;
DEVR) echo "--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --weather=rain --vehicle=limousine --seed=17 $F --start-speed=120" ;;
KBT) echo "$KH --start-km=77.6 --hour=12 --weather=normal --start-speed=80" ;;
KBN) echo "$KH --start-km=77.6 --hour=22 --weather=normal --start-speed=80" ;;
KBNR) echo "$KH --start-km=77.6 --hour=22 --weather=rain --start-speed=80" ;;
TS15) echo "$KH --start-km=14.3 --hour=12 --weather=normal --start-speed=100" ;;
TS15N) echo "$KH --start-km=14.3 --hour=21 --weather=normal --start-speed=100" ;;
KHO) echo "$KH --start-km=81.2 --hour=12 --weather=normal --start-speed=50" ;;
KHH) echo "$KH --start-km=88.2 --hour=12 --weather=normal --start-speed=50" ;;
KIEL) echo "$KH --start-km=0.6 --hour=12 --weather=normal --start-speed=50" ;;
MUC) echo "--stage=muenchen_nuernberg --from=nuernberg --start-km=161.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=50" ;;
NUE) echo "--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.7 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=50" ;;
AMS) echo "--stage=bremen_amsterdam --from=bremen --start-km=361.0 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=50" ;;
KHZ) echo "$KH --start-km=94.4 --hour=12 --weather=normal --start-speed=80" ;;
KHH195) echo "$KH --start-km=88.2 --hour=19.5 --weather=normal --start-speed=50" ;;
KHH22) echo "$KH --start-km=88.2 --hour=22 --weather=normal --start-speed=50" ;;
KIEL195) echo "$KH --start-km=0.6 --hour=19.5 --weather=normal --start-speed=50" ;;
KIEL22) echo "$KH --start-km=0.6 --hour=22 --weather=normal --start-speed=50" ;;
VAL) echo "--stage=prag_nuernberg --from=prag --start-km=87.55 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=80" ;;
VALN) echo "--stage=prag_nuernberg --from=prag --start-km=87.55 --hour=22 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=80" ;;
STB) echo "--stage=dresden_leipzig --from=leipzig --start-km=111.0 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=50" ;;
STBN) echo "--stage=dresden_leipzig --from=leipzig --start-km=111.0 --hour=22 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=50" ;;
GRZ) echo "--stage=bremen_amsterdam --from=bremen --start-km=139.55 --hour=12 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=100" ;;
GRZN) echo "--stage=bremen_amsterdam --from=bremen --start-km=139.55 --hour=22 --weather=normal --vehicle=limousine --seed=11 $F --start-speed=100" ;;
TSB) echo "$KH --start-km=14.3 --hour=12 --weather=normal --start-speed=60" ;;
TSBN) echo "$KH --start-km=14.3 --hour=21 --weather=normal --start-speed=60" ;;
*) echo "unknown position $1" >&2; exit 2 ;;
esac
