import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
# §1: status bullet
('''- Niemand schaltet das Profil bisher im Spiel um: Die Einstellung „Klang“ und der Aufruf''',
'''- **Seit AU-D1** ist der Baustein `music` kein Platzhalter mehr: das Titel-Remaster in den Menüs, Rennstück 1
  „Linke Spur“ mit Einzähler auf „LOS!“, Schleife und Schluss am Taktstrich, die Musik-Kette unter
  `tools/audio/music/` – Abschnitt 14.
- Niemand schaltet das Profil bisher im Spiel um: Die Einstellung „Klang“ und der Aufruf'''),
# §4.1: table row
('''| `music` | `music_director.gd` · `MusicDirector` | `MMusic` | je Kontext ein Stück in Schleife, Überblenden mit zwei Playern | AU-D1 |''',
'''| `music` | `music_director.gd` · `MusicDirector` | `MMusic` | je Kontext ein Stück in Schleife, Überblenden mit zwei Playern | AU-D1 – **erledigt**: Titel-Remaster, Rennstück mit Einzähler, Schleife und Schluss über `AudioStreamInteractive` (Abschnitt 14) |'''),
# §7: music paragraph
('''**Musik.** `set_music_context(ctx)` kennt `title`, `menu`, `race_menu` (Bildschirme zwischen den Etappen), `race`,
`result`, `off`. Das Spiel ruft weiterhin `set_music(true/false)` und ab Welle 2 daneben `set_music_context`; der
letzte Aufruf gewinnt: `set_music(false)` = `off`; `set_music(true)` = `menu`, sofern nicht schon ein Menü-Kontext
gilt. Der Platzhalter-`MusicDirector` spielt je Kontext ein Stück in Schleife und blendet zwischen Stücken über
(0,6 s aus, 0,4 s ein): die Modern-Datei mit der passenden Rolle aus `assets/audio/modern/music/manifest.json`
(`title`, `interlude`, `result`, `race`; mehrere Rennstücke reihum, eins je Etappe), sonst in den Menü-Kontexten
die heutige Titelmelodie und im Rennen nichts. Ein Stück gilt erst als begonnen, wenn sein Stream da ist
(`resolve()` antwortet bis dahin mit Stille): Die Titelmelodie wird ohne `audio.music_file` in einem Thread
synthetisiert und trifft mit dem Profil Modern beim Start erst nach dem Menü-Kontext ein – vor der Korrektur
blieb sie dann für immer stumm. Das Rennstück blendet bei `stage_finish` aus. Der Schalter
`set_race_music(false)` („Musik im Rennen: Aus“) lässt den Kontext `race` still. `stop_all()` hält die Musik nicht
an. Der Pegel je Kontext steht in `audio.modern.music.context_db` (bezogen auf eine Datei mit −14 LUFS).''',
'''**Musik.** `set_music_context(ctx)` kennt `title`, `menu`, `race_menu` (Bildschirme zwischen den Etappen), `race`,
`result`, `off`. Das Spiel ruft weiterhin `set_music(true/false)` und ab Welle 2 daneben `set_music_context`; der
letzte Aufruf gewinnt: `set_music(false)` = `off`; `set_music(true)` = `menu`, sofern nicht schon ein Menü-Kontext
gilt. Der `MusicDirector` spielt in den Menü-Kontexten das Titel-Remaster (ohne Modern-Datei die heutige
Titelmelodie) und im Rennen ein Rennstück, das mit der Etappe beginnt und mit ihr endet; Überblenden zwischen
Stücken 0,6 s aus, 0,4 s ein, gleiche Leistung. Ein Stück gilt erst als begonnen, wenn sein Stream da ist
(`resolve()` antwortet bis dahin mit Stille): Die Titelmelodie wird ohne `audio.music_file` in einem Thread
synthetisiert und trifft mit dem Profil Modern beim Start erst nach dem Menü-Kontext ein. Der Schalter
`set_race_music(false)` („Musik im Rennen: Aus“) lässt den Kontext `race` still. `stop_all()` hält die Musik nicht
an. Der Pegel je Kontext steht in `audio.modern.music.context_db` (bezogen auf eine Datei mit −14 LUFS), dazu
`gain_db` des Stücks im Manifest. Einzelheiten: Abschnitt 14.'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
# §10 tools table: after the make_arcade_golden row
a = '''| `tools/audio/modern/make_arcade_golden.sh` | schreibt die Fingerabdrücke des Arcade-Klangs aus dem Tag v0.7.0 neu (nur nach einem Engine-Update) |'''
b = a + '''
| `tools/audio/music/music_lib.py` | Musik-Kette (AU-D1): moderne Produktionsschicht über `music_synth.py`, Mixer, Master, Vorbis mit Messung nach der Kodierung (Abschnitt 14.2) |
| `tools/audio/music/title_remaster.py`, `linke_spur.py` | die Generatoren des Titel-Remasters und von Rennstück 1 (`--out`, `--wav`, Skizzen) |
| `tools/audio/music/check_music.py` | Noten: Tonklassen und Akkord-Grundton je Takt, Tonart – Remaster gegen das Original, Rennstück gegen seine Partitur |'''
assert s.count(a) == 1
s = s.replace(a, b)
# §12 tests table
a = '''| `test_engine3_bank.gd`, `test_engine3_mix.gd`, `test_engine3_slot.gd`, `test_engine3_checks.gd` |'''
i = s.index(a)
j = s.index("\n", i)
row_end = s[i:j]
b = row_end + '''
| `test_music_director.gd`, `test_music_checks.gd` | Musik (AU-D1): Zustandsmaschine des `MusicDirector` ohne Szenenbaum; `check_music.gd` als eigene Prozesse (Schleife und Schluss offline gemischt, Rennen mit Countdown und Ducking, Arcade ohne Neues, Beenden mit Musik) – Abschnitt 14.5 |'''
s = s[:i] + b + s[j:]
s = s.rstrip("\n") + "\n" + open(sys.argv[2], encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s)
print("ok")
