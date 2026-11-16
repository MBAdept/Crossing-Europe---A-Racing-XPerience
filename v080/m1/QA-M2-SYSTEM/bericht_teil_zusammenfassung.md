## Zusammenfassung

**Urteil: kein Blocker, kein hoher Befund.** Der Kopf `6e48405` ist aus meiner Sicht für den nächsten Testbuild
tauglich, was Arcade-Identität, Klang, Modell-Pipeline und Robustheit angeht. Alle Zahlen sind auf dieser VM (llvmpipe,
Dummy-Audio, Last 13–33) **gemessen**; Hörempfinden, Steam Deck und echte GPU sind **abgeleitet**.

- **Arcade = v0.7.0:** 0 eingefrorene Dateien geändert; `ERGEBNIS` auf drei Etappen gleich (Kiel – Hamburg ganz,
  Bern – Mailand Schnee/Nacht, Dortmund – Frankfurt Regen/Dämmerung); Arcade-Klang-Fingerabdruck aus v0.7.0 neu erzeugt
  = Kopf; `golden.sh check` 20/20 und UI 17/17.
- **Klang Modern:** Kiel – Hamburg im echten Rennen: Betonplatten ab km 25,0 im 5-m-Takt, 4 Fugen der Köhlbrandbrücke
  genau an ihren Kilometern, Hamburger Pflaster/Asphalt genau nach den Blöcken; schwerer Unfall ≤ −4,1 dBTP bei
  Gesamtlautstärke 1,0 (Grenze −1); Rotation 1 → 2 → 3 → 1 mit Stingern und Zwischenspiel; „Musik im Rennen: Aus“ wirkt;
  Wind, Reifen und Menüklänge einzeln sauber; `audio_qc.py` 98/98; kein „leaked“.
- **Modell-Pipeline:** Manifest neu erzeugt byte-gleich, 87 Modelle = 87 Ordner; fünf Modelle neu exportiert und zweimal
  gebacken byte-gleich; `--check-keys` OK; Sprites 187/187 unverändert; Download Windows-Zip 194,5 MB (≤ 280).
- **Tests:** `run_tests.sh` 749/0; Render-Prüfungen 19/19 Dateien OK – die Waldprüfung aber erst nach 49 min mit
  erhöhtem Zeitlimit (M2S-01, mittel). Die beim Merge geänderten Tests werden bei je einer gebrochenen Zeile rot, mit
  drei Lücken (M2S-03 bis M2S-05, niedrig – die Regeln bewacht jeweils ein anderer Test oder der grep des Tors).
- **Robustheit:** `--gfx-debug=fail`, fehlendes/kaputtes Manifest und fehlende Netzdatei fallen auf Arcade zurück (Text
  nennt aber immer die Grafik, M2S-07); Leistungstest schreibt gültiges JSON; Beenden/Neustart in 14 Bildschirmen und in
  der Modern-Etappe ⟨QUITKURZ⟩; 20 min Modern ohne Fehlerzeile, Speicher flach; Linux- und Windows-Build (Wine) fahren
  Arcade und Modern.
