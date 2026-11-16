## 9. Abweichungen, Vertragsfragen, Hinweise für die Nächsten

Abweichungen von meinem Auftrag
- „Hoch“ nicht als eine ganze Fahrt: bei 1 s je Bild hätte sie 37 min gedauert; gefahren km 0–33,7 und km 78–95.
- Speicherfahrt 16,2 statt 20 min Spielzeit (Lüttich–Paris war zu Ende); dazu QA-SYSTEMs 20-min-Lauf (RSS +4 %).
- `tools/run_tests.sh` nicht selbst gelaufen (Zeit; QA-SYSTEM am selben Kopf); `golden.sh check` einmal zum Schluss.
- A/B mit eigenem Aufruf statt `tools/ab_shot.sh`: Modern mit `--shot-fast` und 1 s Vorlauf (an S2 geprüft, gleich).
- Leistungsfahrten mit `--timescale=2` (8 Physikschritte je Bild) statt Echtzeit – sonst nicht in endlicher Zeit.

Vertragsfragen (contract_issues)
- §4.10/A-6: Die Zeitbudgets (`render()` 1,2–2,0 ms, Einhängen 3–4 ms) werden nur kopflos geprüft; unter dem echten
  GL-Pfad liegen sie hier darüber (Einhängen bis 20 ms). Der Vertrag sollte sagen, ob ein Budget kopflos-normiert oder
  im GL-Pfad gilt.
- D14 F4/F5: „nie mehr Nebel als Arcade“ ist nur für statische Kulisse formuliert und als Tiefennebel 0,45–1,0 definiert;
  Arcade tönt Sprites aber nur mit 0,7 × t multiplikativ. Für Fahrzeuge/Schilder fehlt eine Regel, ob über der
  F5-Ausblendung noch Nebel liegen darf (B7).
- §4.9.2: drei Pflicht-Render-Prüfungen fehlen (B11) – wer liefert sie vor dem Gate-Build (QA1)?
- D22/Gate 1 „andere Etappen mit Platzhaltern“: Tunnel haben in M1 keinen Platzhalter (B1).

Für die Nächsten (notes_for_next)
- Vor dem Testbuild: B1 (Tunnel-Abhilfe oder Beschränkung), B5 (Mondglanz), B2 (Ersatz-Tankstellendach).
- Wahrzeichen bis Arcades Reichweite zeigen (B3b) – ohne R7 als Ersatzbild am Pfad.
- Nebelgesetz für Requisiten/Fahrzeuge vereinheitlichen und die Kontrast-Prüfung schreiben (B7, B11).
- Korridor-Entscheidung mit diesen Bildern (B8) vor Gate 2 treffen.
- Zeitstempel je Haken in `perf_stats` (B10), damit der Leistungstest des Decks Spitzen zuordnet; Einzelspitzen auf
  einer ruhigen Maschine nachstellen.
- Werkzeuge in `<scratch>/v080/m1/QA-BILD/tools` und `probe/` (Abschnitt 8) sind wiederverwendbar.
