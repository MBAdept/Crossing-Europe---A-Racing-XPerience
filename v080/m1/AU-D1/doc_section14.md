
## 14. Musik (Paket AU-D1)

Vertrag D26, D29, D30, §4.7, A-5. Alle Zahlen gemessen auf der Entwicklungsmaschine (Godot 4.7.2, ohne Bildschirm,
Dummy-Audiotreiber), sofern nicht „abgeleitet“ dasteht. **Wie die Musik klingt, hat hier niemand gehört** – das
beurteilt der Nutzer (Hörproben unter `<scratch>/v080/deliver/AU-D1/`).

### 14.1 Die Stücke

`assets/audio/modern/music/` (Manifest `manifest.json`, Rollen für den `MusicDirector`):

| Datei | Rolle | Länge | Schleife | Lautheit / True Peak (nach Vorbis) | Größe |
|---|---|---|---|---|---|
| `titel_remaster.ogg` | `title` | 202,5 s | Intro 15 s einmal, dann Takte 9–108 (187,5 s) | −14,1 LUFS / −1,7 dBTP | 3,93 MB |
| `linke_spur.ogg` | `race` | 176,4 s | Einzähler + A1 (9 Takte, 16,36 s) einmal, dann 88 Takte = 160,0 s | −14,2 LUFS / −1,8 dBTP | 3,36 MB |
| `linke_spur_schluss.ogg` | `race_ending` | 7,8 s | – | −15,7 LUFS / −2,4 dBTP | 0,15 MB |

Mit dem Platzhalter von AU-A zusammen 7,48 MB von 25 MB Budget (§4.11). `audio_qc.py` besteht für alle
Dateien (Naht ×0,11 / ×0,08). Die Einträge tragen über das Format hinaus `piece`, beim Rennstück `ending` (die id des
Schlusses), `countin_beats`, `intro_bars`, `loop_bars`; der Schluss eigene QC-Grenzen der Lautheit
(`"qc": {"lufs": [-20, -10]}`): Er wird mit dem Master der Schleife bearbeitet und nicht für sich auf −14 LUFS
gebracht, sonst spränge der Pegel am Übergang.

### 14.2 Die Kette (`tools/audio/music/`)

| Datei | Inhalt |
|---|---|
| `music_lib.py` | die Produktionsschicht über dem eingefrorenen `tools/audio/music_synth.py` (importiert, nie geändert): Sub-Kick- und Snare-Ebenen, Shaker, Sub-Bass, zwei Supersaw-Leads für die Breite, neue Platte und Halle; `Mixer` (eine Spur nach der anderen in Busse und Sends – ein Stück von drei Minuten liegt nie mit allen Spuren im Speicher); `Master` (EQ, drei Bänder bei 140 Hz und 3,2 kHz, Kleber, M/S, Lautheit, Soft-Clip, True-Peak-Begrenzer) mit `pre()`/`fit_gain()`/`post()`; `encode_checked()` schreibt Vorbis q5 bitgenau, dekodiert und misst – liegt der True Peak nach der Kodierung über −1,08 dBTP, sinkt die Grenze des Begrenzers und die Datei wird neu geschrieben; `write_ogg_import_keep()` (Import mit erhaltener uid, `loop_offset` mit allen Stellen); Chroma, Dreiklang, Tonart für die Prüfung |
| `title_remaster.py` | das Titel-Remaster (14.3) |
| `linke_spur.py` | Rennstück 1 (14.4) |
| `check_music.py` | die Noten-Prüfung (14.6) |

```
python3 tools/audio/music/title_remaster.py            # 295 s auf einem Kern (gemessen)
python3 tools/audio/music/linke_spur.py                # 283–291 s
python3 tools/audio/music/linke_spur.py --info         # Form, Clip-Längen
python3 tools/audio/music/title_remaster.py --bars 32:48 --wav /tmp/x   # Skizze einzelner Takte (37 s)
python3 tools/audio/music/linke_spur.py --sketch 12 --wav /tmp/x        # Einzähler + 12 Takte (25 s)
python3 tools/audio/music/check_music.py
python3 tools/audio/qc/audio_qc.py --folders music --determinism
```

Jeder Generator nimmt `--out <Ordner>` (dann ohne Import-Dateien; so ruft `audio_qc.py --determinism` ihn zweimal
auf) und `--wav <Ordner>` (zusätzlich der ganze Master als Float-WAV für Hörproben). Feste Seeds, kein Zeitstempel,
Vorbis über ffmpeg mit den Bitexakt-Schaltern: zwei Läufe schreiben dieselben Bytes. Danach `godot --headless --import`.

