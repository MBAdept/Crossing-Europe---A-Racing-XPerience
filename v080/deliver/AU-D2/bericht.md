# AU-D2 – Rennstücke 2 und 3, Zwischenspiel, Stinger, UI-Klänge

Paket AU-D2 (Vorstart einer späteren Welle). Branch `worktree-wf_2b39c7a4-a94-1`, gesichert als
`origin/wip/v080-au-d2`, Basis 03eaeff (Kopf von AU-D1). Alle Zahlen **gemessen** auf dieser VM (Godot 4.7.2 ohne
Bildschirm, Dummy-Audiotreiber, ffmpeg/numpy), sofern nicht **abgeleitet** dasteht.

**Niemand hier hat die Musik gehört.** Klang, Stil der neuen Stücke, Bass und Pegel muss der Nutzer beurteilen – mit
Kopfhörern, wie er es für heute Abend vorhat. Ich beurteile nur, was sich messen lässt: Pegel, Schleifen, Takt,
Noten, Klangbalance gegen „Linke Spur“, deren Stil er bestätigt hat.

## 1. Für den Nutzer: die Hörproben (in diesem Ordner)

| Datei | Länge | Inhalt |
|---|---|---|
| `rennmusik_2_nachtfahrt_auszug_45s.mp3` | 45 s | Rennstück 2 „Nachtfahrt“ (das dunkle, c-Moll, 105 bpm): Einzähler, A1 (Halbtakt-Groove, Synth-Bass, Motiv), Beginn des Hooks B1 |
| `rennmusik_2_nachtfahrt_komplett_mit_schluss.mp3` | 3:32 | das ganze Stück, wie ein Rennen es spielt: Einzähler, A1, einmal die Schleife, dann der Schluss am Taktstrich |
| `rennmusik_3_rueckenwind_auszug_45s.mp3` | 45 s | Rennstück 3 „Rückenwind“ (das helle, A-Dur, 150 bpm), die ersten 45 s |
| `rennmusik_3_rueckenwind_komplett_mit_schluss.mp3` | 2:43 | das ganze Stück mit Schluss |
| `zwischenspiel_komplett_plus_schleifennaht.mp3` | 1:42 | das Zwischenspiel (e-Moll, 100 bpm) einmal ganz und 20 s weiter über die Schleifennaht |
| `stinger_alle_nacheinander.mp3` | 3:14 | alle Zusatzclips der drei Stücke (Linke Spur, Nachtfahrt, Rückenwind): je Ziel-Schlag, Schluss, Schluss „Rekord“, Schluss „Finale“, „Polizei“, „Tank“ – je 1,5 s Stille dazwischen, ohne Ansage, Reihenfolge wie im Spektrogramm |
| `stinger_im_rennen_nachtfahrt_polizei_rueckenwind_tank_linke_spur_ziel_rekord.mp3` | 1:00 | drei Szenen, wie das Spiel sie mischt (ohne Auto): „Nachtfahrt“ läuft, „Erwischt“ auf dem nächsten Schlag über der um 9 dB abgesenkten Musik; „Rückenwind“, „Tank leer“; „Linke Spur“, Ziellinie 0,9 s vor dem Taktstrich: Ziel-Schlag, am Taktstrich der Schluss „Rekord“ |
| `ui_klaenge_demo.mp3` | 11 s | die UI-Klänge: 3 × Fokus (zwei Varianten im Wechsel), Wert ändern, Reiter, Bestätigen, Zurück, Geht nicht – je 0,8 s Pause |
| `rennmusik_2_nachtfahrt_spektrogramm.png`, `rennmusik_3_rueckenwind_spektrogramm.png`, `zwischenspiel_spektrogramm.png`, `stinger_spektrogramm.png`, `ui_klaenge_spektrogramm.png` | – | Spektrogramme mit den Abschnitten |

