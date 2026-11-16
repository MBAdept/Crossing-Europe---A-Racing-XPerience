# AU-D1 – Musik-Kette, Titel-Remaster, Rennmusik 1 „Linke Spur“, MusicDirector

Paket AU-D1 (Vorstart von M2, Welle 4 des Bauplans). Branch `worktree-wf_158edd89-079-1`, gesichert als
`origin/wip/v080-au-d1`, Basis 3b89a33 (Kopf von UI1). Alle Zahlen **gemessen** auf dieser VM (Godot 4.7.2 ohne
Bildschirm, Dummy-Audiotreiber, ffmpeg/numpy), sofern nicht **abgeleitet** dasteht. **Niemand hier hat die Musik
gehört** – Klang und Mischung muss der Nutzer beurteilen; ich beurteile nur, was sich messen lässt.

## 1. Für den Nutzer: die Hörproben (in diesem Ordner)

| Datei | Inhalt |
|---|---|
| `rennmusik_linke_spur_skizze_45s.mp3` | Rennstück 1 allein, die ersten 45 s: Einzähler (1 Takt), A1 (Groove + Motiv), B1 (der Hook der Skizze), Anfang A2 |
| `rennmix_linke_spur_unter_motor.mp3` | dieselbe Musik im Spiel unter dem Motor (Gran Turismo), 47 s aus dem Spiel aufgenommen: 3 s Leerlauf, Vollgas durch die Gänge, Höchsttempo, Gas weg, 130 km/h |
| `rennmusik_linke_spur_komplett_mit_schluss.mp3` | das ganze Stück, wie ein Rennen es spielt: Einzähler und A1, einmal die Schleife (88 Takte), dann der Schluss am Taktstrich – 3:04 |
| `titel_ab_erst_alt_dann_remaster.mp3` | Titelmelodie 1:00–1:32 (Pre-Chorus 1, Refrain 1): erst v0.5.0/v0.7.0, dann dieselben Takte als Remaster |
| `titel_remaster_komplett.mp3` | das ganze Titel-Remaster (3:22,5) |
| `rennmusik_linke_spur_spektrogramm.png` | Spektrogramm des ganzen Stücks mit Abschnitten |
| `titel_spektrogramm_alt_gegen_remaster.png`, `titel_terzspektrum_alt_gegen_remaster.png` | Titel alt gegen Remaster |
| `rennmix_lautheit.png`, `rennmix_ducking.png` | Lautheit von Auto + Musik und Musik allein über die Fahrt, Absenkung der Musik je Abschnitt |

Die MP3s haben die Pegel der Dateien (Musik −14 LUFS) bzw. des Spiels (Rennmix −16 LUFS), MP3 192 kbit/s.

## 2. Was gebaut ist

- **Musik-Kette** `tools/audio/music/`: `music_lib.py` (Produktionsschicht der Audio-Studie über dem eingefrorenen
  `music_synth.py`, inkrementeller Mixer, Master mit fit/apply, Vorbis q5 mit Messung *nach* der Kodierung und
  automatischer Nachregelung des Begrenzers, Import mit erhaltener uid), Generatoren `title_remaster.py` und
  `linke_spur.py` (`--out`, `--wav`, Skizzen), `check_music.py` (Noten/Tonart).
- **Titel-Remaster** `assets/audio/modern/music/titel_remaster.ogg`: gleiche Komposition (jedes Ereignis des
  Originals), neue Produktion; Rolle `title` → Titel und Menüs im Profil Modern.
- **Rennstück 1 „Linke Spur“** `linke_spur.ogg` (Einzähler + A1 einmal, dann 88 Takte Schleife) und
  `linke_spur_schluss.ogg`, d-Moll, 132 bpm, 2:56 bis zur ersten Wiederholung.
- **MusicDirector** `scripts/audio/modern/music_director.gd`: Kontexte, Rennstück mit Einzähler auf „LOS!“,
  Schluss am Taktstrich über `AudioStreamInteractive`, Pause im Einzähler, Neustart, „Musik im Rennen“, Ducking und
  Pause-Tiefpass über die vorhandene Mischung, nichts im Profil Arcade, sauberes Ende.
