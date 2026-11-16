
### 13.9 Speicher, Ladezeit, Showroom

- **Texturspeicher** (A-6: Modern höchstens Arcade + 60 MB), Kiel–Hamburg km 2, 15 s Fahrt mit Verkehr, Monitor der
  Engine (`m1/RINT-B/probe/texmem_probe.gd`, gemessen): Arcade 221,1 MB, Modern 166,8 MB – davon 51,5 MB für 17 Bögen
  der Ersatzbilder. Die Bögen werden nur in `prepare()` geladen und nur für Sets ohne Modell; Modern liegt 54 MB unter
  Arcade, eine weitere Einschränkung der Bögen ist nicht nötig.
- **Ladezeit** Kiel–Hamburg ab km 0 (Szene eingehängt bis `RaceSession.is_live()`, wie `prepare_s` des
  Leistungstests; `m1/RINT-B/probe/loadtime_probe.gd`, gemessen auf der Build-VM): Modern 5,2–5,6 s, Arcade 0,85 s.
  Die ganze Zeit steht das Ladebild; sein Balken (`prepare_progress()`) läuft 0,05 → 0,1 (Selbsttest) → 0,65 (Stücke)
  → 0,83 … 1,0 (Aufwärmen, 8 Schritte). Er lief vorher einmal rückwärts (0,1 → 0,05 nach dem Selbsttest) und stand
  während des Ladens der Startansicht bei 0,05; jetzt bleibt ein fertiger Selbsttest bei seinem Schritt, und vor dem
  Laden der Startansicht wird einmal mit dem Balken bei 0,65 gezeichnet. Das Laden der Startansicht selbst ist ein
  Bild von 1,6–1,9 s (alle Stücke auf einmal, `ChunkStreamer.update` beim ersten Aufruf) – offen: über mehrere Bilder
  verteilen.
- **Showroom** (`tools/models_contact_sheet.sh <png> --only="player/*" --showroom`, dieselbe Kamera wie die
  Cycles-Sprites, mit dem Look des Showrooms): Kompakt und Limousine in Echtzeit sind heller und gesättigter, aber
  flacher als ihre Sprites (weniger Form im Schatten, Kunststoffglanz, helle Scheiben). Das Echtzeitbild ist nicht
  mindestens so gut wie das Sprite – `showroom` bleibt für beide `false` (das Manifest bleibt unverändert).
