#!/usr/bin/env bash
# KRITIK-MISCHUNG: effect of the mischung.json knobs, measured on a 16-bar sketch of "Linke Spur" (count-in, A1, B1),
# rendered in the scratch COPY (its mischung.json is changed per variant and restored at the end). nice 19, sequential.
set -u
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-MISCHUNG
M=$K/copy/tools/audio/music/mischung.json
cp "$M" "$K/knobs_mischung_orig.json"
mkdir -p "$K/knobs"
run() {
	local name=$1; shift
	python3 - "$M" "$@" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for k in ("sub_db", "bass_db", "high_shelf_db", "race_music_db", "menu_music_db", "ui_db"):
    d[k] = 0.0
d["high_shelf_hz"] = 6000.0
for kv in sys.argv[2:]:
    k, v = kv.split("=")
    d[k] = float(v)
json.dump(d, open(p, "w"), ensure_ascii=False, indent="\t")
EOF
	echo "== $name $* $(date +%T)"
	local t0=$(date +%s)
	nice -n 19 python3 "$K/copy/tools/audio/music/linke_spur.py" --sketch 16 --wav "$K/knobs/$name" > "$K/logs/knob_$name.log" 2>&1
	echo "   exit $? nach $(( $(date +%s) - t0 )) s"
}
for spec in "$@"; do
	IFS=: read -r name kvs <<< "$spec"
	run "$name" ${kvs//,/ }
done
cp "$K/knobs_mischung_orig.json" "$M"
echo "== fertig (mischung.json der Kopie wiederhergestellt)"