### 14.3 Titel-Remaster

Dieselbe Komposition wie die Titelmelodie von v0.5.0: `music_synth.Render` liefert jedes Ereignis des Originals
(Zeitleiste, Abschnitte, Akkorde, Melodien, Schlagzeugmuster, Seeds, Abschnitts-Automation) mit seinem eigenen
Instrument. Neu ist die Produktion aus der Skizze der Audio-Studie, jetzt für das ganze Stück bei 44,1 kHz:
Sub-Kick und Snare mit Knall und Platte unter den alten, Shaker in Refrains, Solo und Schlussrefrain, Sub-Bass unter
der Basslinie, zwei weitere Rhythmusgitarren mit dunklerem Verstärker innen, die Supersaw-Dopplung der Synth-Melodie,
tieferes Pumpen, neue Hallräume, der Mehrband-Master. Die neuen Ebenen folgen der Automation der Spur, die sie
doppeln.

- **Gleiche Noten** (`check_music.py`): Tonklassen je Takt gleich verteilt – Kosinus der Chroma-Vektoren im Median
  0,970, 94 % der Takte ≥ 0,85; Akkord-Grundton in 97 von 108 Takten gleich. Die übrigen elf Takte sind Dreiklänge mit
  zwei gemeinsamen Tönen (a-Moll / C-Dur im Pre-Chorus, wo ein gehaltenes e die Waage kippt; Intro-Takte); das
  Original selbst trifft die Partitur in 94,4 %, das Remaster in 90,7 % der Takte. Tonart vor dem Schlussrefrain (er
  steht einen Ganzton höher) bei beiden e-Moll.
- **Schleife** wie beim Original: Intro 15 s einmal, Schleife bis zum Dateiende; der Körper endet mit der Kehre des
  Intros, die Naht ist Teil der Musik – im Rendering weicht die Fortsetzung vom Schleifenbeginn um −98,4 dBFS ab.
- **Pegel**: −14,12 LUFS, True Peak −1,67 dBTP nach Vorbis (davor −2,22). Im Menü über die Kette gemessen
  (`capture_mix.gd --scenario=menu`): −21,2 LUFS in der ersten Minute (das leise Intro), für das ganze Stück
  −20,2 LUFS (abgeleitet: die erste Minute der Datei ist 1,05 LU leiser als das ganze Stück) – Plan −20.
- **Klangbild** gegen das Original (Terzspektrum, gleiche Lautheit): +11 dB Sub bei 50 Hz, 2–3 dB weniger zwischen
  100 und 500 Hz, +3 bis +6 dB Luft über 6 kHz.

### 14.4 Rennstück 1 „Linke Spur“

Aus der Skizze der Audio-Studie gewachsen (d-Moll, 132 bpm, ihr Groove, Motiv und Hook), im Markenklang der
Titelmelodie: Synthwave-Rock aus den Instrumenten von `music_synth.py` und den neuen Ebenen. 1 Takt = 20/11 s.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | A | Snare-Crescendo, Toms, Riser, Rückwärts-Becken, Arpeggio und Pad schwellen an – keine Kicks, die neben den Countdown-Pieptönen wie Echos klängen |
| A1 | 8 | d d B C d d B C | Groove (Kick auf jeder Viertel, rollende Achtelbässe mit Oktavsprüngen, gedämpfte Gitarren), Motiv der Skizze ab Takt 5 |
| B1 | 8 | B C d d B C F A | der Hook der Skizze mit Supersaw-Dopplung, offene Gitarren 3-3-2, Clap |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre |
| P1 | 8 | g g B B C C A A | Aufstieg mit Bläser-Stößen, Snare-Wirbel in Takt 7–8 |
| B2 | 8 | wie B1 | Hook mit Harmoniestimme und Leadgitarre eine Oktave tiefer |
| D | 8 | B F C d B F C A | Breakdown: FM-Glocken, weiche Melodie, Schlagzeug baut sich auf |
| S | 8 | d B C d d B C A | Gitarrensolo |
| P2 | 8 | wie P1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem: Harmonie, Gitarre, Bläser, Becken jeden zweiten Takt |
| A3 | 8 | wie A1 | Motiv und Antwort in Oktaven (Synth und Gitarre) |
| T | 8 | d d B C g g A A | Kehre: Halbtempo, lange Töne, Riser in A1 |
| Schluss | 2 + Nachklang | B – C – d | Schläge auf B und C, Tom-Wirbel, Schlussakkord d-Moll mit Lead auf f'', klingt 4 s aus |

