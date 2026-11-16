# QA-M2-BILD: shared job function (sourced). job <tree> <mode> <name> <screen> <gfx> <args...>
# Skips a job whose pictures exist (two for --shot-times=1,4.5). Needs S, SH, Q, log().
job() {
	local tree=$1 mode=$2 name=$3 screen=$4 gfx=$5
	shift 5
	local d=$S/shots/${name%%_*}
	mkdir -p "$d"
	local want=1
	case "$*" in *--shot-times=1,4.5*) want=2 ;; esac
	local have
	have=$(ls "$d/${name}"_[0-9][0-9].png 2> /dev/null | wc -l)
	if [ "$have" -ge "$want" ]; then log "skip $name"; return; fi
	log "start $name"
	SCREEN=$screen GFX="$gfx" $SH/shot.sh "$tree" "$mode" "$d/$name" "$@" >> $Q 2>&1
}
