#!/usr/bin/env bash
# KRITIK-MISCHUNG heavy chain 2: one full render_all.py into a scratch folder (timing + all code paths with non-zero
# mix values), then the QC tool on that folder. mischung.json of the COPY is changed and restored. nice 19.
set -u
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-MISCHUNG
M=$K/copy/tools/audio/music/mischung.json
OUT=$K/render_cand
# (Ordner bleibt: Fortsetzung)
mkdir -p "$OUT"
cp "$M" "$K/chain3_mischung_orig.json"
python3 - "$M" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.update({"sub_db": -3.0, "bass_db": 0.0, "high_shelf_db": -2.0, "high_shelf_hz": 5000.0, "race_music_db": 1.0,
          "menu_music_db": 0.0, "ui_db": 0.0})
json.dump(d, open(p, "w"), ensure_ascii=False, indent="\t")
EOF
echo "== render_all $(date +%T)"
t0=$(date +%s)
nice -n 19 python3 "$K/copy/tools/audio/music/render_all.py" --only rueckenwind,zwischenspiel,ui_klaenge --out "$OUT" > "$K/logs/render_all2.log" 2>&1
rc=$?
t1=$(date +%s)
cp "$K/chain3_mischung_orig.json" "$M"
echo "   exit $rc nach $(( t1 - t0 )) s ($(date +%T)); mischung.json wiederhergestellt"
grep -E "^== |FERTIG|FEHLER" "$K/logs/render_all2.log"
echo "== audio_qc $(date +%T)"
nice -n 19 python3 "$K/copy/tools/audio/qc/audio_qc.py" --root "$OUT/assets/audio/modern" --folders music,ui --no-import > "$K/logs/qc_cand.log" 2>&1
echo "   exit $? $(date +%T)"
tail -5 "$K/logs/qc_cand.log"
echo "== fertig $(date +%T)"
nice -n 19 python3 "$K/ana/cand_compare.py" "$K" > "$K/logs/cand_compare.log" 2>&1; echo "== Vergleich fertig $(date +%T)"
