#!/usr/bin/env bash
# QA-WASSER queue 1: pictures from the exported Linux build (Arcade | Modern), one run at a time.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
T=$S/tools
O=$S/shots
cd "$S" || exit 1
KB="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown"
HH="--stage=kiel_hamburg --from=hamburg --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown"
only=${1:-}
step() {   # step <name> <screen> <label> <args…>
	local name=$1
	shift
	if [ -n "$only" ] && [[ ",$only," != *",$name,"* ]]; then return; fi
	echo "== $name $(date +%H:%M:%S)"
	"$T/ab.sh" linux "$O/$name" "$@"
}
# shellcheck disable=SC2086
step kb_tag_hoch_a 1280x720 "Köhlbrandbrücke Tag, Hoch, ab km 77,4 mit 80 km/h, Verkehr" $KB --hour=12 --gfx-preset=high --start-km=77.4 --start-speed=80 --traffic-warmup --shot-times=0.3,1.5,3,4.5,6,7.5
step kb_tag_hoch_b 1280x720 "Köhlbrandbrücke Tag, Hoch, ab km 79,0 mit 80 km/h, Verkehr" $KB --hour=12 --gfx-preset=high --start-km=79.0 --start-speed=80 --traffic-warmup --shot-times=0.3,2,4,6
step kb_nacht_hoch 1280x720 "Köhlbrandbrücke 22 Uhr, Hoch, ab km 77,6 mit 80 km/h, Verkehr" $KB --hour=22 --gfx-preset=high --start-km=77.6 --start-speed=80 --traffic-warmup --shot-times=0.3,2,4,6
step kb_tag_deck 1280x800 "Köhlbrandbrücke Tag, Steam-Deck-Stufe 1280x800, ab km 77,6" $KB --hour=12 --gfx-preset=deck --start-km=77.6 --start-speed=80 --no-traffic --shot-times=0.3,2,4,6
step kb_nacht_deck 1280x800 "Köhlbrandbrücke 22 Uhr, Steam-Deck-Stufe 1280x800, ab km 77,6" $KB --hour=22 --gfx-preset=deck --start-km=77.6 --start-speed=80 --no-traffic --shot-times=0.3,2,4,6
step kb_senk 1280x720 "Fernboden sinkt (Brücke kommt ins Fenster, km 67,1), Hoch, ab km 66,8 mit 120 km/h" $KB --hour=12 --gfx-preset=high --start-km=66.8 --start-speed=120 --no-traffic --shot-times=0.2,0.4,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.6,1.8,2.0
step kb_anfahrt 1280x720 "Anfahrt Köhlbrandbrücke ab km 76,5 mit 60 km/h, Hoch" $KB --hour=12 --gfx-preset=high --start-km=76.5 --start-speed=60 --no-traffic --shot-times=0.25,0.5,0.75,1,1.25,1.5,1.75,2,2.5,3
step elb 1280x720 "Elbbrücken ab km 84,3, Hoch" $KB --hour=12 --gfx-preset=high --start-km=84.3 --start-speed=60 --no-traffic --shot-times=0.3,2,3.5
step holtenau_bruecke 1280x720 "Holtenauer Hochbrücke (Kiel–Hamburg ab Hamburg) ab km 84,8, Hoch" $HH --hour=12 --gfx-preset=high --start-km=84.8 --start-speed=80 --no-traffic --shot-times=0.3,2,4,6
step holtenau_anfahrt 1280x720 "Anfahrt Holtenau (Scheibe 12 m tiefer, Brücke noch nicht in Sicht) ab km 75,5, Hoch" $HH --hour=12 --gfx-preset=high --start-km=75.5 --start-speed=120 --no-traffic --shot-times=0.3,1.5
step ada 1280x720 "Ada-Brücke Belgrad (Slavonski Brod–Belgrad) ab km 198,6, Hoch" --stage=slavonski_brod_belgrad --from=slavonski_brod --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --hour=12 --gfx-preset=high --start-km=198.6 --start-speed=80 --no-traffic --shot-times=0.3,2,4
step berg_t4 1280x720 "Pyrenäen (Saragossa–Pau) km 198,8 (T4), Hoch, enge Kurven" --stage=saragossa_pau --from=saragossa --weather=normal --vehicle=kompakt --seed=4 --autopilot --autopilot-refuel=never --no-countdown --hour=11 --gfx-preset=high --start-km=198.8 --start-speed=80 --traffic-warmup --shot-times=0.3,2,4
echo "== fertig $(date +%H:%M:%S)"
