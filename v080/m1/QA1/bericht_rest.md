## 7. Abweichungen vom Auftrag und vom Vertrag

1. **`tests/race3d/bench_modern.gd` (§4.9.4, Datei von QA1) nicht geschrieben.** Die Budgetfrage „`deck` an S3 und C1“
   ist mit dem echten Leistungstest-Läufer beantwortet: eine `user://game_config.json` ersetzt die Szenenliste
   (Wörterbücher mischen, Listen ersetzen) – derselbe Läufer, den der Nutzer startet (Abschnitt 5).
2. **`scripts/race3d/benchmark.gd`** (laut §6 Datei von QA1) gab es schon (UI1); unverändert benutzt.
3. **A/B-Bögen**: B1 (Brückenankunft Köln/Wien) steht nicht im Auftrag und wurde nicht aufgenommen; die Köhlbrandbrücke
   steckt in S4. Bild je Position bei 3 s, S5 bei 1,5 s.
4. **Testbuild**: die nur für den Build nötigen Änderungen (Version, eigener Nutzerordner, Windows-Versionsnummer
   0.8.0.1) macht `tools/build_testbuild.sh` vor dem Export und nimmt sie danach zurück – nichts davon ist committet.
5. **Clips** ohne Ton (Arcade-Klang in beiden Aufnahmen, Bild nebeneinander); der Modern-Klang liegt als Hörprobe bei
   AU-B/AU-D1.

## 8. Vertragsfragen (contract_issues)

1. **Kurvenkamera „schwächer“**: Der Nutzer soll nach dem Fahren entscheiden „so lassen, stärker oder schwächer“ –
   A-3 erlaubt ohne neuen Beweis nur **stärker** („the look can be made stronger, not weaker“; F1 hat bei 270/260 m
   keinen Rand). Wünscht der Nutzer „schwächer“, braucht es `modern_sight.gd -- --full` und eventuell einen Ausgleich.
2. **F1 deckt Schilder am Rand nicht ab**: `modern_sight_f1` prüft Ziele auf Fahrbahnmitte ± eine Spur. An T1 steht
   ein rot-weißes Kurvenschild ≈ 25 m voraus am rechten Bildrand in Arcade im Bild, in Modern nur als 2-px-Streifen
   (die Kamera schaut in die Kurve). Regel 9 zählt Schilder zu dem, worauf der Spieler reagiert – der Vertrag sollte
   sagen, ob F1 Schilder am Straßenrand einschließt.
3. **Start bei km 0 nicht im Prüfnetz**: Alle Referenzpositionen, Goldens, Attract-Demos und der Leistungstest starten
   bei km > 0; der Start jeder echten Etappe (km 0, Countdown) war deshalb nie im Bild geprüft (QA1-B1). Vorschlag:
   §4.9.2 um eine Position „S0 – Start bei km 0 mit Countdown“ ergänzen (in `modern_frames.txt` steht sie schon).
4. **A-6 zweite Liste**: Die ◀▶-Pfeile von Fahrzeugwahl und Startzeit folgen der Wanduhr (`Time.get_ticks_msec()`,
   seit v0.7.0) – die zweite Liste maskiert sie. Gleichwertig wäre eine Spieluhr in UI-Dateien (UI2), dann ließe sich
   die Maske streichen.
