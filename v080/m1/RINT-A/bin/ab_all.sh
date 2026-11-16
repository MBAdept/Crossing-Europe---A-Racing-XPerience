#!/bin/bash
# The reference positions of the brief: S1–S5, T1, T4, C1 (19:30), N1 (night, snow) – one after the other.
#   ab_all.sh <out_dir> [names...]
B=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin
out="$1"; shift
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(S1 S2 S3 S4 S5 T1 T2 T4 C1 N1)
for n in "${names[@]}"; do
	case "$n" in
	S1|S2|S3|S4|S5) bash $B/ab.sh "$out" "$n" "$n" ;;
	T1) bash $B/ab.sh "$out" T1 --stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --vehicle=limousine --seed=12 --autopilot --traffic-warmup --no-countdown --start-speed=120 ;;
	T2) bash $B/ab.sh "$out" T2 --stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --vehicle=limousine --seed=12 --autopilot --traffic-warmup --no-countdown --start-speed=120 ;;
	T4) bash $B/ab.sh "$out" T4 --stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=14 --vehicle=limousine --seed=12 --autopilot --traffic-warmup --no-countdown --start-speed=80 ;;
	C1) bash $B/ab.sh "$out" C1 --stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --vehicle=limousine --seed=12 --autopilot --traffic-warmup --no-countdown --start-speed=100 ;;
	N1) bash $B/ab.sh "$out" N1 --stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 --autopilot --traffic-warmup --no-countdown --start-speed=110 ;;
	esac
done
