#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
C=$K/cap.sh
declare -A NAME
NAME[PAR]="Haussmann-Block (oben), Haussmann-Eckhaus"
NAME[DUT]="Grachtenhäuser A, Grachtenhäuser B, niederländische Reihenhäuser"
NAME[BEL]="Lütticher Reihenhäuser, Maashaus"
NAME[FRA]="Südhaus, Loire-Haus, Lyoner Stadthaus"
NAME[SWI]="Chalet, Berner Lauben"
declare -A LOW
LOW[PAR]=paris; LOW[DUT]=dutch; LOW[BEL]=belgian; LOW[FRA]=french; LOW[SWI]=swiss
declare -A HN
HN[12]=mittag; HN[19.5]=daemmerung; HN[22]=nacht
for st in PAR DUT BEL FRA SWI; do
  for h in 12 19.5 22; do
    $C shots/dist/${st}_h$h.png 10_abstaende_${LOW[$st]}_${HN[$h]}.jpg "Spielkamera 10 / 30 / 100 / 250 m neben der Straße (Hoch, $h Uhr); je Modell oben das Modell, darunter das Arcade-Sprite in gleicher Lage (Prüfszene: Sprite ohne Fensterlicht) – ${NAME[$st]}" 1920
  done
  $C shots/close/${st}_h12.png 20_nahansichten_${LOW[$st]}_tag.jpg "Nahansichten Straßenflanke / schräg / vorn / hinten, lod0, Hoch, 12 Uhr – ${NAME[$st]}" 2560
  $C shots/close/${st}_h22.png 21_nahansichten_${LOW[$st]}_nacht.jpg "Nahansichten Straßenflanke / schräg / vorn / hinten, lod0, Hoch, 22 Uhr – ${NAME[$st]}" 2560
done
for g in G1 G2 G3; do
  $C shots/lods/${g}_m_h12.png 25_stufenwechsel_${g}_mittel_tag.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m (zweimal), Sprite bei 200 m – Mittel, 12 Uhr" 1800
  $C shots/lods/${g}_m_h22.png 25_stufenwechsel_${g}_mittel_nacht.jpg "Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m (zweimal), Sprite bei 200 m – Mittel, 22 Uhr" 1800
done
$C shots/outline.png 26_umrisse_sprite_gegen_modell.jpg "Umriss in der Sprite-Kamera (−20°, 6°): Modell, Deckung lod0, Modell auf Magenta, Deckung lod1, lod1 (grün beide, blau nur Sprite, orange nur Modell)" 1600
$C shots/tint.png 27_toenung_reihenhaeuser_ead6cc.jpg "Tönung #ead6cc (Ruhrgebiet): Modell, Modell × Tönung (so wird R7 sie auftragen), Sprite × Tönung, Sprite – 35 m, 12 Uhr" 1440
$C shots/far250.png 29_fern_250m_blass.jpg "Fernbild: lod0 bei 60 m, lod0 / lod1 / Sprite bei 250 m (Hoch, 12 Uhr): die Fenster der Modelle verblassen zu hellen, rosa-lila Flecken, das Sprite behält dunkle Fenster" 1280