**Zwei Dateien statt drei Clips.** `linke_spur.ogg` enthält Einzähler und A1 einmal und danach die Schleife
B1 … T, A1 (`loop_offset` auf dem ersten Frame von B1, die Schleife endet am Dateiende) – wie die Titelmelodie. Der
geplante dritte Clip (Einzähler als eigene Datei mit Auto-Advance in die Schleife) scheitert an der Engine: Ein
Auto-Advance startet den nächsten Clip zu früh (gemessen 640 Frames bei der Clip-Reihenfolge Einzähler → Schleife,
128 bei der umgekehrten, Falle 14.7.1) – der Übergang würde doppelt klingen. Die Schleife endet mit A1, so liegt die
Naht mitten in der Musik (A1 → B1) und ist exakt: Was nach dem A1 des Anfangs in B1 nachklingt, klingt auch nach dem
A1 am Ende der Schleife nach. Gemessen: Die Fortsetzung im Rendering weicht vom Schleifenbeginn um −172 dBFS ab, und
in Godot gleicht die Ausgabe nach dem Dateiende dem ersten Durchgang Frame für Frame.

**Ein Rendering, ein Master.** Einzähler, Schleife, eine Fortsetzung (drei Takte B1 für die Nahtprüfung), drei Takte
Stille und der Schluss liegen auf einer Zeitleiste; der Master (Schwellen und Pegel) wird an der Schleife eingestellt
und gilt für alles. So hat der Schluss genau den Klang und das Pegelverhältnis der Schleife.

**Der Schluss** setzt am nächsten Taktstrich nach dem Ziel ein (`AudioStreamInteractive`, Übergang „nächster Takt“,
Schleife endet in 1 ms – `FADE_DISABLED`). Jedes längere Ausblenden lässt den nächsten Schlag der Schleife unter dem
ersten Schlag des Schlusses mitklingen: gemessen über alle 88 Taktstriche +1,7 bis +4,3 dB in den ersten 100 ms und
True Peaks bis +2,2 dBTP (Dateipegel) für 1/16 bis 1/2 Schlag Ausblenden, mit dem Schnitt +0,01 dB. Den Schnitt
verdeckt der Schluss selbst: Er beginnt mit Kick, Becken und Impact.

**Noten** (`check_music.py`): Akkord-Grundton in 85 von 97 Takten wie in der Partitur (87,6 %); die übrigen sind
Dreiklänge mit gemeinsamen Tönen (A → e-Moll in den A7-Takten, B → d-Moll im Breakdown, wo Glocken und Melodie d und f
spielen). Tonart d-Moll, Schluss B – C – d erkannt.

**Pegel im Spiel** (`capture_mix.gd --scenario=race_music`, Gran Turismo, Musik allein über `--mute-bus=MEnv`):
Vollgas durch die Gänge −23,7 LUFS (Plan −24, also 7,7 dB unter dem Auto mit −16), Höchsttempo −23,2, Reisetempo
130 km/h −21,6. Auto und Musik zusammen: Vollgas −15,5 LUFS, ganze Fahrt −16,1 LUFS, True Peak −5,1 dBTP.
`gain_db` bleibt 0: Die Renn-EQ-Mulde und `context_db.race` (+1 dB) gleichen sich für dieses Stück aus.

### 14.5 Der `MusicDirector`

| Kontext | Stück |
|---|---|
| `title`, `menu` | Rolle `title`: das Titel-Remaster (ohne Modern-Datei die Titelmelodie von heute) |
| `race_menu`, `result` | Rolle `interlude` bzw. `result`, solange es keine gibt das Titel-Remaster – es läuft dann ohne Neustart weiter |
| `race` | ein Rennstück (Rolle `race`, reihum eins je Etappe) |
| `off` | Stille |

Das Rennstück und die Etappe:

