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
