#!/usr/bin/env bash
# KRITIK-4 batch 5: approach clips at 120 km/h (frames -> mp4). Waits for batch 4. Progress in $K/logs/batch5.log
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4
L=$K/logs/batch5.log
: > "$L"
until grep -q BATCH4_DONE $K/logs/batch4.log 2>/dev/null; do sleep 10; done
mkdir -p $K/shots/clips $K/logs/clips
$K/k4.sh clips/pylon --mode=approach --look=race --hour=12 --preset=medium --from=320 --to=10 --kmh=120 --fps=30 "--items=props/bridge_pylon@7.5" >> "$L" 2>&1
$K/k4.sh clips/portal --mode=approach --look=race --hour=12 --preset=medium --from=400 --to=4 --kmh=120 --fps=30 "--items=props/bridge_truss_arch@0" >> "$L" 2>&1
$K/k4.sh clips/muehle --mode=approach --look=race --hour=12 --preset=medium --from=500 --to=90 --kmh=120 --fps=30 "--items=props/windmill@60" >> "$L" 2>&1
for c in pylon portal muehle; do
	nice -n 19 ffmpeg -y -loglevel error -framerate 30 -i "$K/shots/clips/${c}_%03d.jpg" -c:v libx264 -pix_fmt yuv420p -crf 23 "$K/shots/clip_${c}.mp4" >> "$L" 2>&1
	echo "mp4 $c $?" >> "$L"
done
echo BATCH5_DONE >> "$L"
