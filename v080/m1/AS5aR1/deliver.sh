#!/usr/bin/env bash
# AS5aR1: delivery pictures (JPG) into deliver/AS5aR1 - composed from shots/vor (63544b6) and shots/fin (final)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR1
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-5a1
mkdir -p $D
cd $S/shots
FONT=DejaVu-Sans
lab() {   # lab <in> <text> <out> [width]
	convert "$1" -resize "${4:-960}x" -gravity south -background '#1a1c20' -fill white -font $FONT -pointsize 20 \
		-splice 0x30 -annotate +0+5 "$2" "$3"
}
T=$S/tmp_del; rm -rf $T; mkdir -p $T
# 1/2: road flanks before / after, day and night
for h in 12 22; do
	rows=()
	for m in city_german_old_fachwerk:OLD city_german_old_fachwerk_b:OLD city_german_old_barock:OLD city_hanse_gabled:HAN; do
		id=${m%%:*}; g=${m##*:}
		lab vor/close_h${h}_${id}_road.png "vorher (63544b6): $id, Straßenflanke, ${h} Uhr" $T/a.png
		lab fin/close_${g}_h${h}_${id}_road.png "nachher: $id, Straßenflanke, ${h} Uhr" $T/b.png
		convert $T/a.png $T/b.png +append $T/row_${id}.png
		rows+=($T/row_${id}.png)
	done
	tag=$([ $h = 12 ] && echo tag || echo nacht)
	convert "${rows[@]}" -append -quality 88 $D/flanken_vorher_nachher_$tag.jpg
done
# 3/4: test street at 50 km/h, before / after (same camera, frames 20, 40, 60)
for st in SOLD SHAN; do
	for h in 12 22; do
		rows=()
		for f in 020 040 060; do
			lab vor/drive_${st}_h$h/f_$f.png "vorher, Bild $f, ${h} Uhr" $T/a.png 800
			lab fin/drive_${st}_h$h/f_$f.png "nachher, Bild $f, ${h} Uhr" $T/b.png 800
			convert $T/a.png $T/b.png +append $T/r$f.png
			rows+=($T/r$f.png)
		done
		name=$([ $st = SOLD ] && echo altstadt || echo hanse)
		tag=$([ $h = 12 ] && echo tag || echo nacht)
		convert "${rows[@]}" -append -quality 86 $D/pruefstrasse_${name}_50kmh_vorher_nachher_$tag.jpg
	done
done
# 5: oriel
lab $K/31_mangel_erker_fachwerk_b.jpg "vorher (Kritik, Bild 31): gemalte Erkerfenster, weiße Konsole" $T/a.png 1280
lab fin/erker_h12.png "nachher 12 Uhr: Futter, Sprossen, Sohlbank, Sandstein-Konsole" $T/b.png 1280
lab fin/erker_h22.png "nachher 22 Uhr" $T/c.png 1280
convert $T/a.png $T/b.png $T/c.png -append -quality 88 $D/erker_vorher_nachher.jpg
# 6: railings (Gruenderzeit oriel balcony at 80 m and 110 m, high)
lab cmp_rail.png "Gründerzeithaus, Erkerbalkon bei 80 m (oben) und 110 m (unten), Hoch, 3x: links vorher, rechts nachher" $D/gelaender_vorher_nachher.jpg 1440
cp fin/rail_h12.png $T/r.png; lab $T/r.png "Mietshaus und Gründerzeithaus bei 15/40/80/110 m (Hoch), darunter je das Arcade-Sprite, 12 Uhr" $D/gelaender_abstaende_mittag.jpg 1600
# 7: level switch, shimmer, outline, tint
lab fin/lods_h12.png "Stufenwechsel lod0/lod1 bei 60 m, lod1 und Sprite bei 200 m, Mittel, 12 Uhr (Haus: Gartenstufe 0,3; geliefert 0,5)" $D/stufenwechsel_mittel_tag.jpg 1200
lab fin/lods_h22.png "Stufenwechsel, Mittel, 22 Uhr (Haus: Gartenstufe 0,3; geliefert 0,5)" $D/stufenwechsel_mittel_nacht.jpg 1200
[ -f house05/lods_h12.png ] && lab house05/lods_h12.png "Einfamilienhaus mit Gartenstufe 0,5 (geliefert), 12 Uhr" $D/stufenwechsel_haus_geliefert.jpg 1200
lab fin/spark.png "Flimmer-Messbild (Viertelpixel-Schritte), Mittel, 12 Uhr" $D/flimmern_messbild.jpg 1600
lab fin/outline.png "Umriss in der Sprite-Kamera" $D/umrisse_sprite_gegen_modell.jpg 1600
lab fin/tint.png "Tönungen: Modell, Modell x Tönung, Sprite x Tönung, Sprite (40 m, 12 Uhr)" $D/toenungen.jpg 1600
# 8: distance and close sheets
for g in GER:german OLD:altstadt HAN:hanse; do
	k=${g%%:*}; n=${g##*:}
	for h in 12 19.5 22; do
		t=$([ $h = 12 ] && echo mittag || ([ $h = 19.5 ] && echo daemmerung || echo nacht))
		lab fin/dist_${k}_h$h.png "Spielkamera 10/30/100/250 m, darunter das Arcade-Sprite, Hoch, $h Uhr" $D/abstaende_${n}_$t.jpg 1600
	done
	for h in 12 22; do
		t=$([ $h = 12 ] && echo tag || echo nacht)
		lab fin/close_${k}_h$h.png "Nahansichten Straße/schräg/vorn/hinten, Hoch, $h Uhr" $D/nahansichten_${n}_$t.jpg 1600
	done
done
rm -rf $T
ls -la $D | head -60
du -sh $D