| Phase | wann | was |
|---|---|---|
| `armed` | `set_music_context("race")` – jede Etappe, auch ein Neustart | die Menümusik blendet aus, das Stück wartet |
| `waiting` | Ereignis `stage_start` {countdown_s} | Start in countdown_s − Einzähler; jede Countdown-Zahl (`countdown` {n}) verankert neu: Start in n − Einzähler |
| `playing` | der Start ist da (das Bild, das dem geplanten Moment am nächsten liegt), `go` ohne `stage_start`, oder 0,5 s Fahrt ohne jedes Ereignis (Werkzeuge) | `play()` des `AudioStreamInteractive`; der erste Schlag nach dem Einzähler fällt auf „LOS!“ |
| `ending` | `stage_finish` | Wechsel zum Schluss am nächsten Taktstrich |
| `over` | `stage_finish`, bevor das Stück begonnen hat | bleibt still |

- **Die Uhr des Starts** sind die Physikschritte (`Engine.get_physics_frames()`, ohne die pausierten) – die Uhr des
  Countdowns. Ein langes Bild, nach dem die Physik aufholt oder Zeit verwirft, verschiebt Countdown und Musik gleich.
  Ohne Physik (Unit-Tests) zählt die Bildzeit. Gemessen in einem Rennen mit Countdown: der Schlag liegt in Spielzeit
  1,5 ms vor „LOS!“; in der Ausgabe eines Laufs ohne Bildschirm 53,4 ms oder eine Treiber-Portion mehr danach – der
  Dummy-Treiber startet jeden Klang an seiner nächsten Portion von 4096 Frames (Falle 14.7.9); ein echter Treiber mischt
  in Schritten von 512 Frames (abgeleitet: dann bestimmt das halbe Bild die Genauigkeit).
- **Pause im Einzähler**: Der Stream pausiert mit dem Countdown (`stream_paused`). Nach „LOS!“ läuft die Musik in
  der Pause weiter, gefiltert vom Mischzustand `pause`.
- **„Musik im Rennen: Aus“** lässt das Rennstück still; wieder an, beginnt es mit seinem Einzähler.
- **Platzhalter** spielen nur, solange eine Rolle kein echtes Stück hat (`audio.modern.placeholders`).
- **Pegel**: Player auf `context_db` + `gain_db`; Ducking, Renn-EQ, Pause-Tiefpass und Dips wirken auf dem Bus.
  Überblenden mit gleicher Leistung über die Player-Lautstärke (die der Mischer je Block rampt).
- **Ende**: `teardown()` hält und gibt die Player frei. Ein `quit()` direkt danach kann bei jedem Profil
  „leaked at exit“ melden (Falle 14.7.10).

### 14.6 Prüfungen

| Datei | prüft |
|---|---|
| `tests/unit/audio_modern/test_music_director.gd` | 8 Tests ohne Szenenbaum: Stücke je Kontext, Start und „LOS!“ (Spielzeit), Neuverankerung an den Countdown-Zahlen, kurzer Countdown, `go`, Start ohne Ereignisse, Ziel, Neustart, Ziel vor dem Start, „Musik im Rennen“, Pause im Einzähler, der gebaute `AudioStreamInteractive`, Platzhalter |
| `tests/unit/audio_modern/check_music.gd` | eigene Prozesse: **interactive** – das Rennstück offline in 512er-Schritten wie der Mischer: Hauptdatei Frame für Frame, nach dem Dateiende Abweichung 0 zum ersten Durchgang, Schluss 2,9 ms vor dem Taktstrich, keine Lücke, kein doppelter Schlag (+0,01 dB); **race** – Kiel – Hamburg mit Countdown und Autopilot: Schlag auf „LOS!“, Musik nach dem Fader −4,5 dB unter Vollgas, ohne Sitzung wieder −0,1 dB, kein Bild über 0,35 s Spielzeit; **arcade** – mit dem Profil Arcade nach Menü, Rennkontext und Etappenereignissen kein `ModernAudio`, kein Modern-Bus, keine Modern-Musik geladen, die Menümusik ist die Titelmelodie von v0.7.0; **quit_menu**, **quit_race** – Musik spielt, Profil endet, nichts bleibt übrig |
| `tests/unit/audio_modern/test_music_checks.gd` | startet `check_music.gd` (so deckt `tools/run_tests.sh` es ab); keine Fehler- oder Warnzeile, auch kein „leaked at exit“ |
| `tools/audio/music/check_music.py` | Noten und Tonart (14.3, 14.4) |
| `tools/audio/qc/audio_qc.py` | Dateien, Pegel, Nähte, Import, Größe; `--determinism` |

### 14.7 Fallen (gemessen, Godot 4.7.2)

