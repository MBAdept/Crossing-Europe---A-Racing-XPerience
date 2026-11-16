#!/usr/bin/env bash
# Review MP3s for AU-A from the captures of tools/audio/modern/capture_mix.gd (scratch only, never into the repo).
set -euo pipefail
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-A
M="$W/mix"
mkdir -p "$OUT"
FF="nice -n 10 ffmpeg -hide_banner -loglevel error -y"
$FF -i "$M/arcade_gt.wav" -codec:a libmp3lame -b:a 192k "$OUT/fahrt_arcade.mp3"
$FF -i "$M/modern_gt.wav" -codec:a libmp3lame -b:a 192k "$OUT/fahrt_modern_platzhalter.mp3"
$FF -i "$M/modern_race_final.wav" -codec:a libmp3lame -b:a 192k "$OUT/rennen_modern_platzhaltermusik_ducking.mp3"
# menu music: 15 s Arcade, 0.6 s pause, 15 s Modern (the same stretch of the title theme)
$FF -t 15 -i "$M/arcade_menu.wav" -f lavfi -t 0.6 -i anullsrc=r=44100:cl=stereo -t 15 -i "$M/modern_menu.wav" \
	-filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" -map "[a]" -codec:a libmp3lame -b:a 192k "$OUT/menuemusik_arcade_dann_modern.mp3"
cp "$M/pegelplan_messung.json" "$OUT/pegelplan_messung.json"
cp "$M/music_only_final.json" "$OUT/musik_im_rennen_messung.json"
cp "$M/modern_race_final_lufs.json" "$OUT/rennen_mit_musik_messung.json"
cp "$W/qc_report.json" "$OUT/qc_bericht_platzhalter.json"
cp "$W/qc_bad_report.json" "$OUT/qc_bericht_absichtlich_kaputt.json"
ls -la "$OUT"
