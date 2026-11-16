## Vertragsfragen

| ID | Frage | Anlass |
|---|---|---|
| V-1 | Was ist ein Zeitlimit im Tor? `run_render_checks.sh` wertet Exit 124 (900 s je Datei) als FEHLER der Regel; nach A-11 ist eine Prüfung, die nur unter Last scheitert, kaputt. Vorschlag: Zeitlimit = eigener Zustand „kein Ergebnis“, Tor rot mit diesem Grund, Laufzeit je Datei im Protokoll; Dateien, die bei Last 20 über 5 min brauchen, gelten als zu reparieren. | M2S-01 |
| V-2 | Muss der Unit-Läufer (`tests/run_tests.gd`) einen Test, der mit einem Skriptfehler abbricht, selbst als FAIL zählen? Heute macht erst der grep von `run_tests.sh` das Tor rot; ein Einzellauf zeigt „ok“. | M2S-04 |
| V-3 | §4.4.2 nennt **einen** Hinweistext („… lässt sich mit dieser Grafik nicht starten …“). Er erscheint auch, wenn Spieldateien fehlen oder kaputt sind (Manifest, Netzdatei) – dann führt „Grafik“ den Spieler in die Irre. Zweiter Text für die Gründe `manifest`/Dateien (z. B. „… weil Spieldateien fehlen – bitte die Dateien des Spiels prüfen“)? | Rückfall-Fälle 2–4 |
| V-4 | A-6 „`run_tests.sh` ≤ 12 min“ ist ohne Maschine/Last nicht prüfbar: hier 1 133 s bei Last 13–18 (M2ZS1: 881 s). Ziel an eine unbelastete VM mit 4 Kernen binden oder als CPU-Zeit fassen? | Abschnitt 6 |
| V-5 | Klangmessungen auf belasteten Maschinen: Movie Maker (Bild-Uhr) als vorgeschriebener Messweg für `capture_mix`/Pegelplan, mit `editor/movie_writer/mix_rate=44100` (Godots Vorgabe 48 kHz ≠ D26)? | M2S-06 |
| V-6 | Pegelplan D29 nennt für die Musik nur „8 dB unter dem Auto bei Vollgas“. Beim Reisen mit 130 km/h ist sie gemessen **so laut wie das Auto** (−21,47 LUFS beide). Ist das gewollt (Ducking nach Fahrzustand) oder soll die Musik auch beim Reisen unter dem Auto bleiben? Entscheidet der Nutzer. | Abschnitt 2 |