- **Prüfungen**: `test_music_director.gd` (8 Tests), `check_music.gd` + `test_music_checks.gd` (5 Szenarien im
  laufenden Spiel), `check_music.py`; die Musik-Erwartungen dreier AU-A-Tests auf die echten Stücke umgestellt.
- **Doku**: `docs/audio-modern.md` Abschnitt 14 (Musik) und die Musik-Zeilen in 1, 4.1, 7, 10, 12.
- `scripts/audio/modern/modern_audio.gd` musste **nicht** geändert werden (der Director wird dort schon angelegt und
  mit Kontexten, Ereignissen und Bildern versorgt).

## 3. Messwerte

### 3.1 Dateien (audio_qc.py: alle OK)

| Datei | Länge | Lautheit | True Peak nach Vorbis | Naht (QC) | Größe |
|---|---|---|---|---|---|
| titel_remaster.ogg | 202,5 s, Schleife ab 15,0 s | −14,12 LUFS | −1,67 dBTP (davor −2,22) | ×0,11 | 3,93 MB |
| linke_spur.ogg | 176,4 s, Schleife ab Frame 721 636 (88 Takte = 7 056 000 Frames) | −14,16 LUFS | −1,80 dBTP | ×0,08 | 3,36 MB |
| linke_spur_schluss.ogg | 7,8 s | −15,73 LUFS (eigene QC-Grenze) | −2,43 dBTP | – | 0,15 MB |

Musikordner zusammen 7,48 MB von 25 MB (§4.11). Rendering auf einem Kern mit `nice 19`: Titel 295 s, Rennstück
283–291 s. Determinismus: siehe 3.6. Das Manifest führt je Datei Lautheit, True Peak, Frames, Schleifenpunkte, Bytes
und sha256, dazu `bpm`/`bar_beats` (Titel 128, Rennstück 132) und für Titel und Rennstück `intro_bars`/`loop_bars`
(8 + 100 bzw. 9 + 88 Takte).

### 3.2 Titel-Remaster: gleiche Noten
`check_music.py`: Tonklassen je Takt gleich verteilt (Kosinus der Chroma-Vektoren Median **0,970**, 94 % der Takte
≥ 0,85); Akkord-Grundton in **97 von 108** Takten gleich – die elf übrigen sind Dreiklänge mit zwei gemeinsamen Tönen
(a-Moll/C-Dur im Pre-Chorus, Intro), das Original selbst trifft seine Partitur nur in 94,4 % der Takte; Tonart vor
dem Schlussrefrain bei beiden **e-Moll**. Naht im Rendering −98,4 dBFS. Klangbild gegen das Original bei gleicher
Lautheit: +11 dB Sub bei 50 Hz, −2…−3 dB zwischen 100 und 500 Hz, +3…+6 dB über 6 kHz (wie die Skizze vom 10.11.).

### 3.3 Rennstück: Form, Noten, Naht
Form A1 B1 A2 P1 B2 D S P2 B3 A3 T (je 8 Takte) nach einem Einzähler von einem Takt; Motiv und Hook aus der Skizze,
Aufstieg und Solo in der Bauart der Titelmelodie (Wiedererkennung), Schluss B – C – d. `check_music.py`: Grundton in
85 von 97 Takten wie in der Partitur (87,6 %), Tonart d-Moll, Schluss erkannt. Naht: Die Fortsetzung im Rendering
weicht vom Schleifenbeginn um **−172 dBFS** ab; in Godot gleicht die Ausgabe nach dem Dateiende dem ersten Durchgang
**Frame für Frame** (Abweichung 0).

### 3.4 Übergänge in Godot (check_music.gd „interactive“, offline in 512er-Schritten wie der Mischer)
- Der `AudioStreamInteractive` spielt die Hauptdatei bis zum Wechsel Frame für Frame (Abweichung 0).
- Wechsel zum Schluss 0,596 s vor dem Taktstrich angefordert → der Schluss beginnt **2,90 ms vor** dem Taktstrich
  (die Engine rechnet von ihrem Decoder, der bis zu 128 Frames voraus ist), Restfehler des Abgleichs 0.
- Keine Lücke (leisestes 5-ms-Fenster 6,4 dB unter der Musik davor), **kein doppelter Schlag**: erste 100 ms des
  Schlusses +0,01 dB gegenüber dem Schluss allein.

