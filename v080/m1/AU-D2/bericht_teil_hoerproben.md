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
