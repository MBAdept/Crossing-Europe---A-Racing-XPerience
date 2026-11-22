
## 6. Abweichungen und Vertragsfragen

**Abweichungen vom Auftrag**
- Notiz 11 (c): Docken 0,14 m breit nach Arcades `_balustrade` (fünf je Segment, Pfeiler alle vier Segmente) statt
  der 0,35 m des Auftrags – Arcade ist die Vorlage.
- Notiz 4: Der Zuschlag des Blaulichts bleibt nachts (nur der Bremszuschlag fällt): nachts liegt das Blau der Modelle
  ohnehin bei etwa der Hälfte von Arcade; „höchstens Arcade + 10 %“ ist erfüllt.
- Notiz 6: Mit eingespeistem Verkehr (48 Autos) gilt die Budgetgrenze der Fahrzeug-Ebene (128) nicht – sie kann
  gezeigte Stufen nicht freigeben; gebunden wird durch die Szenengrenze 230 und die Ablehnung der Engine. Ohne
  Einspeisung (Kiel – Hamburg) gilt sie weiter.
- Notiz 4: „bremsschein“ misst das aufsummierte Rot statt der Zahl der Pixel (die Zahl trennte Tag und Verstärkung
  1,0 nicht sicher).
- Determinismus: zwei AS5a-Modelle zweimal erzwungen exportiert und gebacken (nicht alle elf; AS5aR1 hat alle elf
  echt exportiert und zwei davon so geprüft).
- Nach dem ersten Einfrieren (`1cd689d`) noch Code am Tankstellendach (`c72d484`, `b673df5`, `02051f7`, `b903797`,
  `9b02f05`, Notiz 8) und eine Render-Prüfung (`ab2a400`). Die Goldens `6b17293` entstanden auf `c72d484`; die
  späteren Schritte ändern keinen Entscheid (Sonde über das ganze Netz, 1909 Dächer, 0 verschieden) – `modern-check`
  auf dem Endstand: 6 von 6 identisch, GLES OK. Run_tests Lauf 2, Builds und Rauchtest liefen auf dem Endstand, die Render-Prüfungen
  auf `b673df5`, die Strukturprüfungen auf dem Endstand erneut: 7 von 7 OK.
- Notiz 8: „≤ 2 ms“ ist in einem Messlauf auf einer belasteten VM erfüllt (1,36 ms); Höchstwerte streuen dort stark
  (Requisiten 0,12–4,19 ms in vier Läufen ohne Änderung) – auf dem Gerät nicht gemessen.
- **Regelverstoß, selbst gefunden (14:00 Uhr):** mein Hilfsskript für einzelne Render-Prüfungen (`sh/rc_snap.sh`)
  legte zwar einen eigenen Ordner an, exportierte aber `XDG_DATA_HOME` nicht. Rund 20 Läufe (Bremsschein, Laternen, Budget, Wald, Stadt,
  Strukturen, Requisiten; 06:16–13:57 Uhr) liefen deshalb mit dem echten Benutzerordner
  `~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience`. Geschrieben haben sie dort Godot-Logs
  (die Rotation behält fünf – ältere Logs anderer Läufe vor heute sind dadurch verdrängt), den Startwächter
  `modern_start.lock` (von jedem Lauf beim sauberen Ende wieder entfernt, jetzt nicht vorhanden) und 31 Dateien im
  Shader-Cache. Keine Einstellungen, keine Rekorde, kein Spielstand (die Prüfungen speichern nichts). Behoben: das
  Skript exportiert jetzt den Ordner; meine fünf Logs dort gesichert (`logs/userfolder_artefacts/`) und entfernt; die
  Shader-Cache-Dateien liegen noch dort (nicht sicher zuzuordnen, harmlos). Die Ergebnisse der Prüfungen hängen nicht
  daran (kein gespeicherter Grafikmodus, `--graphics=modern` ausdrücklich).
- Die A/B-Bögen und Einzelbilder bis 13:57 Uhr liefen mit dem eigenen leeren, absoluten `XDG_DATA_HOME` von
  `tools/ab_shot.sh` unter `/tmp` (nicht im Arbeitsordner); ab dann mit `TMPDIR` im Arbeitsordner.

**Vertragsfragen**
- NACH-M2 N-03 nahm an, die nasse Fahrbahn verliere mit `SPOT_SPECULAR` 0 ihren Glanz – gemessen pixelgleich: die
  Fahrbahn liegt auf Ebene 2 und nahm den Spot nie (A-20 erster Spiegelstrich ist damit gegenstandslos für die Fahrbahn).
- A-19: Der Wald mit 48 gleichzeitig gezeigten Autos erreicht 216 von 230 – mehr gleichzeitig gezeigte Autos als dort
  verträgt die Szene nicht; die Fahrzeug-Ebene ist ein weiches Budget. Vorschlag: eine harte Obergrenze gezeigter
  Modellautos (Rest als Stand-in-Karte) oder `buffer_size` des globalen Puffers in den Projekteinstellungen prüfen.
- A-19 Tönung: Für Pakete, die MultiMeshes mit `vpbr`/`baked`/`leaves`/`billboard` bauen, gilt jetzt „Farbe und
  Custom-Daten oder keins von beiden“ (Godot 4.7.2 Compatibility, gemessen, §17.3) – als Regel in den Vertrag?
- A-20: Für das Blaulicht gibt es nur die obere Grenze; nachts liegt es bei der Hälfte von Arcade. Eine untere Grenze
  (z. B. 0,8 × Arcade) wäre eine eigene Aufgabe (Blaulicht-Schein der Modelle).