### 3.5 Im Rennen (check_music.gd „race“, Kiel – Hamburg ab km 2 mit Countdown, Autopilot, Profil Modern)
- Einzähler auf „LOS!“: im Director (Spielzeit, Physikschritte) **−1,5 ms**; in der aufgenommenen Ausgabe 53–65 ms
  nach dem „LOS!“-Ton (im Gesamtlauf am Ende 64,9 ms; in einzelnen Läufen eine Treiberportion mehr, 146 ms; erlaubt
  156 ms). Der Unterschied ist der Dummy-Treiber: Er startet jeden Klang erst an seiner nächsten Portion von
  4096 Frames (93 ms), Musik und Ton fallen in verschiedene Portionen. Mit einem echten Treiber (Schritte von
  512 Frames) bestimmt das halbe Bild die Genauigkeit (abgeleitet: ±8 ms bei 60 fps).
- Ducking: Musik nach dem Fader **−4,5 bis −4,9 dB** unter Vollgas gegenüber dem Countdown (Median über 1 s; der
  Mischzustand selbst −4,5 dB), nachdem die Sitzung weg ist wieder innerhalb **±0,1 dB**; längstes Bild 0,1–0,25 s
  Spielzeit (< 0,35 s).
- Pegel über die ganze Kette (`capture_mix.gd`, Gran Turismo): Musik allein unter Vollgas **−23,7 LUFS** (Plan −24,
  also 7,7 dB unter dem Auto), Höchsttempo −23,2, 130 km/h −21,6; Auto + Musik unter Vollgas −15,5 LUFS, ganze Fahrt
  −16,1 LUFS, True Peak −5,1 dBTP. Menü: −21,2 LUFS in der ersten Minute (leises Intro), für das ganze Stück
  −20,2 LUFS (abgeleitet) – Plan −20.

### 3.6 Gates
- `tools/audio/qc/audio_qc.py --folders music --determinism`: 4 Klänge, 0 Fehler; alle drei Generatoren zweimal
  gerendert, byte-gleich untereinander und mit dem Repository (Anhang).
- `tools/run_tests.sh` (ganz, einmal): bestanden, 622 Tests, 0 fehlgeschlagen, 83 `CHECK … OK`; `tools/golden.sh
  check`: 20 von 20 identisch (Anhang).
- **Arcade spielt nichts Neues** (check_music.gd „arcade“): mit dem Profil Arcade nach Menü, Rennkontext und den
  Ereignissen einer Etappe kein `ModernAudio`, kein Modern-Bus, keine Datei aus `assets/audio/modern/music` geladen;
  die Menümusik ist `assets/audio/music/title_theme.ogg`. Dazu laufen weiter `check_arcade_lean.gd` (kein Modern-Skript
  bei einem Arcade-Start) und `test_arcade_identity.gd` (die 40 eingefrorenen Dateien, Motor-Mischer) in den Tests.
- Beenden: Musik spielt (Menü bzw. Rennen), Profil endet → 0 Player übrig, 0,3 s später `quit()`: in 16 Läufen
  keine „leaked at exit“-Meldung.

## 4. Entscheidungen und warum

1. **Zwei Dateien statt drei Clips.** Gemessen: ein Auto-Advance von `AudioStreamInteractive` startet den nächsten
   Clip 640 Frames (Clip-Reihenfolge 0 → 1) bzw. 128 Frames (1 → 0) **vor** dem Ende des ersten – der Quelltext von
   Godot 4.7.2 bestätigt die Ursache (Wartezeit von der Decoder-Position, Zählung ab dem laufenden Block). Darum
   liegen Einzähler und A1 als Intro in der Schleifendatei (`loop_offset`), wie bei der Titelmelodie; der Schluss bleibt
   ein eigener Clip mit Übergang „nächster Takt“.
2. **Einzähler ein Takt.** `AudioStreamPlaybackInteractive.start()` beginnt immer bei 0, der Countdown dauert 3,0 s,
   zwei Takte bei 132 bpm 3,64 s. Ein ganzer Takt hält das Taktraster der Datei (der Übergang zählt Takte vom
   Dateianfang); der Director startet ihn 1,18 s nach `stage_start`.
3. **Start auf der Uhr der Physik.** Das erste Bild einer Etappe dauerte in den Läufen bis 0,55 s; danach liefen
   Bildzeit und Countdown um bis zu 0,2 s auseinander. Der Director zählt jetzt Physikschritte und verankert den Start
   an jeder Countdown-Zahl neu.
