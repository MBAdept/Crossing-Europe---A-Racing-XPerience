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
