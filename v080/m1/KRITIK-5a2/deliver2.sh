#!/usr/bin/env bash
# race A/B delivery: both shots (2 s above 4 s) with a caption
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
A=$K/ab
mk() {  # mk <prefix> <out.jpg> <caption>
  [ -f $A/${1}_ab_01.jpg ] || { echo "fehlt $1"; return; }
  convert $A/${1}_ab_00.jpg $A/${1}_ab_01.jpg -append $K/tmpimg/${1}_both.jpg
  $K/cap.sh $K/tmpimg/${1}_both.jpg "$2" "$3" 2566
}
mk pa_high_h12 01_rennen_paris_mittag.jpg "Paris (Lüttich–Paris km 387,5), Hoch, 12 Uhr, oben +2 s, unten +4 s – links Arcade, rechts Modern: Haussmann-Flanke mit Bogenläden, Balkonen, Gittern statt Bildfläche"
mk pa_high_h22 02_rennen_paris_nacht.jpg "Paris km 387,5, Hoch, 22 Uhr: Wohnfenster wie Arcade, die Bogenläden leuchten auf einem Drittel der Fläche und dunkler (K1)"
mk am_high_h12 03_rennen_amsterdam_mittag.jpg "Amsterdam (Bremen–Amsterdam km 357,3), Hoch, 12 Uhr: Grachtenhäuser mit Flankenfenstern, Treppen, Gesimsen"
mk br_high_h12 04_rennen_bruessel_mittag.jpg "Brüssel (Köln–Brüssel km 195,5), Hoch, 12 Uhr: Maashaus-Flanke, Lütticher Reihen; die niedrigen Backsteinmauern von Arcade fehlen in Modern (Renderer, nicht AS5a2)"
mk ly_high_h12 05_rennen_lyon_mittag.jpg "Lyon (Montpellier–Lyon km 297,0), Hoch, 12 Uhr: bei +2 s fehlt rechts das Lyoner Haus (Kurvenkorridor F7, FIX-M2 B-01 noch nicht in diesem Stand); bei +4 s Lyoner Haus mit Läden, Quadern"
mk be_high_h12 06_rennen_bern_mittag.jpg "Bern (Lyon–Bern km 302,3), Hoch, 12 Uhr: Lauben als echte Arkaden beidseits, Blumenkästen; +2 s links fehlt eine Laube (Kurvenkorridor)"
mk am_high_h22 07_rennen_amsterdam_nacht.jpg "Amsterdam km 357,3, Hoch, 22 Uhr"
mk be_high_h22 08_rennen_bern_nacht.jpg "Bern km 302,3, Hoch, 22 Uhr"
mk br_medium_h19.5 09_rennen_bruessel_daemmerung_mittel.jpg "Brüssel km 195,5, Mittel, 19:30"
mk ly_out_high_h12 11_rennen_lyon_vorort_mittag.jpg "Lyon Vorort (Montpellier–Lyon km 285,6), Hoch, 12 Uhr: Südhäuser"
mk am_out_high_h12 12_rennen_amsterdam_vorort_mittag.jpg "Amsterdam Vorort (Bremen–Amsterdam km 345,5), Hoch, 12 Uhr: niederländische Reihenhäuser"
