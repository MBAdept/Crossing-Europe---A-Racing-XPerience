
### 6.2 Ist die „nachher“-Hälfte der Klang des Endstands?

Zwei unabhängige Wege, beide gemessen:

**(a) Welche Schleifendatei spielt?** Eine Strecke mit festem Tempo wird gegen jede Kandidatendatei kreuzkorreliert
(Datei mit der Tonhöhe des Tempos gerendert, 1–8 kHz, normiert, jede Verschiebung einer Periode). Die Datei, die spielt,
gibt einen klaren Höchstwert; fremde bleiben im Rauschen (≤ 0,09). Probe aufs Exempel an meinen eigenen Aufnahmen: die
Neuaufnahme auf dem Endstand findet die Dateien des Endstands (0,421 / 0,731), die auf AU-R die von AU-R (0,462 / 0,750).

| Strecke | Endstand-Datei | AU-R-Datei | AU-C1-Datei |
|---|---|---|---|
| vorher_nachher, **nachher**, Beton 175 km/h (`slab_fast`, 0:54.2–0:57.6) | **0,414** | 0,039 | 0,089 |
| vorher_nachher, **nachher**, Hamburger Pflaster rechts (`tyre_cobbles_b`, 1:26.3–1:31.6) | **0,700** | 0,020 | 0,019 |
| vorher_nachher, vorher, Beton 175 km/h | 0,121 | 0,043 | **0,481** |
| vorher_nachher, vorher, Pflaster (AU-C1s eine Schleife) | – | – | **0,824** |
| spielmix_neu, Beton 175 km/h (0:05.4–0:08.8, mit Musik) | **0,387** | 0,039 | 0,085 |
| spielmix_neu, Pflaster rechts (0:37.9–0:43.3, mit Musik) | **0,255** | 0,018 | – |

Die beiden Dateien, die AU-R2 geändert hat (Plattenmuster, rechte Pflasterschleife), sind in beiden neuen Hörproben
die des Endstands; AU-R3 hat keine Klangdatei geändert (git: nur `audio_feed.gd`, Test, Doku, eine Beschreibung).

**(b) Klingt eine Neuaufnahme gleich?** Dieselbe Fahrt (`drive_ab.gd` von AU-R2, `--cobble-km=88.4`) auf dem Endstand,
auf AU-R und auf AU-C1 neu aufgenommen und Strecke für Strecke mit den Hälften der MP3 verglichen (Terzen, Lautheit):

| Vergleich | Beton 175 km/h | Stahldeck 120 km/h (mit Fugen) | Pflaster 50 km/h |
|---|---|---|---|
| nachher → Neuaufnahme **Endstand** | Terzen 500 Hz–10 kHz **−0,2 … +0,1 dB**; Motorbänder 125 / 251 / 398 Hz +1,9 / +1,0 / +1,5 dB → +1,16 LU | −0,4 … +0,9 dB, −0,21 LU | −0,2 … +0,5 dB, +0,17 LU |
| nachher → Neuaufnahme AU-R | −0,2 … +1,5 dB (Motorbänder +1,1 / +0,7 / +1,5), +0,82 LU | −0,1 … +1,3 dB, +0,78 LU | −0,3 … +1,1 dB, +0,04 LU |
| nachher → Neuaufnahme AU-C1 | −0,5 … +1,3 dB (Motorbänder +1,3 / +0,7 / +1,0), +0,98 LU | **+0,2 … +6,4 dB** (12 Fugen statt 4), +0,48 LU | −0,7 … +1,2 dB, −0,24 LU |
| vorher → Neuaufnahme AU-C1 (Streuung einer Neuaufnahme desselben Stands) | −0,2 … +0,5 dB, +0,35 LU | −0,1 … +0,9 dB, +0,24 LU | −0,9 … +0,6 dB, +0,09 LU |

Ergebnis: **Ja.** Die nachher-Hälfte und der Spielmix sind der Klang des Endstands: über 500 Hz (Platten, Reifen, Wind)
auf 0,2 dB gleich, auf Pflaster und Deck innerhalb der Streuung einer Neuaufnahme. Die +1,16 LU auf Beton kommen aus den
Motorbändern (125 / 251 / 398 Hz); alle drei Neuaufnahmen – gleich welcher Stand – liegen dort 0,7–1,9 dB über der MP3:
die Hörprobe hat in diesen 3,6 s einen leiseren Motormoment (Motor-Bewegung; Motordateien seit AU-C1 byte-gleich).

### 6.3 Die übrigen Hörproben

`koehlbrandbruecke_fugen_vorher_nachher`, `aufprall_abwechslung_neu`, `schnee_neu` stammen von AU-R. Zwischen AU-R und dem
Endstand haben sich nur die Plattenmuster, die rechte Pflasterschleife, das Plattengesetz über 150 km/h, die Sperre und
die Altstadtregel geändert (git diff `3d2e6e1..b6339ad`); keine davon spielt auf dem Stahldeck, beim Aufprall oder im
Schnee. Diese drei Hörproben gelten darum für den Endstand (abgeleitet aus dem Diff; die Fugenzeiten der Brücke sind
gemessen, Tabelle 6.1). Die Angaben in den .txt (z. B. „tiefer Schlag 2,5 dB leiser“, „bei 170 km/h knapp 1 dB leiser“,
„Pflaster ohne die zwei lauten Steine“) stimmen mit der Konfiguration bzw. meinen Messungen überein
(`hit_heavy` −11,5 statt −9; −0,82 dB bei 170 km/h; rechts ≤ +0,43 dB).
