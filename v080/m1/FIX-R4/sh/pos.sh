#!/bin/bash
# Position arguments of R4's pictures: pos.sh <ID> -> prints the race scene arguments
case "$1" in
N1) echo "--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
N2) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --weather=rain --vehicle=gran_turismo --seed=14 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
N2N) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=22 --weather=rain --vehicle=gran_turismo --seed=14 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
C1) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100" ;;
DEV) echo "--stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --weather=normal --vehicle=limousine --seed=17 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
S1DAWN) echo "--stage=kiel_hamburg --from=kiel --start-km=2 --hour=6.6 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
S1DUSK) echo "--stage=kiel_hamburg --from=kiel --start-km=2 --hour=19.2 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
S1OVC) echo "--stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=rain --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
S1) echo "--stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
S1NIGHT) echo "--stage=kiel_hamburg --from=kiel --start-km=2 --hour=22 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120" ;;
TEXIT) echo "--stage=dev_testetappe --from=dev_start --start-km=52.8 --hour=12 --weather=normal --vehicle=limousine --seed=17 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100" ;;
C1RN) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=21.5 --weather=rain --vehicle=sportwagen --seed=15 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100" ;;
KBN) echo "--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6 --hour=22" ;;
KBNS) echo "--stage=kiel_hamburg --from=kiel --weather=snow --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6 --hour=13" ;;
*) echo "unknown position $1" >&2; exit 2 ;;
esac
