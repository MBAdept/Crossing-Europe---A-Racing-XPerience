#!/usr/bin/env bash
# AS5aR1: race A/B pictures into the delivery; where KRITIK-5a1 shot the same position and time, before above after
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR1
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-5a1
FONT=DejaVu-Sans
lab() { convert "$1" -gravity north -background '#1a1c20' -fill white -font $FONT -pointsize 26 -splice 0x40 -annotate +0+6 "$2" "$3"; }
T=$S/tmp_ab; rm -rf $T; mkdir -p $T
pair() {   # pair <kritik jpg> <my ab jpg> <out name> <title>
	if [ -f "$2" ]; then
		if [ -n "$1" ] && [ -f "$K/$1" ]; then
			lab "$K/$1" "vorher (Kritik, Stand 63544b6): $4" $T/a.jpg
			lab "$2" "nachher (AS5aR1): $4" $T/b.jpg
			convert $T/a.jpg $T/b.jpg -append -resize 2000x -quality 86 "$D/$3"
		else
			lab "$2" "AS5aR1: $4" $T/b.jpg
			convert $T/b.jpg -resize 2000x -quality 86 "$D/$3"
		fi
	fi
}
pair 02_rennen_hamburg_innenstadt_mittag.jpg $S/ab/hh_high_h12_ab_01.jpg rennen_hamburg_innenstadt_mittag.jpg "Hamburg, Kiel–Hamburg km 88,2, Hoch, 12 Uhr, +4 s"
pair 03_rennen_nuernberg_altstadt_mittag.jpg $S/ab/nu_high_h12_ab_01.jpg rennen_nuernberg_altstadt_mittag.jpg "Nürnberg, Würzburg–Nürnberg km 102,7, Hoch, 12 Uhr, +4 s"
pair 04_rennen_hannover_mittag.jpg $S/ab/hn_high_h12_ab_01.jpg rennen_hannover_mittag.jpg "Hannover, Hamburg–Hannover km 143,9, Hoch, 12 Uhr, +4 s"
pair 06_rennen_hamburg_innenstadt_nacht.jpg $S/ab/hh_high_h22_ab_01.jpg rennen_hamburg_innenstadt_nacht.jpg "Hamburg km 88,2, Hoch, 22 Uhr, +4 s"
pair 07_rennen_nuernberg_altstadt_nacht.jpg $S/ab/nu_high_h22_ab_01.jpg rennen_nuernberg_altstadt_nacht.jpg "Nürnberg km 102,7, Hoch, 22 Uhr, +4 s"
pair "" $S/ab/hn_high_h22_ab_01.jpg rennen_hannover_nacht.jpg "Hannover km 143,9, Hoch, 22 Uhr, +4 s"
pair "" $S/ab/hh_medium_h19.5_ab_01.jpg rennen_hamburg_innenstadt_daemmerung.jpg "Hamburg km 88,2, Mittel, 19:30, +4 s"
pair "" $S/ab/nu_medium_h19.5_ab_01.jpg rennen_nuernberg_altstadt_daemmerung.jpg "Nürnberg km 102,7, Mittel, 19:30, +4 s"
pair 08_rennen_hannover_daemmerung.jpg $S/ab/hn_medium_h19.5_ab_01.jpg rennen_hannover_daemmerung.jpg "Hannover km 143,9, Mittel, 19:30, +4 s"
pair 01_rennen_muenchen_links_fehlen_haeuser_mittag.jpg $S/ab/mu_high_h12_ab_01.jpg rennen_muenchen_mittag.jpg "München, Nürnberg–München km 161,7, Hoch, 12 Uhr, +4 s"
rm -rf $T
ls -la $D | grep rennen