1. **Auto-Advance startet zu früh**: `_queue()` rechnet die Wartezeit von der Position des Decoders, der dem Ausgang
   bis zu 128 Frames voraus ist, und der neue Clip zählt den laufenden Mischblock schon mit – gemessen 640 Frames zu
   früh (Clip 0 → 1), 128 Frames (1 → 0). Gegenmittel: Intro und Schleife in einer Datei mit `loop_offset`.
2. **„Nächster Takt“ rechnet vom Decoder**: Der Schluss beginnt bis zu 128 Frames (2,9 ms) vor dem Taktstrich.
3. **Ausblenden unter dem Schluss verdoppelt den Schlag** (14.4) – `FADE_DISABLED` nehmen.
4. **`AudioStreamPlaybackInteractive.start()` übergeht die Startposition**: Der erste Clip beginnt immer bei 0. Den
   Einzähler deshalb als ganze Takte an den Dateianfang legen und den Start zeitlich planen.
5. **`beat_count` zählt vom Dateianfang**: Mit `bpm` und `beat_count` springt eine Ogg-Schleife nach beat_count
   Schlägen ab Frame 0 zurück, nicht ab `loop_offset`. Dateien mit Intro tragen deshalb `beat_count` 0 (die Schleife
   endet am Dateiende) – und im Manifest kein `beats`, denn `audio_qc.py` setzt `beats` gleich der Schleifenlänge.
6. **`loop_offset` braucht alle Stellen**: Godot schneidet loop_offset × Rate auf einen Frame ab; mit 6 Stellen
   (16,3636) läge der Rücksprung zwei Frames daneben. Der Generator schreibt (Frame + 0,25) / Rate.
7. **Der eingefrorene Oszillator wählt seine Bandbegrenzung nach dem höchsten Ton der ganzen Phrase**: Eine vor dem
   Rendern gekürzte Phrase klingt heller oder dunkler. Phrasen werden immer ganz gerendert und danach abgeschnitten.
8. **`AudioStreamPlayback.mix_audio()` eines zu Ende gespielten Streams** liefert weniger Frames (Schleifen in Prüfungen
   auffüllen, sonst endlos). Jeder Clip erreicht den Ausgang 2 Frames später (kubischer Resampler).
9. **Der Dummy-Treiber** startet jeden Klang an seiner nächsten Portion (4096 Frames, 93 ms): Zeitmessungen zwischen
   zwei Klängen ohne Bildschirm schwanken um eine Portion.
10. **„leaked at exit“ nach `quit()`**: Ein gestoppter Klang wird vom AudioServer erst nach dem Ausblenden im Mischer
    und in einem späteren Bild des Hauptthreads freigegeben. Ein `quit()` gleich danach meldet „ObjectDB instances were
    leaked at exit“ – mit dem Profil Arcade (Menümusik von v0.7.0) in 3 von 6 Läufen, mit Modern in 2 von 6. Mit 0,3 s
    zwischen dem Ende des Profils und `quit()`: 0 von 16.
11. **`modern_lib.write_ogg_import()` verliert den Kopf der `.import`-Datei** (Abschnitt 13): `music_lib` hat dafür
    `write_ogg_import_keep()`.

### 14.8 Offene Punkte

- **Hören**: Titel-Remaster, Rennstück 1, Schluss und Pegel muss der Nutzer beurteilen.
- **Stücke 2–3, Zwischenspiel, Stinger, UI-Klänge** (AU-D2): je Stück ein Generator nach dem Muster von
  `linke_spur.py` (ein Rendering, ein Master, Hauptdatei mit Intro und Schleife, Schluss). Der Director nimmt weitere
  Rennstücke reihum und Rollen `interlude`/`result` ohne Änderung.
- **Beenden des Spiels** (UI / AU-E): `GameFlow.quit_game()` sollte den Klang anhalten und 0,3 s warten, bevor es
  `quit()` ruft (Falle 10) – betrifft beide Profile.
- **`capture_mix.gd --scenario=race_music`** sendet kein `stage_start`: Das Rennstück beginnt nach 0,5 s Fahrt, sein
  Einzähler und der erste Schlag fallen in das Messfenster „idle“ (gemessen −18,75 LUFS gegen Plan −19,5) – für das
  Leerlauf-Ziel nicht vergleichbar.
- **QC-Regel und Godot**: `audio_qc.py` vergleicht `beats` mit der Schleifenlänge, Godot zählt `beat_count` vom
  Dateianfang (Falle 5).