Die MP3s haben den Pegel der Dateien (Musik −14 LUFS, 192 kbit/s). Im Spiel liegt die Rennmusik etwa 8 dB unter dem
Auto bei Vollgas, das Zwischenspiel bei der Menü-Lautheit von etwa −20 LUFS – beides **abgeleitet** (gleiche
Dateilautheit und Klangbalance wie „Linke Spur“ und das Titel-Remaster, die AU-D1 in der Kette gemessen hat).

**Wenn Bass oder Pegel nicht passen**: Eine Zahl in `tools/audio/music/mischung.json` ändern (`sub_db`, `bass_db`,
`high_shelf_db`, `race_music_db`, `menu_music_db`, `ui_db`), dann `python3 tools/audio/music/render_all.py` und
`godot --headless --import` – alle Stücke ändern sich gleich (etwa 25 Minuten Rechenzeit).

## 2. Was gebaut ist

- **Rennstück 2 „Nachtfahrt“** (`tools/audio/music/nachtfahrt.py`): c-Moll, 105 bpm – das dunkle Stück:
  Halbtakt-Groove in den Strophen, sequenzierter Sechzehntel-Synth-Bass, hypnotisches Arpeggio über Farbakkorden
  (Cm9, A♭maj7, E♭add9, Fm7), sparsame dunkle Gitarren, Motiv auf der weichen Lead-Stimme, Hook über ♭VI – ♭III –
  ♭VII – i. Form: Einzähler | A1 | B1 A2 C1 B2 D S C2 B3 T A1 (Schleife 80 Takte = 182,9 s).
