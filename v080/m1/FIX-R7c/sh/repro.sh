#!/bin/bash
# FIX-R7c: reproduce the QA pictures of QR7c-01 (Hamburg Deck) and QR7c-06 (countdown Nürnberg – Fulda, Deck) from
# this tree at bd1803b (tag r7c) – they must equal QA's r7c pictures (determinism) before anything is changed.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
TAG=${1:-r7c}
SCREEN=1280x800 TREE=${TREE:-$WT} "$S/sh/shot.sh" hh_deck_h12 "$TAG" deck --stage=kiel_hamburg --from=kiel --start-km=88.2 --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=2,4
SCREEN=1280x800 TREE=${TREE:-$WT} "$S/sh/shot.sh" start_nu_deck_h12 "$TAG" deck --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12 \
	--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5
echo "REPRO DONE $TAG" >> "$S/logs/shot.out"
