## Für die Nächsten (offen oder nur abgeleitet)

1. **Waldprüfung** (`check_instance_budget_wald`): bis M2S-01 repariert ist, nur mit `RENDER_CHECK_TIMEOUT=3600` und allein laufen lassen (hier 2 945 s bei Last 20–33).
2. Klang: der Schluss „rekord“ und „finale“ kam im Ablauf nicht vor (die Bestenlisten sind vorbelegt) – für den Test ein leeres `user://` mit leeren Bestenlisten nehmen. Reifen, Wind und Menüklänge sind seit dem Nachtrag einzeln gemessen (Abschnitt 2), im echten Rennen nur über die Feed-Karte.
3. Ob die Leerlauf-Textur nach einem Unfall (1,5-ms-Klingler an jedem Zündstoß) als Ticken hörbar ist, kann nur ein Mensch hören (`sound/rs_crash2.wav` ab 13 s).
4. Messweg Klang: Movie Maker mit Bild-Uhr und `override.cfg` (`editor/movie_writer/mix_rate=44100`), sonst laufen WAV und Uhr unter Last auseinander.
5. `tools/*.sh`, die sich selbst `nice -n 10` geben, nicht noch einmal in `nice` packen – die Werte addieren sich zu 19, dann verhungert die Prüfung neben anderen Agenten (so lief die Waldprüfung in Lauf 1).
6. Mutationen an Shader-Uniforms, die zur Laufzeit gesetzt werden (`lane_line_w` in `road.gd`), im Setter brechen, nicht im Shader-Vorgabewert – sonst ist die Mutation wirkungslos (so mein erster `golden_road`-Versuch).
7. Fenster schließen ist unter nacktem Xvfb nicht prüfbar (kein `WM_DELETE_WINDOW`); dafür einen Fenstermanager starten oder auf dem Desktop/Steam Deck von Hand prüfen.
8. Testbuilds über `tools/build_testbuild.sh` bauen (eigene Version, eigener Nutzerordner); `build_linux.sh`/`build_windows.sh` tragen bis REL „0.7.0“ – so vorgesehen.
9. Laufzeiten bei Last 20: `check_sprite_geometry.py --jobs 2` 20 min, `--check-keys` ≈ 20 min, Export der Kirche (Cycles) 7 min, `run_tests.sh` 19 min; Hintergrundbefehle enden nach 2 h – lange Ketten teilen.