4. **Schluss mit Schnitt statt Ausblenden.** Jede Ausblendung der Schleife lässt deren nächsten Schlag unter dem
   ersten Schlag des Schlusses mitklingen (über alle 88 Taktstriche gemessen: +1,7 bis +4,3 dB, True Peak bis
   +2,2 dBTP auf Dateipegel). `FADE_DISABLED` (1 ms): +0,01 dB.
5. **Ein Rendering, ein Master** für Hauptdatei und Schluss: gleicher Klang, gleiches Pegelverhältnis am Übergang.
6. **Keine neuen Konfigurationsschlüssel** (`audio.modern` gehört in Welle 4 AU-C1): `gain_db` 0 im Manifest genügt,
   die gemessenen Pegel treffen den Plan.

## 5. Ehrliche Einschätzung

- **Gut (messbar)**: Remaster mit denselben Noten und dem Klangbild der Skizze, die der Nutzer am 10.11. bekam;
  Rennstück mit sauberer Form, exakter Schleife, Schluss am Taktstrich ohne Lücke und ohne Doppelschlag, Einzähler auf
  „LOS!“, Pegel auf dem Plan, Ducking hörbar (−4,5 dB) und schnell zurück; Arcade unberührt.
- **Nicht beurteilbar**: ob die Musik gefällt. Die Komposition ist programmatisch aus der Skizze erweitert; der Groove
  ist durchgehend „vier auf den Boden“ und der Tiefbass dicht (im Spektrogramm sehr hell unter 80 Hz) – unter dem Motor
  kann das brummen oder genau richtig drücken, das muss jemand hören. Der Einzähler ist mit 1,8 s kürzer als in der
  Skizze (dort zwei Takte).
- **Grenzen**: Die Genauigkeit „Schlag auf LOS!“ in Echtzeit ist hier nur auf ±1 Treiberportion (93 ms) messbar; auf
  dem Steam Deck mit echtem Treiber erwarte ich ±8 ms (abgeleitet). Ein sofortiges `quit()` des Spiels kann mit beiden
  Profilen „leaked at exit“ melden (Arcade in 3 von 6 Läufen) – nur der Beenden-Pfad des Spiels kann das abstellen.

## 6. Abweichungen vom Vertrag

- Rennstück als Hauptdatei (Intro + Schleife) + Schluss statt Einzähler → Schleife → Schluss als drei Clips (D30) –
  gemessener Fehler des Auto-Advance (4.1).
- Einzähler 1 Takt statt 2 (4.2).
- Übergang zum Schluss ohne Überblenden (`FADE_DISABLED`) (4.4).
- Drei Testdateien von AU-A geändert, deren Musik-Erwartungen das Platzhalter-Verhalten festschrieben:
  `test_modern_audio.gd` (`test_music_contexts`), `test_modern_assets.gd` (Listen des Musikordners),
  `check_modern_audio.gd` (Rennmusik-Schlüssel) – inhaltlich unverändert, nur auf die echten Stücke umgestellt.
- „Kein leaked at exit“ gilt, wenn das Spiel den Klang 0,3 s vor `quit()` anhält; ein sofortiges `quit()` meldet es
  mit beiden Profilen (vorhandenes Verhalten).

## 7. Vertragspunkte (contract issues)

1. D30 setzt für Einzähler → Schleife ein `AudioStreamInteractive`-Auto-Advance voraus; das startet in Godot 4.7.2
   640/128 Frames zu früh (Probe `m1/AU-D1/probe_autoadvance.gd`, Log `probe_aa.log`).
2. `audio_qc.py` verlangt `beats × 60/bpm = Schleifenlänge`; Godot zählt `beat_count` vom Dateianfang. Dateien mit
   Intro (Titel, Rennstück) tragen deshalb kein `beats` und `beat_count` 0.
3. `modern_lib.write_ogg_import()` verliert den Kopf der `.import` und schreibt `loop_offset` mit 6 Stellen
   (`%g`) – 16,3636 statt 16,363634 läge zwei Frames daneben. `music_lib.write_ogg_import_keep()` umgeht beides.
