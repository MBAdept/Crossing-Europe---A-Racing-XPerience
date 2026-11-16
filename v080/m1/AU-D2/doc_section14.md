## 14. Musik (Pakete AU-D1, AU-D2)

Vertrag D26, D29, D30, §4.7, A-5. Alle Zahlen gemessen auf der Entwicklungsmaschine (Godot 4.7.2, ohne Bildschirm,
Dummy-Audiotreiber), sofern nicht „abgeleitet“ dasteht. **Wie die Musik klingt, hat hier niemand gehört** – das
beurteilt der Nutzer (Hörproben unter `<scratch>/v080/deliver/AU-D1/` und `<scratch>/v080/deliver/AU-D2/`). Der
Stil der ersten Hörproben (Rennstück 1, Titel-Remaster) ist vom Nutzer bestätigt („der Stil passt super“); Bass und
Pegel beurteilt er noch – dafür liegen alle Mischentscheidungen, die er ändern könnte, an einer Stelle (14.10).

### 14.1 Die Stücke

`assets/audio/modern/music/` (Manifest `manifest.json`, Rollen für den `MusicDirector`):

| Datei | Rolle | bpm | Länge | Schleife | Lautheit / True Peak (nach Vorbis) | Größe |
|---|---|---|---|---|---|---|
{TABLE}

Mit dem Platzhalter von AU-A zusammen {MUSIC_MB} MB von 25 MB Budget (§4.11). Alle Dateien tragen `bpm` und
`bar_beats` (in den Import-Einstellungen ebenso, `beat_count` 0). Über das Format hinaus: die Rennstücke `piece`,
`ending` (normaler Schluss), `endings` (`rekord`, `finale`), `ziel` (Schlag an der Ziellinie), `stingers` (`busted`,
`out_of_fuel`), `countin_beats`, `intro_bars`, `loop_bars`, `rotation` (Reihenfolge, 1 = erstes Stück einer Sitzung)
und `key`; Schlüsse und Stinger `piece`, `variant` bzw. `event` und `bars` (musikalische Länge, für die Absenkung
darunter); das Zwischenspiel `intro_bars`, `loop_bars`, `key`. Eigene QC-Grenzen der Lautheit: der normale Schluss
`[-20, -10]`, die Zusatzclips `[-30, -10]` – sie werden mit dem Master und den Spurpegeln ihres Stücks bearbeitet und
nicht für sich auf −14 LUFS gebracht, sonst spränge der Pegel am Übergang.

### 14.2 Die Kette (`tools/audio/music/`)

| Datei | Inhalt |
|---|---|
| `music_lib.py` | die Produktionsschicht über dem eingefrorenen `tools/audio/music_synth.py` (importiert, nie geändert): Sub-Kick- und Snare-Ebenen, Shaker, Sub-Bass, zwei Supersaw-Leads für die Breite, neue Platte und Halle; `Mixer` (eine Spur nach der anderen in Busse und Sends; zeichnet seine Pegelentscheidungen als `fit` auf und mischt mit `ref` eine andere Zeitleiste genau damit); `Master` (EQ, drei Bänder bei 140 Hz und 3,2 kHz, Kleber, M/S, Lautheit, Soft-Clip, True-Peak-Begrenzer) mit `pre()`/`fit_gain()`/`post()`/`post_at()`; `encode_checked()` schreibt Vorbis q5 bitgenau, dekodiert und misst – liegt der True Peak nach der Kodierung über −1,08 dBTP, sinkt die Grenze des Begrenzers und die Datei wird neu geschrieben; `write_ogg_import_keep()`; `prefs()`/`apply_prefs()` (14.10); Chroma, Dreiklang, Tonart für die Prüfung |
| `mischung.json` | die gemeinsamen Mischentscheidungen aller Stücke (14.10) |
| `race_lib.py` | die gemeinsame Rennstück-Kette (AU-D2): Voicings für jede Tonart nach den Regeln von „Linke Spur“, Zeitleiste, Render-Schleife, `RacePiece` (Hauptdatei mit Einzähler, Schleife, Schluss, Import, Manifest) und `Extras` (Zusatzclips, 14.7) |
| `title_remaster.py` | das Titel-Remaster (14.3) |
| `linke_spur.py` | Rennstück 1 (14.4) und seine Zusatzclips |
| `nachtfahrt.py`, `rueckenwind.py` | Rennstücke 2 und 3 (14.5, 14.6) und ihre Zusatzclips |
| `zwischenspiel.py` | das Zwischenspiel (14.8) |
| `ui_klaenge.py` | die UI-Klänge (14.9, schreibt nach `assets/audio/modern/ui/`) |
| `render_all.py` | alle Generatoren nacheinander (nach einer Änderung von `mischung.json`) |
| `check_music.py` | die Noten-Prüfung (14.12) |

