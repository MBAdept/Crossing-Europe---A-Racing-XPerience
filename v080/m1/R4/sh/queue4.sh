#!/bin/bash
# queue4.sh – after the render-check pair: Köhlbrand pylon at night, weather table, picture batch v4 (high) and deck
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
until grep -q RCPAIR_DONE "$R4/rc/pair.out" 2>/dev/null; do sleep 20; done
O=$R4/shots/v4
mkdir -p "$O"
log() { echo "$*" >> "$O/queue.log"; }
pair() {   # pair <name> <POS> <preset> <times> [screen]
	log "== $1 $(date -u +%T)"
	SCREEN=${5:-1280x720} "$R4/sh/ab.sh" "$O" "$1" "$2" "$3" --shot-times="$4" > "$O/$1.out" 2>&1
	log "   exit=$? $(date -u +%T)"
	grep -hE 'SCRIPT ERROR|SHADER ERROR|Shader compilation' "$O/${1}_modern.log" 2>/dev/null | head -5 >> "$O/queue.log"
}
pair KBN KBN high 2
log "== tabelle $(date -u +%T)"
"$R4/sh/rc.sh" check_weather --only=tabelle >> "$O/queue.log" 2>&1
pair TEXIT TEXIT high 1.0,2.4,3.8
pair C1 C1 high 2
pair DEV DEV high 2
pair S1DAWN S1DAWN high 2
pair S1DUSK S1DUSK high 2
pair S1OVC S1OVC high 2
pair C1RN C1RN high 2
pair N1_deck N1 deck 2 1280x800
pair N2N_deck N2N deck 2 1280x800
log "QUEUE4_DONE $(date -u +%T)"
