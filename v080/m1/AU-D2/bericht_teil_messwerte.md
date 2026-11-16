## 3. Messwerte (alle gemessen)

### 3.1 Die neuen Dateien

| Datei | Länge | Schleife | Lautheit | True Peak nach Vorbis | Größe |
|---|---|---|---|---|---|
| `nachtfahrt.ogg` | 203,4 s | ab 20,57 s, 80 Takte = 182,86 s | −14,24 LUFS | −1,52 dBTP | 3,93 MB |
| `nachtfahrt_schluss.ogg` | 8,8 s | – | −15,27 LUFS | −2,16 dBTP | 0,17 MB |
| `rueckenwind.ogg` | 155,2 s | ab 14,40 s, 88 Takte = 140,80 s | −14,16 LUFS | −1,78 dBTP | 2,98 MB |
| `rueckenwind_schluss.ogg` | 7,4 s | – | −15,97 LUFS | −2,15 dBTP | 0,14 MB |
| `zwischenspiel.ogg` | 81,6 s | ab 4,80 s, 32 Takte = 76,80 s | −14,13 LUFS | −1,51 dBTP | 1,61 MB |
| `*_ziel.ogg` (LS / NF / RW) | 6,4 / 6,9 / 6,2 s | – | −17,8 / −16,5 / −18,7 LUFS | −3,0 / −2,3 / −3,0 dBTP | je 0,09 MB |
| `*_schluss_rekord.ogg` | 10,1 / 11,5 / 9,4 s | – | −15,3 / −14,8 / −15,7 LUFS | −2,5 / −1,7 / −2,2 dBTP | 0,16–0,20 MB |
| `*_schluss_finale.ogg` | 11,9 / 13,7 / 11,0 s | – | −14,7 / −14,3 / −14,8 LUFS | −2,2 / −2,0 / −2,6 dBTP | 0,19–0,24 MB |
| `*_polizei.ogg` | 10,1 / 11,5 / 9,4 s | – | −16,1 / −15,4 / −15,8 LUFS | −3,0 / −2,5 / −3,2 dBTP | 0,12–0,15 MB |
| `*_tank.ogg` | 8,2 / 9,2 / 7,8 s | – | −19,2 / −17,9 / −19,3 LUFS | −5,0 / −4,8 / −6,4 dBTP | 0,11–0,14 MB |

Die Längen der Clips enthalten den Nachklang (Hall, Echos) bis zur Stille; musikalisch sind es 1 (Ziel), 2 (Tank),
3 (Rekord, Polizei) und 4 Takte (Finale). Zusatzclips tragen den Pegel ihres Stücks und sind deshalb nicht auf
−14 LUFS gebracht (eigene QC-Grenzen im Manifest).

- **Musikordner**: 18,54 MB von 25 MB (`audio_qc.py`, mit Titel-Remaster, „Linke Spur“ und dem Platzhalter von AU-A);
  **UI-Ordner** 0,75 MB.
- **Bitgleich geblieben**: `linke_spur.ogg` (sha256 d8fb9046…), `linke_spur_schluss.ogg` (f6630635…),
  `titel_remaster.ogg` (63ca5b0d…) – nach dem letzten Rendering verglichen.
- **Schleifen** (Abweichung des zweiten Durchgangs vom ersten über die Naht, im Rendering vor der Kodierung):
  „Linke Spur“ −172,2 dBFS, „Nachtfahrt“ −186,7 dBFS, „Rückenwind“ −175,7 dBFS, Zwischenspiel −112,9 dBFS (der
  Ausklang der Echos; unhörbar). In Godot gleicht die Ausgabe nach dem Dateiende dem ersten Durchgang bei allen vier
  Frame für Frame (Abweichung 0, `check_music.gd`).
- **Schluss am Taktstrich** (`check_music.gd`, offline in 512er-Schritten wie der Mischer): alle drei Rennstücke nach
  der Schleife und die Varianten Rekord und Finale („Nachtfahrt“, erster Durchgang) beginnen 2,90–2,93 ms vor dem
  Taktstrich (die bekannte Vorlaufzeit des Decoders), ohne Lücke (leisestes 5-ms-Fenster 6,4–7,6 dB unter der Musik
  davor), ohne doppelten Schlag (erste 100 ms −0,04 bis +0,01 dB gegenüber dem Clip allein).
- **Noten** (`check_music.py`, Chroma je Takt gegen die Partitur): „Nachtfahrt“ Grundton in 83 von 89 Takten
  (93,3 %), Tonart c-Moll erkannt, Schluss A♭ – B♭ – c; „Rückenwind“ 87 von 97 Takten (89,7 %), Tonart A-Dur, Schluss
  F – G – A (den G-Dur-Akkord hört der Erkenner als e-Moll: zwei gemeinsame Töne); „Linke Spur“ unverändert 85 von
  97. Zusatzclips aller drei Stücke: Ziel-Schlag und Rekord auf der Tonika, Finale endet in Dur (D, C, A), Polizei
  in der Moll-Tonart (d, c, a), Tank auf dem Moll-Grundton. Die abweichenden Takte sind Farbakkorde und Obertöne,
  die der Dreiklang-Erkenner einem Nachbarakkord zuschlägt.

**Klangbalance gegen „Linke Spur“** (Langzeitspektrum, Anteil je Band an der Gesamtenergie; die anderen Stücke als
Abstand zu „Linke Spur“):

{BANDS}

Die beiden neuen Rennstücke liegen in jedem Band höchstens 1,0 dB von „Linke Spur“ entfernt (dieselben Instrumente,
dieselbe Misch- und Master-Kette); das Zwischenspiel ist absichtlich weicher (weniger Sub, Bass und Präsenz, mehr
Mitten: Flächen, Glocken, cleane Gitarre).

- **Tempo und Länge**: „Nachtfahrt“ 105 bpm, bis zur ersten Wiederholung 3:23 min (mit Schluss 3:32); „Rückenwind“
  150 bpm, 2:35 min (mit Schluss 2:43); „Linke Spur“ 132 bpm, 2:56 min. Zwischenspiel 100 bpm, Schleife 1:17 min.
- **UI-Klänge** (Dateipegel, integriert / True Peak): `ui_move` −23,0 LUFS / −13,1 dBTP, `ui_ok` −22,1 / −8,4,
  `ui_back` −22,7 / −9,6, `ui_tab` −22,5 / −10,8, `ui_toggle` −24,2 / −11,1, `ui_error` −20,1 / −11,2; Längen
  0,42–0,85 s.
- **Rechenzeit** (ein Kern, `nice -n 19`, Maschine geteilt): „Linke Spur“ mit Zusatzclips 330–407 s, „Nachtfahrt“
  400–447 s, „Rückenwind“ 305–337 s, Zwischenspiel 76–81 s, UI-Klänge 1 s; `render_all.py` alles zusammen etwa
  25–27 Minuten.