```
python3 tools/audio/music/render_all.py                  # alle Stücke und UI-Klänge ins Repository (etwa 25–27 min)
python3 tools/audio/music/title_remaster.py              # 264–295 s auf einem Kern (gemessen)
python3 tools/audio/music/linke_spur.py                  # 330–407 s mit den Zusatzclips (gemessen)
python3 tools/audio/music/nachtfahrt.py                  # 400–447 s (gemessen)
python3 tools/audio/music/rueckenwind.py                 # 305–337 s (gemessen)
python3 tools/audio/music/zwischenspiel.py               # 76–81 s (gemessen)
python3 tools/audio/music/ui_klaenge.py                  # wenige Sekunden
python3 tools/audio/music/nachtfahrt.py --info           # Form, Clip-Längen (jedes Rennstück)
python3 tools/audio/music/nachtfahrt.py --sketch 16 --wav /tmp/x   # Einzähler + 16 Takte
python3 tools/audio/music/check_music.py [--only nachtfahrt] [--music <Ordner eines --out-Laufs>]
python3 tools/audio/qc/audio_qc.py --folders music,ui --determinism
```

Jeder Generator nimmt `--out <Ordner>` (dann ohne Import-Dateien; so ruft `audio_qc.py --determinism` ihn zweimal
auf) und `--wav <Ordner>` (zusätzlich der ganze Master als Float-WAV für Hörproben; `ui_klaenge.py` legt dort eine
Hörprobe aller Klänge ab). Feste Seeds, kein Zeitstempel, Vorbis über ffmpeg mit den Bitexakt-Schaltern: zwei Läufe
schreiben dieselben Bytes. Danach `godot --headless --import`.

{TITLE_PART}
{LS_PART}
**Seit AU-D2** schreibt `linke_spur.py` nach Hauptdatei und Schluss auch die Zusatzclips (14.7) in d-Moll; Hauptdatei
und Schluss sind dabei bitgleich geblieben (sha256 nach dem neuen Rendering gleich). Rotation 1: das erste Rennstück
einer Sitzung.

### 14.5 Rennstück 2 „Nachtfahrt“

