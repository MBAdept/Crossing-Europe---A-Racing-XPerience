#!/usr/bin/env bash
# AS4R scratch: the final race A/B pictures, one run after the other.   batch_ab.sh <tag>
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
T=${1:-f}
L=$S/logs/batch_ab_$T.log
: > "$L"
run() {
	local name=$1; shift
	"$S/ab.sh" "${T}_$name" "$@" >> "$L" 2>&1
}
run pylon_mittag high --stage=kiel_hamburg --from=kiel --start-km=77.4 --start-speed=50 --shot-times=1,2.5,4,6 --hour=12
run dorf_nacht high --stage=paris_tours --from=paris --start-km=129.0 --hour=23 --start-speed=100 --shot-times=1,6,9
run dorf_mittag high --stage=paris_tours --from=paris --start-km=129.0 --hour=12 --start-speed=100 --shot-times=1,6,9
run fabrik_nacht high --stage=bremen_dortmund --from=dortmund --start-km=1.9 --hour=23 --start-speed=100 --shot-times=1,3
run turm_nachmittag high --stage=dresden_leipzig --from=dresden --start-km=111.0 --hour=15 --start-speed=100 --shot-times=2,5
run elbe_deck deck --stage=kiel_hamburg --from=kiel --start-km=82.9 --start-speed=50 --shot-times=1,5 --hour=19.5
echo BATCH_DONE >> "$L"
