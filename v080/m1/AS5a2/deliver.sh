#!/usr/bin/env bash
# AS5a2: delivery pictures (German names, caption strip on top) from the review shots.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a2
mkdir -p $D
cap() {   # cap <in.png> <out.jpg> <caption> [max width]
	[ -f "$1" ] || { echo "fehlt: $1"; return; }
	local w=${4:-1920}
	convert "$1" -resize "${w}x>" -background '#1b1f27' -fill white -font DejaVu-Sans -pointsize 22 \
		-gravity center label:"$3" +swap -append -quality 88 "$D/$2"
	echo "$2"
}
declare -A NAME
NAME[french]="Südhaus, Loire-Haus, Lyoner Stadthaus"
NAME[belgian]="Lütticher Reihenhäuser, Maashaus"
NAME[dutch]="niederländische Reihenhäuser, Grachtenhäuser A und B"
NAME[swiss]="Chalet, Berner Lauben"
NAME[paris]="Haussmann-Block, Haussmann-Eckhaus"
for st in french belgian dutch swiss paris; do
	cap $S/shots/real_$st/close_h12.png nahansichten_${st}_mittag.jpg "Nahansichten Straße / schräg / vorn – ${NAME[$st]} – lod0, Hoch, 12 Uhr"
	cap $S/shots/real_$st/close_h22.png nahansichten_${st}_nacht.jpg "Nahansichten Straße / schräg / vorn – ${NAME[$st]} – lod0, Hoch, 22 Uhr"
	cap $S/shots/real_$st/dist_h12.png spielkamera_${st}_mittag.jpg "Spielkamera 10 / 30 / 100 / 250 m neben der Straße, darunter das Arcade-Sprite – ${NAME[$st]} – Hoch, 12 Uhr"
	cap $S/shots/real_$st/dist_h22.png spielkamera_${st}_nacht.jpg "Spielkamera 10 / 30 / 100 / 250 m neben der Straße, darunter das Arcade-Sprite (Platzhalter ohne Fensterlicht) – ${NAME[$st]} – 22 Uhr"
done
cap $S/shots/fin/kontakt_tag.png kontaktbogen_tag.jpg "Kontaktbogen aller zwölf Modelle und Stufen, Tag (tools/models_contact_sheet.sh)"
cap $S/shots/fin/kontakt_nacht.png kontaktbogen_nacht.jpg "Kontaktbogen aller zwölf Modelle und Stufen, Nacht (ce_night = 1)"
for g in G1 G2 G3; do
	cap $S/shots/fin/lods_${g}_h12.png stufen_${g}_mittag.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite – Mittel, 12 Uhr"
	cap $S/shots/fin/lods_${g}_h22.png stufen_${g}_nacht.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite – Mittel, 22 Uhr"
done
cap $S/shots/fin/tint.png toenung_reihenhaeuser_ruhr.jpg "Tönung #ead6cc (Ruhrgebiet): Modell, Modell × Tönung (wie R7 es auftragen wird), Sprite getönt, Sprite"
cap $S/shots/fin/outline.png umrisse_sprite_gegen_modell.jpg "Umriss in der Sprite-Kamera: Modell gegen Sprite"
cap $S/shots/fin/spark.png flimmern_messbild.jpg "Flimmern: Viertelpixel-Schritte der Kamera bei 40 / 60 / 100 / 150 m, Modell und Sprite"
echo "=== deliver fertig"