- **Rennstück 3 „Rückenwind“** (`rueckenwind.py`): A-Dur, 150 bpm – das helle: Disco-Rock-Beat mit offenen Hi-Hats
  auf den Nachschlägen, Oktav-Achtelbässe, Gitarren im 3-3-2-Rhythmus der Marke, funkelndes Arpeggio, der heroische
  Aufstieg F – G – A, ein Hook bis zum hohen a'''. Form wie „Linke Spur“ (Schleife 88 Takte = 140,8 s).
- **Zusatzclips je Rennstück** (alle drei, auch „Linke Spur“): Ziel-Schlag, Schluss „Rekord“, Schluss „Finale“ (Moll
  endet in Dur), Stinger „Polizei“ und „Tank“ – in der Tonart des Stücks, mit seinen Spurpegeln und seinem Master.
- **Zwischenspiel** (`zwischenspiel.py`): e-Moll, 100 bpm, ruhig, mit dem Hook der Titelmelodie auf der weichen
  Lead-Stimme; Schleife 32 Takte = 76,8 s; Kontext `race_menu` (und `result`).
- **UI-Klänge** (`ui_klaenge.py` → `assets/audio/modern/ui/`): `ui_move` (2 Varianten), `ui_ok`, `ui_back` (sofort
  wirksam im Profil Modern), `ui_tab`, `ui_toggle`, `ui_error` (abrufbar als `ui/<id>`).
- **Gemeinsame Mischung** `tools/audio/music/mischung.json` + `render_all.py`: Sub, Bass, Höhen, Musikpegel im Rennen
  und im Menü, UI-Pegel – eine Änderung, alle Stücke gleich neu gerendert; bei 0 bitgleich.
- **Musik-Kette**: `race_lib.py` (gemeinsame Rennstück-Kette, Zusatzclips), `music_lib.py` (Mixer zeichnet seine
  Pegelentscheidungen auf und mischt damit andere Zeitleisten; Master `post_at`/`state`; Sub-Faltung wählbar;
  `prefs`), `check_music.py` (alle Stücke, Zusatzclips), `race_lib.check_tempo()`.
- **MusicDirector**: Rotation der drei Stücke (Manifest `rotation`), Zwischenspiel für `race_menu`/`result`,
  Schluss-Varianten nach `stage_finish {record, last_stage}`, Ziel-Schlag, Ausklingen des Schlusses in den
  Ergebnisbildschirm, Stinger auf dem nächsten Schlag mit Absenkung des Stücks, Zielklang ohne Rennmusik, Taktuhr,
  dritter Player `MusicSting`; beansprucht `stage_finish`.
- **Prüfungen**: `test_music_director.gd` (14 Tests: Rotation, Zwischenspiel, Varianten, Ziel-Schlag, Stinger …),
  `check_music.gd` (alle Rennstücke offline Frame für Frame mit Schluss und Varianten, Naht des Zwischenspiels,
  Arcade jetzt auch mit Stinger-Ereignissen, UI-Klängen und Zwischenspiel-Kontext), drei Tests von AU-A an das neue
  Verhalten angepasst (Abschnitt 6); Doku `docs/audio-modern.md` Abschnitt 14 (neu gegliedert, 14.1–14.14) und die
  Musik-Zeilen in 1, 4.1, 7, 10, 12.

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

| Band | Linke Spur (Anteil) | Nachtfahrt | Rückenwind | Zwischenspiel | Titel-Remaster |
|---|---|---|---|---|---|
| Sub 25–50 Hz | −9,9 dB | +0,2 dB | −0,2 dB | −2,6 dB | +0,2 dB |
| Bass 50–100 Hz | −3,2 dB | −0,5 dB | +0,1 dB | −1,7 dB | −0,2 dB |
| Grundton 100–250 Hz | −7,0 dB | +0,2 dB | −0,2 dB | −1,9 dB | −0,1 dB |
| Tiefe Mitten 250–800 Hz | −10,1 dB | +1,0 dB | −0,7 dB | +5,1 dB | +0,5 dB |
| Mitten 0,8–2,5 kHz | −12,3 dB | +0,5 dB | +0,7 dB | +3,8 dB | +0,2 dB |
| Präsenz 2,5–6 kHz | −14,3 dB | −0,3 dB | +0,7 dB | −2,3 dB | +0,1 dB |
| Höhen 6–12 kHz | −16,4 dB | +0,3 dB | +0,7 dB | −2,1 dB | −0,1 dB |
| Luft 12–18 kHz | −21,1 dB | +0,5 dB | +0,8 dB | −3,1 dB | −0,2 dB |

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

## 4. Entscheidungen und warum

1. **Schlüsse, Ziel-Schlag und Stinger je Stück, gerendert mit dessen Spurpegeln und Master.** „In der Tonart des
   Stücks“ heißt hier: dieselben Instrumente, dieselbe Partitur für jede Tonart (Kadenz, Tonika, phrygisches ♭II,
   Moll-Subdominante, Dur-Tonika), dasselbe Tempo. Die Zusatzclips laufen nach der Hauptdatei über eine eigene
   Zeitleiste und werden mit den aufgezeichneten Pegelentscheidungen des Stücks gemischt (`Mixer(ref=fit)`) und mit
   seinem gemessenen Master bearbeitet. Ein gemeinsames Rendering hätte die Normierung jeder Spur über die ganze Spur
   verändert – „Linke Spur“, deren Stil der Nutzer bestätigt hat, wäre nicht mehr bitgleich gewesen.
2. **Das Ziel ist Musik.** Der Director beansprucht `stage_finish`: Der Arcade-Jingle „finish“ (C-Dur-Arpeggio) klang
   bisher 0–1,8 s vor dem Schluss des Rennstücks – in c-Moll mit e gegen es. Jetzt: sofort der Ziel-Schlag in der
   Tonart (nur wenn der Taktstrich weiter als 0,3 s entfernt ist, sonst wäre es ein doppelter Schlag), am Taktstrich
   der Schluss in der passenden Variante. Ohne spielendes Stück („Musik im Rennen: Aus“) ist der Schluss selbst der
   Zielklang. Preis: Mit dem Regler „Musik“ auf 0 ist das Ziel in Modern still.
3. **Varianten statt Stinger über dem Schluss.** „Rekord“ und „Finale“ sind eigene Clips des
   `AudioStreamInteractive` mit demselben Übergang „nächster Taktstrich, ohne Überblenden“ wie der normale Schluss
   (gemessen wie bei AU-D1: Doku 14.4 und 14.12, hier Abschnitt 3). Eine Fanfare über dem laufenden Schluss hätte
   zeitlich nur auf ±1 Treiberportion gepasst und harmonisch gegen dessen Akkorde.
4. **Der Schluss klingt in den Ergebnisbildschirm aus.** Der Ergebnisbildschirm kommt 6 s nach dem Ziel
   (`render.finish_hold_s`), die Schlüsse dauern 8–13 s. Bisher schnitt der Kontextwechsel sie mit 0,6 s Ausblenden
   ab; jetzt läuft der Schluss bis 1,2 s vor seinem Ende weiter (höchstens 10 s), dann blendet das Zwischenspiel ein.
5. **Stinger auf dem nächsten Schlag, das Stück 9 dB darunter.** Ein Stinger mitten im Takt hätte gegen den Groove
   gestolpert. Die Wartezeit ist höchstens ein Schlag (0,40 s bei 150 bpm bis 0,57 s bei 105 bpm); die HUD-Meldung
   kommt sofort.
6. **Tempi, bei denen die Schleife exakt ist** (105 / 150 / 100 statt der geplanten 112 / 144 / 96 bpm): eine
   Sechzehntel muss eine ganze Zahl von Frames sein (bei 112 bpm lag die Naht bei −30 dBFS: Einsätze auf halben
   Frames) und die Schleife ein Vielfaches der 63-Frame-Blöcke des Kompressors (bei 108 bpm −34 dBFS) – beides
   gemessen, Falle 14.13.12; `race_lib.check_tempo()` verweigert seitdem andere Tempi.
7. **Zwischenspiel mit dem Hook der Titelmelodie.** Die Bildschirme zwischen den Etappen gehören zur Marke; der Hook
   leise auf der weichen Lead-Stimme verbindet Menü und Rennen. Das Ergebnis-Bild nimmt mangels eigenem Stück das
   Zwischenspiel (statt das Titel-Remaster neu zu starten) – so läuft vom Ergebnis zum Etappenbildschirm ein Stück.
8. **Gemeinsame Mischentscheidungen in einer Datei** (`mischung.json`), Werte relativ zu jedem Stück: eine Änderung
   von Sub, Bass oder Höhen wirkt in jedem Stück gleich, ohne dass die Stücke gleich klingen müssen. Bei 0 bleiben
   alle Dateien bitgleich – gemessen.
9. **Keine neuen Konfigurationsschlüssel**: `audio.modern` gehört in diesem Schub anderen Paketen; die Werte der
   Stinger-Absenkung stehen im Code und werden aus `audio.modern.music` gelesen, sobald jemand sie dort einträgt.
10. **UI-Klänge im Ordner `ui/` mit den Namen des `AudioManager`**: `ui_move`, `ui_ok`, `ui_back` wirken ohne eine
    Zeile Code (SfxBank nimmt die Modern-Datei, sobald das Manifest sie nennt). `ui_tab`, `ui_toggle`, `ui_error` gibt
    es als Klänge; aufrufen muss sie die UI (gehört UI1/UI2).

## 5. Ehrliche Einschätzung: was der Spieler hören wird

**Was gemessen gut ist**

- Die Technik der neuen Stücke ist so sauber wie bei „Linke Spur“: −14,2 LUFS, True Peak nach Vorbis −1,5 bis
  −1,8 dBTP, Schleifen ohne messbaren Sprung, der Schluss auf dem Taktstrich ohne Lücke und ohne doppelten Schlag –
  auch die Varianten Rekord und Finale (Abschnitt 3).
- Die Noten stimmen mit der Partitur überein (89–93 % der Takte, der Rest sind Farbakkorde), die Tonarten werden
  erkannt, alle 15 Zusatzclips stehen in der Tonart ihres Stücks.
- Die Klangbalance der neuen Rennstücke liegt in jedem Band höchstens 1 dB neben „Linke Spur“, deren Stil der Nutzer
  bestätigt hat – dieselben Instrumente, dieselbe Misch- und Master-Kette. Der Markenklang ist also messbar derselbe;
  ob die Stücke auch so *wirken*, ist eine andere Frage (unten).
- Das Profil Arcade spielt nichts Neues (geprüft: kein Modern-Klang geladen, auch nach Stinger-Ereignissen und
  UI-Klängen).

**Was niemand weiß, weil niemand es gehört hat**

- Ob die Melodien tragen, ob „Nachtfahrt“ mit ihrem Halbtakt-Groove dunkel-spannend oder eher träge wirkt (105 bpm
  ist das langsamste der drei Tempi) und ob „Rückenwind“ mit 150 bpm treibt oder hetzt. Das lässt sich nicht messen.
- Wie Ziel-Schlag und Stinger im Rennen gegen Motor, Wind und Sirene wirken: Ihre Dateipegel sind gemessen (−15 bis
  −19 LUFS, also etwa 4–8 dB über dem um 9 dB abgesenkten Stück – abgeleitet), die ganze Kette mit dem Auto nicht
  (gehört AU-E). Die Szene in `stinger_im_rennen_….mp3` ist ohne Auto gemischt. „Tank leer“ ist der leiseste Clip
  (ein seufzender Abstieg, −18 bis −19 LUFS) – vielleicht zu leise.
- Ob der Hook der Titelmelodie im Zwischenspiel nach vielen Etappen nervt (die Schleife ist 76,8 s lang).
- Wie die UI-Klänge neben der Menümusik wirken (Pegel abgeleitet, nicht in der Kette gemessen) und ob sie zu
  „musikalisch“ sind – sie sind aus dem gezupften Synth und der Glocke der Musik gebaut.

**Was bekannt nicht gut ist**

- „Linke Spur“ behält das leise Knacken am Ende der weichen Lead-Phrasen (Breakdown, Kehre; der Ausklang endet
  34 dB unter der Spitze der Phrase abrupt), weil ihre Hauptdatei bitgleich zu den Hörproben bleiben sollte, die der
  Nutzer heute Abend hört. In den neuen Stücken und allen Zusatzclips ist es behoben; für Stück 1 ist es eine Zeile
  beim nächsten Rendering.
- Mit dem Regler „Musik“ auf 0 ist das Ziel im Profil Modern still – der Zielklang ist jetzt Musik.
- `ui_tab`, `ui_toggle`, `ui_error` klingen erst, wenn die UI sie aufruft (UI2).
- Ein Rennen hört drei Stücke reihum: Ab der vierten Etappe wiederholt sich die Musik (Stücke 4–5 nicht gebaut).

## 6. Abweichungen vom Vertrag und vom Auftrag

- **Tempi**: geplant waren 112 / 144 / 96 bpm (Nachtfahrt, Rückenwind, Zwischenspiel), geliefert 105 / 150 / 100 bpm –
  nur diese Tempi geben eine exakte Schleife (Entscheidung 6, Falle 14.13.12).
- **Stinger „Etappenziel“, „Rekord“, „Meisterschaft“** sind keine Einzelklänge über der laufenden Musik, sondern
  der Ziel-Schlag (Einzelklang) plus drei Schluss-Varianten im `AudioStreamInteractive` (Entscheidung 3); ohne
  laufendes Stück sind die Varianten selbst die Einzelklänge. „Erwischt“ und „Tank leer“ sind Einzelklänge über dem
  um 9 dB abgesenkten Stück, wie verlangt.
- **Der Jingle „finish“ entfällt im Profil Modern** (der Director beansprucht `stage_finish`, Entscheidung 2).
- **Ergebnisbildschirm**: spielt das Zwischenspiel statt des Titel-Remasters, und erst nachdem der Schluss
  ausgeklungen ist (bis zu 10 s; Entscheidung 4, 7).
- **UI-Klänge `ui_tab`, `ui_toggle`, `ui_error`** sind gebaut, aber nicht verdrahtet: Die UI ruft heute nur
  `ui_move`, `ui_ok`, `ui_back`; die Dateien unter `scripts/ui/` gehören in diesem Schub UI1 (Vertrag A-8).
- **Fünf Testdateien von AU-A/AU-D1 angepasst**, deren Erwartungen das alte Verhalten festschrieben:
  `test_modern_audio.gd` (nach dem Ziel klingt der Schluss erst aus; `ui_move` kommt jetzt aus der Modern-Datei –
  den Rückfall auf den Arcade-Klang prüft der Test an `flash`, solange es dafür keine Modern-Datei gibt),
  `test_modern_assets.gd` (der Ordner `ui` hat mehr als den Platzhalter), `check_modern_audio.gd` (Zielklang: der
  Jingle oder – beansprucht – der Schluss), `test_music_director.gd` und `check_music.gd` (neue Stücke, Rotation,
  Varianten, Stinger, Zwischenspiel, Arcade).
- **`linke_spur.py` und `title_remaster.py` geändert** (gemeinsame Mischung, Zusatzclips): Hauptdatei und Schluss von
  „Linke Spur“ und das Titel-Remaster sind bitgleich geblieben (gemessen).

## 7. Vertragspunkte (contract issues)

1. D30 und der Auftrag verlangen Stinger als Einzelklänge „ducking the running music“ auch für Ziel, Rekord und
   Meisterschaft – im Ziel spielt aber das Rennstück schon seinen taktgenauen Schluss (AU-D1, D30); zwei Musiken
   übereinander passen weder zeitlich noch harmonisch. Gelöst mit Varianten des Schlusses (Entscheidung 3).
2. Der Vertrag (§6 Welle 6) gibt AU-D2 `assets/audio/modern/sfx/**`, der Auftrag verbietet es (gehört AU-C1). Die
   Stinger liegen deshalb im Ordner `music/` (Ogg, Rolle `race_ziel`/`race_ending`/`race_stinger`).
3. Die UI-Namen `ui_tab`, `ui_toggle`, `ui_error` brauchen Aufrufe in `scripts/ui/**` (UI1/UI2) und – für einen
   Arcade-Ersatz – Einträge in `SfxBank.ROUTES` / `AudioManager.ONESHOT_DB` (AU-E); beides außerhalb von AU-D2.
4. `audio_qc.py --determinism` läuft immer alle Generatoren eines Ordners (gemessen: 50 min für `music,ui`, davon
   39 min zweimal rendern); ein Filter je Generator fehlt (Werkzeug von AU-A).
5. Die QC-Grenze „Musik −14 ± 1 LUFS“ passt nicht auf Schlüsse und Stinger (sie tragen den Pegel ihres Stücks); sie
   haben eigene Grenzen im Manifest (`qc.lufs`), wie schon der Schluss von AU-D1.

## 8. Für die nächsten Pakete

- **UI2**: `UiKit.sound("ui/ui_tab")` beim Reiterwechsel der Optionen (LB/RB), `"ui/ui_toggle"` beim Ändern eines
  Werts (`option_row.gd`), `"ui/ui_error"` wo eine Eingabe nicht geht; für Arcade weiter `ui_move`/`ui_back`.
- **AU-E**: Stinger und Ziel-Schlag im Rennen mit der ganzen Kette messen (`capture_mix.gd`), die Absenkung
  (`sting_duck_db`, `sting_release_s`) gegebenenfalls in `audio.modern.music` setzen; eine ganze Etappe bis ins Ziel
  je Profil aufnehmen (Ziel-Schlag, Schluss-Variante, Ausklingen in den Ergebnisbildschirm).
- **Nutzerurteil**: Bass und Pegel ändert man in `tools/audio/music/mischung.json`, dann
  `python3 tools/audio/music/render_all.py` und `godot --headless --import` (etwa 25 Minuten). Bei diesem Lauf in
  `linke_spur.py` auch `race_lib.phrase_end()` auf die weiche Lead-Stimme anwenden (das Knacken, Doku 14.14) – die
  Bitgleichheit mit den Hörproben von AU-D1 zählt nach dem Urteil nicht mehr.
- **Stücke 4–5** (nur wenn alles andere fertig ist): eine neue Partitur-Datei nach dem Muster von `nachtfahrt.py`;
  Tempo nach `race_lib.check_tempo()`.

## 9. Dateien

Neu:
- `tools/audio/music/race_lib.py`, `nachtfahrt.py`, `rueckenwind.py`, `zwischenspiel.py`, `ui_klaenge.py`,
  `render_all.py`, `mischung.json`
- `assets/audio/modern/music/`: `nachtfahrt.ogg`, `rueckenwind.ogg`, `zwischenspiel.ogg`, je Stück `_schluss`
  (Nachtfahrt, Rückenwind), `_schluss_rekord`, `_schluss_finale`, `_ziel`, `_polizei`, `_tank` (alle drei Stücke) –
  mit `.import`
- `assets/audio/modern/ui/`: `ui_move_1.wav`, `ui_move_2.wav`, `ui_ok.wav`, `ui_back.wav`, `ui_tab.wav`,
  `ui_toggle.wav`, `ui_error.wav` – mit `.import`

Geändert:
- `scripts/audio/modern/music_director.gd` (Rotation, Zwischenspiel, Varianten, Ziel-Schlag, Stinger, Ausklingen)
- `tools/audio/music/music_lib.py` (gemeinsame Mischung, Mixer `fit`/`ref`, Master `post_at`/`state`, Sub-Faltung),
  `linke_spur.py` und `title_remaster.py` (gemeinsame Mischung, Zusatzclips; Ausgabe bitgleich), `check_music.py`
- `assets/audio/modern/music/manifest.json`, `assets/audio/modern/ui/manifest.json`
- `tests/unit/audio_modern/test_music_director.gd`, `check_music.gd`, `test_modern_audio.gd`,
  `test_modern_assets.gd`, `check_modern_audio.gd`
- `docs/audio-modern.md` (Abschnitt 14 neu, Zeilen in 1, 4.1, 7, 10, 12)

Nicht angefasst: die eingefrorenen Arcade-Werkzeuge und -Klänge, `tools/audio/music_synth.py`,
`assets/audio/modern/sfx/**` (AU-C1), `modern_audio.gd`, `sfx_bank.gd`, `audio_manager.gd`, `scripts/ui/**`,
`audio_qc.py`, `config/game_config.json`.

## 10. Gates (je einmal, am Ende, auf Commit 2f4f260)

| Gate | Ergebnis |
|---|---|
| `tools/run_tests.sh` (alles, `XDG_DATA_HOME` unter scratch, `nice -n 19`) | **grün**: 627 Tests, 0 fehlgeschlagen, alle Integrationsprüfungen OK („Tests bestanden“, 641 s) – darin `check_music.gd` (interactive, race, arcade, quit_menu, quit_race) |
| `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch“** (204 s) |
| `audio_qc.py --folders music,ui --determinism` | **grün**: 31 Klänge geprüft, 0 Fehler; jeder Generator zweimal byte-gleich (Platzhalter, Titel-Remaster, Linke Spur, Nachtfahrt, Rückenwind, Zwischenspiel, UI-Klänge); Musik 18,54 MB von 25 MB, Klänge 0,75 MB von 23 MB (50 min) |
| `check_music.py` (Noten, alle Stücke und Zusatzclips) | OK |
| Arcade spielt nichts Neues | `check_music.gd` arcade: kein ModernAudio, kein Modern-Bus, keine Datei aus `music/` oder `ui/` geladen – nach Menü, UI-Klängen, Rennkontext, Ereignissen mit `busted`/`out_of_fuel`/`stage_finish` und Zwischenspiel-Kontext; Menümusik die Titelmelodie von v0.7.0 |

Zwischendurch (vor den Gates): `run_tests.sh audio_modern` fand einen Fehler – `test_modern_audio.gd` erwartete für
`ui_move` noch den Arcade-Klang; behoben (Abschnitt 6), danach 14 von 14 und im Gesamtlauf grün.
