**Beenden und Neustart in jedem Bildschirm** (`bin/quit_screens.sh`: echtes Spiel auf eigenem Xvfb 1280 × 720, gespeicherter
Modus Modern, Klang Modern; jeder Bildschirm mit `--screen=<name>` und Beispieldaten, nach 14 s Bild, dann Beenden über
SIGTERM, danach Neustart **ohne** Argumente, nach 14 s Bild, wieder SIGTERM; Bilder alle angesehen):

| Fall | Ergebnis (gemessen) |
|---|---|
| 14 Bildschirme: Titel, Rennen wählen, Fahrzeug (Showroom in Modern), Startzeit, Route wählen, Etappe, Etappe beendet, Rennen beendet, Einzelne Etappe, Bestenlisten, Optionen, Fähre, Grafik wählen, Leistungstest | jeder Bildschirm zeigt seinen Inhalt (`beenden_14_bildschirme.png`); SIGTERM beendet sofort (Exit 143), **kein Startmarker**, `settings.json` unverändert (`graphics_mode: modern`, `gfx_preset: medium`), Neustart zeigt den **Titel ohne Absturzfrage**; 0 Fehler-/Warnzeilen in 28 Logs |
| Modern-Etappe Kiel – Hamburg, SIGTERM **beim Laden** (5 s) | Marker bleibt (wie ein Absturz – so gebaut, FIX1); Neustart: Titel mit der **Absturzfrage** („Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“, „Bei Arcade bleiben“ fokussiert; `beenden_absturzfrage_nach_sigterm_beim_laden.png`), dieser Start läuft Arcade |
| Strike 1: Antwort mit Return („Bei Arcade bleiben“) | `settings.json` bleibt **modern**, `modern_start.strikes` = 1, Marker weg – wie FIX1 („der erste Abbruch behält die Wahl“) |
⟨QUIT2⟩