Das dunkle der drei Rennstücke: c-Moll, 105 bpm (1 Takt = 16/7 s, eine Sechzehntel genau 6300 Frames), eine
Nachtfahrt im Markenklang. Wo „Linke Spur“ (d-Moll, 132 bpm) auf vier Vierteln rollt, pulsiert dieses: Halbtakt-Groove
in den Strophen (Kick auf 1 und auf „und“ von 3, große Snare mit Gate-Hall auf 3, Sechzehntel-Hi-Hats), ein
sequenzierter Sechzehntel-Synth-Bass mit Oktavsprüngen (der Sub folgt den Vierteln), ein hypnotisches Arpeggio
(Grundton – Quinte – Spitze – Terz) über weiten Flächen mit Farbakkorden (Cm9, A♭maj7, E♭add9, Fm7, B♭add9), sparsame
dunkle Gitarren, das Motiv auf der weichen Lead-Stimme und ein hoher Hook über ♭VI – ♭III – ♭VII – i.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | G | Hi-Hats schwellen an, Toms, Riser – keine Kicks neben den Countdown-Pieptönen |
| A1 | 8 | c A♭ f G c A♭ f G | Halbtakt-Groove, Synth-Bass, Arpeggio; Motiv (weiche Lead) ab Takt 5 |
| B1 | 8 | A♭ E♭ B♭ c A♭ E♭ B♭ G | Hook mit Supersaw-Dopplung, Vierviertel-Kick, Gitarrenwand |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre, Shaker, gedämpfte Gitarren |
| C1 | 8 | f f A♭ A♭ B♭ B♭ G G | Aufstieg: Toms, Bläser-Stöße, gedämpfte Sechzehntel, Snare-Wirbel |
| B2 | 8 | wie B1 | Hook mit Harmonie, Leadgitarre eine Oktave tiefer |
| D | 8 | A♭ E♭ f c A♭ E♭ f G | Breakdown: FM-Glocken über dem Arpeggio, weiche Melodie |
| S | 8 | c A♭ E♭ B♭ c A♭ f G | Gitarrensolo |
| C2 | 8 | wie C1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem: Harmonie, Gitarre, Bläser |
| T | 8 | c c A♭ A♭ f f G G | Kehre im Halbtakt, Tom-Wirbel in A1 |
| Schluss | 2 + Nachklang | A♭ – B♭ – c | Schläge, Tom-Wirbel, Schlussakkord Cm9 mit Lead auf es''' |

`nachtfahrt.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (80 Takte = 182,86 s, 8 064 000 Frames) –
dieselbe Bauart wie „Linke Spur“ (die Naht liegt in A1 → B1; der zweite Durchgang weicht vom ersten um −186,7 dBFS
ab, gemessen vor der Kodierung). Bis zur ersten Wiederholung 203,4 s. Rotation 2.

### 14.6 Rennstück 3 „Rückenwind“

Das helle der drei: A-Dur, 150 bpm (1 Takt = 1,6 s, eine Sechzehntel genau 4410 Frames), aufbrechender
Synthwave-Rock. Gegen „Linke Spur“ und „Nachtfahrt“: Dur, das schnellste Tempo, ein Disco-Rock-Beat (Kick auf allen
Vierteln, offene Hi-Hats auf den Achtel-Nachschlägen), Oktav-Achtelbässe, Gitarren im 3-3-2-Rhythmus des Markenklangs,
ein funkelndes aufsteigendes Arpeggio, der heroische Aufstieg ♭VI – ♭VII – I (F – G – A) und ein Hook, der bis zum
hohen a''' steigt.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | E | Claps schwellen an, Snare-Wirbel, Riser |
| A1 | 8 | A E f♯ D A E D E | Groove, Gitarren 3-3-2, Motiv ab Takt 5 |
| B1 | 8 | D E c♯ f♯ D E A E | Hook mit Supersaw-Dopplung, Crash alle zwei Takte |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre |
| P1 | 8 | F G A A F G E E | Aufstieg ♭VI – ♭VII – I, Bläser, Tom-Groove |
| B2 | 8 | wie B1 | Hook mit Harmonie, Leadgitarre eine Oktave tiefer |
| D | 8 | f♯ D A E f♯ D E E | Breakdown: Glocken, weiche Melodie |
| S | 8 | wie A1 | Gitarrensolo |
| P2 | 8 | wie P1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem |
| A3 | 8 | wie A1 | Motiv und Antwort in Oktaven |
| T | 8 | A A D D f♯ f♯ E E | Kehre: Halbtakt, dann 3-3-2 |
| Schluss | 2 + Nachklang | F – G – A | Schläge, Tom-Wirbel, Schlussakkord Aadd9 mit Lead auf cis''' |

`rueckenwind.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (88 Takte = 140,8 s, 6 209 280 Frames;
Naht −175,7 dBFS, gemessen). Bis zur ersten Wiederholung 155,2 s. Rotation 3.

**Gemessen an beiden Stücken**: Lautheit und True Peak in 14.1; die Klangbalance (Langzeitspektrum in acht Bändern
von 25 Hz bis 18 kHz, bezogen auf die Gesamtenergie) liegt in jedem Band höchstens 1,0 dB von „Linke Spur“ entfernt
(Nachtfahrt: tiefe Mitten +1,0 dB, Bass −0,5 dB; Rückenwind: Mitten bis Luft +0,7 bis +0,8 dB). Noten
(`check_music.py`): „Nachtfahrt“ Grundton in 83 von 89 Takten wie in der Partitur (93,3 %), Tonart c-Moll; „Rückenwind“
in 87 von 97 Takten (89,7 %), Tonart A-Dur – die übrigen sind Farbakkorde und Obertöne (Falle 15).

### 14.7 Schlüsse, Ziel-Schlag und Stinger

Jedes Rennstück hat fünf Zusatzclips in seiner Tonart, gespielt von seinen eigenen Instrumenten (`race_lib.Extras`,
eine Partitur für jede Tonart und jedes Tempo):

| Clip | Takte | Inhalt | wann |
|---|---|---|---|
| `<stück>_ziel` | 1 | Schlag auf der Tonika: Kick, Crash, Snare, Clap, Impact, Gitarren- und Bläserakkord, ein kurzes Quint-Oktav-Motiv | sofort an der Ziellinie, über der abgesenkten Schleife – nur wenn der Taktstrich des Schlusses mehr als 0,3 s entfernt ist |
| `<stück>_schluss_rekord` | 3 | der Schluss (Kadenz – Tonika) mit einer Fanfare im 3-3-2-Rhythmus die Tonika hinauf, Glocken | neuer Rekord: am nächsten Taktstrich statt des normalen Schlusses |
| `<stück>_schluss_finale` | 4 | die Kadenz zweimal (beim zweiten Mal höher, mit Snare-Wirbel), dann die **Dur**-Tonika mit Fanfare auf ihrer Terz (Moll-Stücke enden picardisch in Dur: d → D, c → C) | letzte Etappe eines Rennens: am nächsten Taktstrich |
| `<stück>_polizei` | 3 | „Erwischt“: Schläge auf i – ♭II (phrygisch) – i, dann ein chromatischer Fall von der Quinte zum Grundton, Tom-Wirbel, Schlussschlag | Ereignis `busted`, auf dem nächsten Schlag |
| `<stück>_tank` | 2 | „Tank leer“: ein seufzender chromatischer Abstieg, dann sinkt der Grundton um eine Oktave; das Arpeggio geht aus | Ereignis `out_of_fuel`, auf dem nächsten Schlag |

Dur-Stücke („Rückenwind“) leihen sich für die Stinger das gleichnamige Moll (a-Moll, ♭II = B, iv = d). **Gleicher
Klang, gleicher Pegel wie das Stück**: Die Zusatzclips werden nach der Hauptdatei auf einer eigenen Zeitleiste
gerendert (je Clip gefolgt von vier leeren Takten, damit kein Hall in den nächsten reicht) und mit den Spurpegeln des
Stücks gemischt (`Mixer(ref=fit)`: Normierung, Kompressorschwellen, Sättigungsbezug, Schlagzeugbus aus dem Rendering
des Stücks) und mit seinem gemessenen Master bearbeitet (`Master.post`); ein Clip, dessen True Peak nach Vorbis zu
hoch läge, bekommt nur für sich eine tiefere Begrenzergrenze. So bleibt die Hauptdatei von „Linke Spur“ bitgleich,
und ihre Zusatzclips klingen trotzdem wie sie.

### 14.8 Zwischenspiel

Die ruhige Schleife der Bildschirme zwischen den Etappen (Kontext `race_menu`, und `result`, solange es kein eigenes
Stück gibt): e-Moll wie die Titelmelodie, 100 bpm (1 Takt = 2,4 s, eine Sechzehntel 6615 Frames), im Markenklang,
aber leise gespielt – Flächen (Em9, Cmaj7, Gadd9, Am7, B7), FM-Glocken, ein weiches Achtel-Arpeggio, eine cleane
Gitarre (das Saitenmodell ohne Verstärker), ein runder Synth-Bass, ein weicher Halbtakt-Beat ohne Crash und Impact.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| T (Intro) | 2 | a H | die Kehre der Schleife, einmal |
| A | 8 | C G D e C G a H | eine eigene Glockenmelodie über den Flächen |
| B | 8 | e C G D e C G D | **der Hook der Titelmelodie** auf der weichen Lead-Stimme (Wiedererkennung), Arpeggio, Shaker |
| A' | 8 | wie A | die Glockenmelodie auf der weichen Lead eine Oktave tiefer, cleane Gitarre |
| B' | 6 | e C G D e C | der Hook mit Harmonie, cleane Gitarre |
| T | 2 | a H | Kehre, Tom-Auftakt in A |

`zwischenspiel.ogg`: das Intro (= die letzten zwei Takte der Schleife) einmal, dann 32 Takte = 76,8 s
(3 386 880 Frames) in Schleife bis zum Dateiende; die Naht liegt in der Musik (zweiter Durchgang −112,9 dBFS vom
ersten entfernt – der Ausklang der Echos, unhörbar; gemessen). Datei auf −14 LUFS wie jedes Stück;
im Spiel bringt die Kette (Kontext `race_menu` −1 dB, Regler) es auf die Menü-Lautheit von −20 LUFS (abgeleitet wie
beim Titel, 6.1). Vom Ergebnisbildschirm zum Etappenbildschirm läuft es ohne Neustart weiter.

### 14.9 UI-Klänge

`assets/audio/modern/ui/` (Generator `tools/audio/music/ui_klaenge.py`): weiche Menüklänge im Markenklang – der
gezupfte Synth und die FM-Glocke der Musik, e-Moll-Pentatonik (die Tonart von Titel und Zwischenspiel unter den
Menüs), ein Hauch der Platte der Musik-Kette; 16-Bit-WAV, 44,1 kHz Stereo, je auf eine eigene Momentanlautheit
(400 ms) gebracht, True Peak höchstens −3 dBTP.

| id | Dateien | wofür | Lautheit / True Peak (Datei) | Größe |
|---|---|---|---|---|
{UI_TABLE}

Zusammen {UI_KB} kB (mit dem Platzhalter von AU-A). Pegel im Spiel (abgeleitet): `MUI` 0 dB, `MSfx` 0 dB,
Gesamtlautstärke 0,8 (−1,9 dB): „Bestätigen“ erreicht etwa −20 LUFS momentan – so laut wie die Menümusik integriert,
„Fokus“ etwa −25 LUFS; der Arcade-Klang „ui_ok“ liegt ebenso bei etwa −21 LUFS momentan (berechnet aus `SfxSynth`
und `ONESHOT_DB`).

**Verdrahtung**: `ui_move`, `ui_ok` und `ui_back` sind die Namen, die die Menüs heute spielen (`UiKit.sound()`,
`AudioManager.play()`): Mit dem Profil Modern nimmt `SfxBank` dafür die Datei aus `ui/` (`ROUTES`), `ui_move` mit zwei
Varianten reihum. `ui_tab`, `ui_toggle` und `ui_error` gibt es als Namen im Spiel noch nicht: Die UI spielt sie mit
`AudioManager.play("ui/ui_tab")` usw. (`SfxBank` nimmt „<Ordner>/<id>“; das Profil Arcade kennt die Namen nicht und
bleibt still) – offener Punkt für UI2 (14.14). Das Profil Arcade behält seine Klänge.

### 14.10 Gemeinsame Mischung (`tools/audio/music/mischung.json`)

Was der Nutzer am Klang noch ändern könnte, steht für alle Stücke an einer Stelle; jeder Generator liest die Datei.

| Schlüssel | wirkt auf | Standard |
|---|---|---|
| `sub_db` | Tiefbass: Sub-Bass unter der Basslinie und Sub-Kick (auf den Pegel jedes Stücks addiert) | 0 |
| `bass_db` | gezupfter Bass und Synth-Bass | 0 |
| `high_shelf_db`, `high_shelf_hz` | Höhen der Summe: ein Kuhschwanzfilter im Master (bei 0 dB gibt es keinen) | 0 dB, 6000 Hz |
| `race_music_db` | Musik im Rennen gegen das Auto: `gain_db` der Rennstücke, ihrer Schlüsse und Stinger | 0 |
| `menu_music_db` | `gain_db` von Titel-Remaster und Zwischenspiel | 0 |
| `ui_db` | `gain_db` der UI-Klänge | 0 |

Nach einer Änderung: `python3 tools/audio/music/render_all.py` (alle Stücke, etwa 25 Minuten auf einem Kern), dann
`godot --headless --import`. Die drei `*_music_db`/`ui_db` brauchen kein neues Klangrendering, nur die
Manifest-Einträge – der Lauf schreibt sie. Bei allen Werten 0 schreiben die Generatoren die Dateien vom 11.11.2026
bitgleich (gemessen: Titel-Remaster und „Linke Spur“ nach dem Umbau mit gleicher sha256).

### 14.11 Der `MusicDirector`

| Kontext | Stück |
|---|---|
| `title`, `menu` | Rolle `title`: das Titel-Remaster (ohne Modern-Datei die Titelmelodie von heute) |
| `race_menu` | Rolle `interlude`: das Zwischenspiel (ohne es das Titel-Remaster) |
| `result` | Rolle `result`; ohne eigenes Stück das Zwischenspiel, dann das Titel-Remaster |
| `race` | ein Rennstück (Rolle `race`, reihum eins je Etappe in der Reihenfolge `rotation`: Linke Spur, Nachtfahrt, Rückenwind, …) |
| `off` | Stille |

Das Rennstück und die Etappe:

| Phase | wann | was |
|---|---|---|
| `armed` | `set_music_context("race")` – jede Etappe, auch ein Neustart | die Menümusik blendet aus, das nächste Stück der Rotation wartet |
| `waiting` | Ereignis `stage_start` {countdown_s} | Start in countdown_s − Einzähler; jede Countdown-Zahl (`countdown` {n}) verankert neu: Start in n − Einzähler |
| `playing` | der Start ist da (das Bild, das dem geplanten Moment am nächsten liegt), `go` ohne `stage_start`, oder 0,5 s Fahrt ohne jedes Ereignis (Werkzeuge) | `play()` des `AudioStreamInteractive`; der erste Schlag nach dem Einzähler fällt auf „LOS!“ |
| `ending` | `stage_finish` {record, last_stage} | der Schluss am nächsten Taktstrich: `finale` auf der letzten Etappe, sonst `rekord` bei neuem Rekord, sonst der normale; davor sofort der Ziel-Schlag, wenn der Taktstrich mehr als 0,3 s entfernt ist |
| `over` | `stage_finish` ohne spielendes Stück („Musik im Rennen: Aus“ oder vor dem Start) | der passende Schluss sofort als Einzelklang – der Zielklang der Etappe |

- **Das Ziel gehört der Musik**: Der Director beansprucht `stage_finish` (`claims()`, nur wenn ein Rennstück Schlüsse
  hat) – der „finish“-Jingle des `AudioManager` (C-Dur-Arpeggio) entfällt in diesem Moment (Abschnitt 7) und klingt
  nicht gegen den Schluss in d-Moll, c-Moll oder A-Dur. Folge: Mit dem Regler „Musik“ auf 0 ist das Ziel im Profil
  Modern still (der Zielklang ist Musik).
- **Der Schluss klingt aus**: Verlässt das Spiel die Etappe in einen Menü-Kontext (Ergebnisbildschirm 6 s nach dem
  Ziel), spielt der Schluss weiter, bis er bis auf 1,2 s ausgeklungen ist (höchstens 10 s); erst dann blendet das
  Zwischenspiel ein. Ein Kontext außerhalb der Menüs (`off`, `race`) beendet das sofort.
- **Stinger**: `busted` und `out_of_fuel` spielen den Stinger des laufenden Stücks auf dem nächsten Schlag auf einem
  eigenen Player (`MusicSting` auf `MMusic`); das Rennstück sinkt darunter um `sting_duck_db` (−9 dB, Attack 50 ms),
  hält die musikalische Länge des Stingers und kommt in `sting_release_s` (1 s) zurück. Nur solange das Stück spielt
  (Stinger sind Musik): ohne „Musik im Rennen“, vor dem Start und nach dem Ziel keine. Beide Werte liest der Director
  aus `audio.modern.music`, falls jemand sie dort einträgt (heute steht dort keiner – Standardwerte im Code).
- **Die Taktuhr** `music_t`: Sekunden, die der Stream spielt – auch in der Pause nach „LOS!“, in der die Musik nur
  gefiltert weiterläuft (die Spielzeit-Uhr `race_t` steht dort). Aus ihr folgen der nächste Taktstrich (Ziel-Schlag)
  und der nächste Schlag (Stinger); das Taktraster beginnt mit Frame 0 der Datei, die Schleife ist ganze Takte lang.
- Weiter wie bei AU-D1: **Uhr des Starts** (Physikschritte), **Pause im Einzähler**, **„Musik im Rennen: Aus“** (das
  Stück bleibt still; wieder an, beginnt es mit seinem Einzähler), **Platzhalter** nur ohne echtes Stück, **Pegel**
  `context_db` + `gain_db`, **Ende** (`teardown()` gibt alle drei Player frei).

### 14.12 Prüfungen

| Datei | prüft |
|---|---|
| `tests/unit/audio_modern/test_music_director.gd` | ohne Szenenbaum: Stücke je Kontext, das Zwischenspiel (race_menu, result, ohne Neustart zwischen beiden), Start und „LOS!“, Rotation der drei Stücke (Einzähler je Tempo, Schlüsse, Stinger), Neuverankerung, kurzer Countdown, `go`, Start ohne Ereignisse, Ziel mit Ausklingen in den Ergebnisbildschirm, Neustart, Ziel vor dem Start (Schluss als Zielklang), Schluss-Varianten und Ziel-Schlag (nur fern vom Taktstrich, Absenkung bis zum Taktstrich), Stinger auf dem Schlag mit Absenkung und Rückkehr, keine Stinger ohne Rennmusik oder nach dem Ziel, Ziel ohne Rennmusik, „Musik im Rennen“, Pause im Einzähler, die Taktuhr in der Pause, der gebaute `AudioStreamInteractive` (vier Clips), Platzhalter |
| `tests/unit/audio_modern/check_music.gd` | eigene Prozesse: **interactive** – jedes Rennstück offline in 512er-Schritten wie der Mischer: die ganze Hauptdatei Frame für Frame, nach dem Dateiende Abweichung 0 zum ersten Durchgang, der normale Schluss nach der Schleife am Taktstrich (höchstens 3 ms davor), ohne Lücke, ohne doppelten Schlag; die Varianten `rekord` und `finale` (Nachtfahrt, im ersten Durchgang) ebenso; die Naht des Zwischenspiels (gemessen: alle Schlüsse 2,90–2,93 ms vor dem Taktstrich, ohne Lücke, erste 100 ms −0,04 bis +0,01 dB gegenüber dem Clip allein); **arcade** – wie bei AU-D1, dazu nach den Ereignissen `busted`, `out_of_fuel`, den UI-Klängen und dem Kontext `race_menu`: keine Datei aus `music/` oder `ui/` geladen; **race**, **quit_menu**, **quit_race** wie bei AU-D1 |
| `tests/unit/audio_modern/test_music_checks.gd` | startet `check_music.gd` (so deckt `tools/run_tests.sh` es ab) |
| `tools/audio/music/check_music.py` | Noten: Titel gegen Original; jedes Rennstück gegen seine Partitur (Grundton je Takt oder ein Dreiklang aus den Tönen des gespielten Farbakkords), Tonart, Schluss; die Zusatzclips (Ziel-Schlag auf der Tonika, Rekord auf der Tonika, Finale in Dur, Stinger in der Moll-Tonart des Stücks) |
| `tools/audio/qc/audio_qc.py` | Dateien, Pegel, Nähte, Import, Größe; `--determinism` |

{OLD_TRAPS}12. **Tempo und Schleife** (AU-D2): Damit die zwei Durchgänge über den Schleifenbeginn gleich sind, braucht ein
    Stück zwei Dinge. (a) Eine Sechzehntel ist eine ganze Zahl von Frames – bei 112 und 144 bpm (5906,25 / 4593,75
    Frames) lagen Einsätze auf halben Frames und rundeten im ersten und im zweiten Durchgang verschieden: die
    Fortsetzung wich vom Schleifenbeginn um −30 dBFS ab (gemessen; die Lead-Noten ab dem zweiten Ton jedes Takts um
    einen Frame verschoben). (b) Die Schleife ist ein Vielfaches von 63 Frames: Der eingefrorene Kompressor
    (`music_synth.compressor_gain`) misst den Pegel in Blöcken zu 63 Frames ab Frame 0 – sonst liegt das Raster in
    beiden Durchgängen anders und die Kompressoren regeln um etwa 0,1 dB verschieden (gemessen bei 108 bpm: −34 dBFS
    über die ganze Schleife). Beides erfüllen 100, 105, 125, 140, 150 bpm für jede Taktzahl (eine Sechzehntel ist ein
    Vielfaches von 63 Frames); `race_lib.check_tempo()` lehnt andere Tempi ab. „Linke Spur“ (132 bpm, Schleife
    7 056 000 = 63 × 112 000 Frames) trifft nie genau einen halben Frame und ist exakt (−172 dBFS).
13. **Sub-Faltung** (AU-D2): `sub_bass` faltet in 36–75 Hz; in c-Moll und A-Dur landen F und E dabei bei 42–44 Hz –
    im 40-Hz-Terzband +5,8 / +6,3 dB gegenüber „Linke Spur“ (gemessen). Die neuen Stücke falten in 45–94 Hz
    (`RacePiece.SUB_FOLD`); Titel und „Linke Spur“ bleiben bei 36 Hz (bitgleich).
14. **Ende einer Synth-Phrase** (AU-D2): `music_synth.synth_lead` rendert eine Phrase bis 0,6 s nach ihrer letzten
    Note und schneidet dort ab. Mit dem Patch „soft“ (Ausklang 0,16 s) liegt der Ausklang an der Schnittstelle noch
    34 dB unter der Spitze der Phrase (gemessen; „lead“: −63 dB) – ein leises Knacken in ruhigen Stellen.
    `race_lib.phrase_end()` blendet die letzten 60 ms aus (alle Stücke über `race_lib`, das Zwischenspiel); die
    Hauptdatei von „Linke Spur“ behält es (bitgleich zu AU-D1, offener Punkt). Dieselbe Länge (`int` einer
    Fließkomma-Zeitspanne) kann in zwei Durchgängen um einen Frame verschieden sein – endet eine Phrase nach dem
    Schleifenpunkt, weicht die Naht dort um einen Frame ab (Zwischenspiel vor der Korrektur: −67 dBFS, danach
    −112,9 dBFS).
15. **Akkorderkennung der Prüfung** (AU-D2): Farbakkorde (A♭maj7 enthält c-Moll, Cm9 enthält E♭-Dur) und die dritte
    Harmonische der Quinten im Bläser- und Gitarrenakkord (D4 → A5) ziehen die Chroma zum Nachbar-Dreiklang. Die
    Prüfung zählt deshalb einen Dreiklang aus den Tönen des gespielten Akkords als Treffer, beurteilt beim Schluss
    den ersten Akkord und die Tonika und bei den Stingern die Tonart.

### 14.14 Offene Punkte

- **Hören**: „Nachtfahrt“, „Rückenwind“, Zwischenspiel, Schlüsse, Stinger und UI-Klänge muss der Nutzer beurteilen
  (Hörproben `<scratch>/v080/deliver/AU-D2/`). Bass und Pegel ändert `mischung.json` für alle Stücke zugleich (14.10).
- **UI2**: `ui_tab` (Reiter LB/RB der Optionen), `ui_toggle` (Wert einer Optionszeile) und `ui_error` (nicht möglich)
  aufrufen – Vorschlag: `UiKit.sound("ui/ui_tab")` usw. an den Stellen, die heute `ui_move` spielen, und für Arcade
  dort weiter `ui_move` (das Profil Arcade kennt die neuen Namen nicht). Sauberer wäre ein Eintrag in
  `SfxBank.ROUTES` und `AudioManager.ONESHOT_DB` (Ersatz: der Arcade-Klang `ui_move` bzw. `ui_back`) – das gehört
  AU-E bzw. dem Eigentümer des `AudioManager`.
- **AU-E**: die Stinger im Rennen mit der ganzen Kette messen (`capture_mix.gd`), `sting_duck_db`/`sting_release_s`
  gegebenenfalls in `audio.modern.music` eintragen; ob der Ziel-Schlag mit echtem Treiber auf den Taktstrich passt
  (die Taktuhr zählt ab `play()`, die Ausgabe beginnt eine Treiberportion später – abgeleitet: Absenkung endet bis zu
  einer Portion zu früh).
- **Beenden des Spiels** (UI / AU-E): `GameFlow.quit_game()` sollte den Klang anhalten und 0,3 s warten, bevor es
  `quit()` ruft (Falle 10) – betrifft beide Profile.
- **`capture_mix.gd --scenario=race_music`** sendet kein `stage_start` (AU-D1) – für das Leerlauf-Ziel nicht
  vergleichbar.
- **QC-Regel und Godot**: `audio_qc.py` vergleicht `beats` mit der Schleifenlänge, Godot zählt `beat_count` vom
  Dateianfang (Falle 5).
- **„Linke Spur“, Hauptdatei**: Die weiche Lead-Stimme (Breakdown D, Kehre T) endet je Phrase mit dem leisen Schnitt
  von Falle 14.13.14. Beim nächsten Rendering von Stück 1 (etwa nach dem Urteil des Nutzers zu Bass und Pegel) lässt
  sich das in `linke_spur.py` mit `race_lib.phrase_end()` beheben – dann ist die Datei nicht mehr bitgleich zu den
  Hörproben vom 11.11.2026, darum ist es heute nicht geschehen.
- **Stücke 4–5**: nur, wenn alles andere fertig ist (Vertrag D30); `race_lib.RacePiece` macht ein weiteres Stück zu
  einer Partitur-Datei (Muster: `nachtfahrt.py`).
