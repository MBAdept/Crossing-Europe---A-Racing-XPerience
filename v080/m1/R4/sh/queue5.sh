#!/bin/bash
# queue5.sh [outdir] – picture batch v5 (high) and deck, then the weather table; one job after the other
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
O=${1:-$R4/shots/v5}
mkdir -p "$O"
log() { echo "$*" >> "$O/queue.log"; }
pair() {   # pair <name> <POS> <preset> <times> [screen]
	log "== $1 $(date -u +%T)"
	SCREEN=${5:-1280x720} "$R4/sh/ab.sh" "$O" "$1" "$2" "$3" --shot-times="$4" > "$O/$1.out" 2>&1
	log "   exit=$? $(date -u +%T)"
	grep -hE 'SCRIPT ERROR|SHADER ERROR|Shader compilation' "$O/${1}_modern.log" 2>/dev/null | head -5 >> "$O/queue.log"
}
for item in ${QUEUE:-TEXIT C1 DEV S1DAWN S1DUSK S1OVC C1RN N2 N1_deck N2N_deck tabelle}; do
	case "$item" in
	TEXIT) pair TEXIT TEXIT high 1.0,2.4,3.8 ;;
	N1_deck) pair N1_deck N1 deck 2 1280x800 ;;
	N2N_deck) pair N2N_deck N2N deck 2 1280x800 ;;
	tabelle)
		log "== tabelle $(date -u +%T)"
		"$R4/sh/rc.sh" check_weather --only=tabelle >> "$O/queue.log" 2>&1 ;;
	*) pair "$item" "$item" high 2 ;;
	esac
done
log "QUEUE_DONE $(date -u +%T)"
