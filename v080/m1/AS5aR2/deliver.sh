#!/usr/bin/env bash
# AS5aR2: delivery pictures (German names, caption strip) from the review shots
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR2
mkdir -p $D
C=$S/cap.sh
declare -A NAME
NAME[FRA]="Südhaus, Loire-Haus, Lyoner Stadthaus"
NAME[BEL]="Lütticher Reihenhäuser, Maashaus"
NAME[DUT]="Grachtenhäuser A und B, niederländische Reihenhäuser"
NAME[SWI]="Chalet, Berner Lauben"
NAME[PAR]="Haussmann-Block, Haussmann-Eckhaus"
declare -A LOW
LOW[FRA]=french; LOW[BEL]=belgian; LOW[DUT]=dutch; LOW[SWI]=swiss; LOW[PAR]=paris
for g in FRA BEL DUT SWI PAR; do
	$C $S/shots/fin/close_${g}_h12.png nahansichten_${LOW[$g]}_mittag.jpg "Nahansichten Straße / schräg / vorn – ${NAME[$g]} – lod0, Hoch, 12 Uhr"
	$C $S/shots/fin/close_${g}_h22.png nahansichten_${LOW[$g]}_nacht.jpg "Nahansichten Straße / schräg / vorn – ${NAME[$g]} – lod0, Hoch, 22 Uhr"
	$C $S/shots/fin/dist_${g}_h12.png spielkamera_${LOW[$g]}_mittag.jpg "Spielkamera 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite – ${NAME[$g]} – Hoch, 12 Uhr"
	$C $S/shots/fin/dist_${g}_h19.5.png spielkamera_${LOW[$g]}_daemmerung.jpg "Spielkamera 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite – ${NAME[$g]} – Hoch, 19:30"
	$C $S/shots/fin/dist_${g}_h22.png spielkamera_${LOW[$g]}_nacht.jpg "Spielkamera 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite (Platzhalter ohne Fensterlicht) – ${NAME[$g]} – 22 Uhr"
done
$C $S/shots/fin/dist_B1I_h22.png spielkamera_charge1_nacht.jpg "Charge 1 (Gründerzeit, Mietshaus, Kontor), 22 Uhr – Läden mit dem neuen Ladenlicht"
$C $S/shots/fin/kontakt_B2_tag.png kontaktbogen_charge2_tag.jpg "Kontaktbogen der zwölf Häuser von Charge 2, lod0 und lod1, Tag" 1600
$C $S/shots/fin/kontakt_B2_nacht.png kontaktbogen_charge2_nacht.jpg "Kontaktbogen der zwölf Häuser von Charge 2, Nacht" 1600
$C $S/shots/fin/kontakt_B1_tag.png kontaktbogen_charge1_tag.jpg "Kontaktbogen der elf Häuser von Charge 1 (neu exportiert), Tag" 1600
$C $S/shots/fin/kontakt_B1_nacht.png kontaktbogen_charge1_nacht.jpg "Kontaktbogen der elf Häuser von Charge 1, Nacht" 1600
for g in G1 G2 G3; do
	$C $S/shots/fin/lods_${g}_h12.png stufen_${g}_mittag.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite – Mittel, 12 Uhr"
	$C $S/shots/fin/lods_${g}_h22.png stufen_${g}_nacht.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite – Mittel, 22 Uhr"
done
$C $S/shots/fin/tint.png toenung_reihenhaeuser_ruhr.jpg "Tönung #ead6cc (Ruhrgebiet): Modell, Modell × Tönung (wie R7 sie auftragen wird), Sprite getönt, Sprite"
$C $S/shots/fin/outline.png umrisse_sprite_gegen_modell.jpg "Umriss in der Sprite-Kamera: Modell gegen Sprite"
$C $S/shots/fin/spark.png flimmern_messbild.jpg "Flimmern: Viertelpixel-Schritte der Kamera bei 40 / 60 / 100 / 150 m, Modell und Sprite"
$C $S/shots/fin/lodcol_pick.png fernbild_250m.jpg "Fernbild: Südhaus, Haussmann, Lauben bei 60 und 250 m – lod0 / lod1 / Sprite (K2 nicht behoben)" 960
for f in $S/del/*.jpg; do cp "$f" $D/; done
for r in pa_high_h22 pa_high_h12 be_high_h22 am_high_h12 ly_out_high_h12 hh_high_h22 br_medium_h19.5 pa_medium_h19.5; do
	for i in 00 01; do
		[ -f $S/ab/${r}_ab_$i.jpg ] && cp $S/ab/${r}_ab_$i.jpg $D/rennen_${r}_$i.jpg
	done
done
[ -f $S/clip/fahrt_paris_50kmh.mp4 ] && cp $S/clip/fahrt_paris_50kmh.mp4 $D/
echo "=== deliver fertig"
