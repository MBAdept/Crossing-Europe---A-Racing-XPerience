## Ergebnis je Befund

| Befund | Urteil | Kern (gemessen, wenn nicht anders gesagt) |
|---|---|---|
| B-01 Kurvenkorridor F7 | **nicht behoben** | Code unverändert (`builders/`, `terrain_profile.gd`, `chunk_context.gd`: kein Diff). Sonde auf `515dd51`: T4 9 von 12 ausgelassen, S0-Eiche (seg 9, x −17,1, `corridor=true`) fehlt – zeilengleich mit dem Vorher-Lauf von FIX-M2. Bild: Starteiche fehlt (S0), Baum der Kurveninnenseite C1 fehlt. Leitungsentscheidung nach A-3/A-10 offen. |
| B-02 Niederschlag | **nicht behoben** | Kein `layers/weather.gd` auf `515dd51`; N1 ohne Schneefall (Arcade mit). R4 hat die Ebene (`origin/wip/v080-r4`, im Merge-Baum-Bild von FIX-M2 fällt Schnee). |
| B-03 Blaulicht | **behoben** | Blaue Pixel um die Polizei (Box der Prüfung): Tag 20/60 m Arcade 1 601/182, ZS1 1 004/114, vorher 411/28, **FIX-M2 1 004/153**; 22 Uhr 20/60/150 m Arcade 1 530/184/17, ZS1 481/76/7, vorher 144/49/3, **FIX-M2 1 250/103/16**. Ziel „mindestens ZS1“ überall erreicht; nachts bei 60 m 56 % von Arcade. Im Bild ein deutlicher blauer Hof, der Lichtbalken selbst bleibt schmal. |
| B-04 Bremslicht | **teilweise** | Tag 60 m rote Pixel (Arcade / ZS1 / vorher / FIX-M2): Sportwagen 34/31/9/**11**, Kombi 19/17/4/**6**, Limousine 31/17/17/**20**, Polizei 16/15/5/**5** → 31–65 % von Arcade, Ziel 70 % nicht erreicht. Nachts deutlich stärker (Sportwagen 60 m 95/60/44/**150**). Der rosa Hof liest sich bei Tag nicht als Rot; das schmale Band des Sportwagens ist Modellarbeit. |
| B-05 Abblendlicht | **behoben** | Lkw-Heck (enger Ausschnitt, 22 Uhr) 60 m: Arcade 42, ZS1 194, vorher 194, **FIX-M2 45** mittlere Leuchtdichte, Pixel > 200: 0 / 652 / 652 / **0**; 20 m: 51 / 121 / 121 / **57** (1 537 → 16 Pixel > 200). Limousine silber 60 m: Pixel > 200 12 / 126 / 126 / **13**. Innerhalb ±30 % von Arcade. Der Lkw ist wieder rot, Rückstrahlerband sichtbar. |
| B-06 Spielerlack | **teilweise** | Sättigung der Lackpixel (Arcade / vorher / FIX-M2 / FIX-M2+R4 aus FIX-M2-Bildern): Limousine 12 Uhr (Sonde) 0,583 / 0,731 / **0,634** / 0,631 (+9 %), S1 „Hoch“ 0,583 / 0,732 / **0,635**; Sportwagen 19:30 (Sonde) 0,493 / 0,617 / **0,585** / 0,561 (+19 % / +14 %), C1 0,509 / 0,617 / **0,584** (+15 %); Kompakt 22 Uhr Schnee (Sonde) 0,721 / 0,950 / **0,950** / 0,755, N1 0,719 / 0,944 / **0,944** (+31 %). Ziel ±10 % nur bei Tag erreicht; auf `515dd51` allein ist die Nacht unverändert, erst R4s Nachtgesetz bringt sie heran. |
| B-07 Laden/Hänger | **nicht behoben** | Kein Code geändert (`chunk_streamer.gd` ohne Diff); nicht nachgemessen (keine ruhige Maschine). FIX-M2s kopflose 6,1 ms sind plausibel, belegen aber nur, dass die Spitzen lastabhängig sind (abgeleitet). |
| B-08 LOD-Wechsel 40 m | **nicht behoben (pausiert)** | `XFADE_LODS` = ["lod1","lod2"], `LOD_HYSTERESIS` 0,05 unverändert; auf Nutzerwunsch pausiert (#76). R4 hat lod0 in der Überblendung (`origin/wip/v080-r4` Zeile 68) – kommt mit RINT-M2. |
| M2S-01 Waldprüfung | **teilweise** | ZEITLIMIT-Meldung geprüft: `RENDER_CHECK_TIMEOUT=15` → „ZEITLIMIT (Exit 124, 15 s) – kein Ergebnis“, Skript-Exit 1; Kopfzeile `## render-check-timeout: 1800` wird gelesen. Laufzeit der Waldprüfung @@WALD@@ – Ziel < 300 s bei Last 20 @@WALDZIEL@@. |

### Weitere Punkte von FIX-M2 (nicht in der Liste, kurz nachgeprüft)
- **M2S-04** (Läufer): Wegwerf-Test mit Laufzeitfehler → „FAIL … Skriptfehler im Test (1×), Test abgebrochen: Invalid
  call. Nonexistent 'float' constructor“, Exit 1; Datei gelöscht, Arbeitsbaum sauber (gemessen).
- **M2S-05** (Fernboden-Test): Mutation `target_height()` ohne Wasserterm → `test_far_ground_lies_below_the_water_of_a_bridge`
  rot („hier entscheidet das Wasser … erwartet −3,21, ist 6,44“); zurückgesetzt, Arbeitsbaum sauber (gemessen).
- **M2S-02/03/07**: über die Tore (`vehicle_standin`, `check_vehicles leistung`, `check_seam rueckfall_dateien`) – siehe
  Tore.
- **Mutation der neuen Lichtprüfungen** (SPOT_SPECULAR 0,6, beide Modell-Zuschläge 1,0): @@MUTATION@@