4. „Sauberer Stopp beim Beenden“ ist in den Musikdateien nicht vollständig erreichbar: `GameFlow.quit_game()` ruft
   `quit()` sofort; der AudioServer gibt gestoppte Klänge erst in einem späteren Bild frei.
5. `capture_mix.gd --scenario=race_music` sendet kein `stage_start`/`go`: Das Rennstück beginnt über den Rückfall nach
   0,5 s Fahrt, sein Einzähler fällt ins Messfenster „idle“ (−18,75 LUFS gegen Plan −19,5).

## 8. Für die nächsten Pakete

- **AU-D2**: Stücke 2–3, Zwischenspiel, Stinger nach dem Muster von `linke_spur.py`; der Director nimmt weitere
  Rennstücke reihum und die Rollen `interlude`/`result` ohne Änderung.
- **UI2/AU-E**: `GameFlow.quit_game()` – Klang anhalten, 0,3 s warten, dann `quit()`.
- **Eigentümer von modern_lib/audio_qc**: Import-Kopf und `loop_offset`-Stellen; QC-Regel für `beats` bei Intro.
- **AU-E**: Pegel der Musik mit Fahrbahn/Wind von AU-C1 nachmessen; Gate 2: Urteil des Nutzers zu Stil und Pegel.

## 9. Dateien

Neu: `tools/audio/music/{music_lib,title_remaster,linke_spur,check_music}.py`,
`assets/audio/modern/music/{titel_remaster,linke_spur,linke_spur_schluss}.ogg` (+ `.import`),
`tests/unit/audio_modern/{test_music_director,test_music_checks,check_music}.gd`.
Geändert: `scripts/audio/modern/music_director.gd`, `assets/audio/modern/music/manifest.json`,
`docs/audio-modern.md`, `tests/unit/audio_modern/{test_modern_audio,test_modern_assets,check_modern_audio}.gd`.

## Anhang: Gates am Ende

Alle auf Commit `03eaeff` (= `origin/wip/v080-au-d1`), nacheinander, je mit `nice -n 19` und einem Arbeiter. (Der
Determinismus-Lauf begann auf `b713e71`; `03eaeff` ändert nur Manifest-Eintrag und Import des Titels – `bpm`,
`intro_bars`, `loop_bars` – und lag vor, bevor der Lauf den Titel-Generator erreichte; die Prüfung der Dateien lief
danach auf `03eaeff` noch einmal.)

| Gate | Ergebnis |
|---|---|
| `audio_qc.py --folders music --determinism` | **OK**: 4 Klänge, 0 Fehler, 0 Probleme; Musik 7,483 MB von 25 MB. Determinismus: `make_placeholders.py` OK (15 Dateien je Lauf), `linke_spur.py` OK (3 Dateien je Lauf, 2 Einträge), `title_remaster.py` OK (2 Dateien je Lauf, 1 Eintrag) – je zwei Läufe nach `--out` byte-gleich, Dateien und Manifest-Einträge gleich denen im Repository; 1276 s. Danach `audio_qc.py --folders music` auf dem Endstand: OK (65 s). |
| `tools/run_tests.sh` (ganz, einmal; `XDG_DATA_HOME` absolut unter scratch) | **bestanden** in 663 s: 622 Tests, 0 fehlgeschlagen; 83 `CHECK … OK`, 0 `FEHLER`; keine Zeile „leaked“, „SCRIPT ERROR“, „ERROR:“. Darin die Musik: 8 Tests `test_music_director.gd`, `test_music_checks.gd` mit `interactive` OK, `race` OK (Schlag 64,9 ms nach „LOS!“, erlaubt 156 ms; Director −1,5 ms; Musik −4,9 dB unter Vollgas, danach +0,1 dB), `arcade` OK, `quit_menu`/`quit_race` OK; dazu `check_modern_audio` `mix` OK (Ducking −4,5 dB, Pause-Tiefpass auf `MMusic`). |
| `tools/golden.sh check` (einmal, `JOBS=1`) | **„GOLDEN arcade: 20 von 20 identisch“** (206 s), Exit 0. |
| Arcade spielt nichts Neues | `check_music.gd` `arcade` OK (kein `ModernAudio`, kein Modern-Bus, keine Modern-Musik geladen, Menümusik `title_theme.ogg`); `check_arcade_lean`, `test_arcade_identity` OK im selben Lauf. |
