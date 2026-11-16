#!/usr/bin/env bash
# R5: pictures of the BASE (6e48405, exported to m1/R5/base) at the places of the brief (U1 already done)
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
AB=$R5/tools/ab.sh
export WT=$R5/base
OUT=${1:-$R5/shots/base}
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
bash $AB $OUT kb_rampe high --stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=12 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT kb_ende high --stage=kiel_hamburg --from=kiel --start-km=79.6 --hour=12 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT holtenau high --stage=rostock_kiel --from=rostock --start-km=199.6 --hour=12 --seed=11 $COMMON --start-speed=100 --shot-times=2,4
bash $AB $OUT b1_koeln high --stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT elbbruecken high --stage=kiel_hamburg --from=kiel --start-km=83.5 --hour=12 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT stein_wuerzburg high --stage=kassel_wuerzburg --from=kassel --start-km=205.5 --hour=12 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT kb_nacht high --stage=kiel_hamburg --from=kiel --start-km=77.2 --hour=22 --seed=11 $COMMON --start-speed=80 --shot-times=2,4
bash $AB $OUT dev high --stage=dev_testetappe --from=dev_start --start-km=48 --hour=21 --seed=11 $COMMON --start-speed=120 --shot-times=2,4,6
bash $AB $OUT somport high --stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 $COMMON --start-speed=100 --shot-times=2,4,6
echo BASELINE_DONE
