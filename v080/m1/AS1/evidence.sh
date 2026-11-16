#!/usr/bin/env bash
# renders the evidence pictures of AS1 into $S/ev (sequential)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
mkdir -p $S/ev
shot() {
	echo "== $1"
	$S/cs.sh "ev/$1" "${@:2}" 2>&1 | grep -i "error\|fehl" | head -5
}
want() {
	# with arguments: only the named pictures (prefix match)
	[ -z "${ONLY:-}" ] && return 0
	case "$1" in ${ONLY}*) return 0 ;; esac
	return 1
}
run() {
	want "$1" && shot "$@"
	return 0
}
run 01_tag_spieler.png --only="player/*"
run 02_tag_verkehr.png --only="traffic/*"
run 03_nacht_spieler.png --only="player/*" --night
run 04_nacht_verkehr.png --only="traffic/*" --night
run 05_lampenkanaele.png --channels
run 06_showroom_ab.png --only="player/*" --showroom
run 07_verfolger_spieler.png --only="player/*" --chase=9,30
run 08_verfolger_verkehr.png --only="traffic/*" --chase=8,30,80
run 09_verfolger_lkw.png --only="traffic/truck" --chase=20,60,150
run 10_verfolger_nacht.png --only="traffic/*" --chase=30 --night
run 11_review_limousine.png --only="player/limousine" --review --cols=4
run 12_review_kompakt.png --only="player/kompakt" --review --cols=4
run 13_stufen_sedan.png --only="traffic/sedan" --review --views=0,3,1 --lods=lod0,lod1,lod2 --cols=3
run 14_stufen_hatch.png --only="traffic/hatch" --review --views=0,3,1 --lods=lod0,lod1,lod2 --cols=3
run 15_stufen_wagon.png --only="traffic/wagon" --review --views=0,3,1 --lods=lod0,lod1,lod2 --cols=3
run 16_review_lkw.png --only="traffic/truck" --review --views=0,1,2,3,4,5,8,9 --cols=4
run 17_stufen_lkw.png --only="traffic/truck" --review --views=0,1 --lods=lod0,lod1,lod2 --cols=2
run 18_review_sedan.png --only="traffic/sedan" --review --views=0,1,2,3,4,5,6,12,13,8,9,10 --cols=4
ls -la $S/ev
