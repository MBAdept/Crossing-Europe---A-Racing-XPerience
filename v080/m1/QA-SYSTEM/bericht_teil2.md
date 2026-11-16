## 2. Einstellungen, Bestände, Auswahl, Umschalten

**Daten von v0.7.0 echt erzeugt** (nicht von Hand geschrieben): das Spiel v0.7.0 selbst (`git archive v0.7.0`) hat eine
Einstellungsdatei mit Nicht-Standardwerten (Vollbild **Aus gewählt**, Lautstärken 0,55/0,35/0,25, Vibration aus,
Name „Jörg Ü“, Filter „kompakt“), zwei Bestenlisteneinträge (Etappe und Rennen) und über `run_race.gd` einen
Spielstand nach der ersten Etappe von Kiel–Nürnberg geschrieben (`bin/make_v070_data.sh`, Ordner `xdg_v070/`).
v0.8.0 liest dieselbe Kopie (`gd/v080_migration.gd`): **23 von 23 Prüfungen bestanden** (gemessen, `migration.log`):

- alle Werte von v0.7.0 gelesen, „Vollbild: Aus“ bleibt die Wahl des Spielers (die Falle `FULLSCREEN_CHOICE_SINCE` ist
  richtig umgesetzt), neue Schlüssel nicht gewählt (`graphics_mode` leer, Klang „Wie Grafik“, Musik im Rennen an);
- ohne Kommandozeile: Modus Arcade (Grund `default`), Klang Arcade; die Auswahl ist fällig, der Spieler gilt als
  bestehender Spieler (Untertitel „Neu in v0.8.0 …“);
- Speichern schreibt `settings_version` 3, verliert nichts, schreibt keinen ungewählten neuen Schlüssel; ein
  Schlüssel einer späteren Version überlebt Laden und Speichern;
- Wahl „Modern“: genau `graphics_mode` wird gespeichert, Klang folgt (Modern), Auswahl danach nicht mehr fällig;
- Bestenlisten: die Einträge von v0.7.0 unverändert (ohne `gfx`), neue Einträge tragen `gfx` (`modern`, nach einem
  Rückfall `arcade` + `gfx_fallback`); der Spielstand von v0.7.0 lädt unverändert, `gfx_summary()` = `arcade`.
- Rückweg (Information): v0.7.0 liest eine v3-Datei richtig, entfernt beim Speichern aber `graphics_mode` (eingefrorener
  Code von v0.7.0) – wer zurück- und wieder vorwechselt, sieht die Auswahl noch einmal.

**Umschalten mitten in der Meisterschaft** (`gd/qa_champ_switch.gd`, echter `GameFlow`, Autopilot, ohne
`--graphics`; **9 von 9 bestanden**, `champ_switch.log`, keine Fehler- oder Warnzeile): Etappe 1 Arcade (Bild und Klang),
zurück zum Titel, Optionen → Grafik „Modern“ über den Handler der Zeile → Klang folgt sofort im Menü, gespeichert;
„Rennen fortsetzen“ → Etappe 2 in Modern (Bild und Klang); während Etappe 3 Grafik und Klang auf Arcade gestellt →
die laufende Etappe bleibt Modern (Bild und Klang), der Klang wechselt erst auf dem Ergebnisbildschirm; Etappe 4 Arcade;
Rennen `gfx_summary()` = `mixed`.

**Auswahl „GRAFIK WÄHLEN“ genau einmal**: siehe Abschnitt 5 (echter Start ohne Argumente unter Xvfb mit Tastatur) und
die Pad-Prüfung unten.

## 3. Menüs nur mit dem Gamepad, 1280×720 und 1280×800

`gd/qa_pad_walk.gd` mit echten Pad-Ereignissen im echten `GameFlow`, unter Xvfb in beiden Fenstergrößen, Bilder in
`pad/<größe>/`: **14 von 14 bestanden in beiden Größen** (gemessen):

- Auswahl: ▲▼ und B ändern nichts (keine Falle, kein Ausweg – so gewollt), ◀▶ wechselt zwischen genau zwei Karten,
  A übernimmt → Titel; empfohlen ist auf diesem Rechner (llvmpipe) Arcade mit Warnzeile.
- Titel: ▼ von „Rennen starten“ bis „Beenden“ ohne Umbruch (wie v0.7.0), Optionen erreichbar.
- Optionen ALLGEMEIN: ▼ läuft Gesamtlautstärke → … → Zurück → wieder oben; RB → GRAFIK mit Fokus auf „Grafik“; mit
  Modern alle zehn Zeilen, mit Arcade nur Grafik, Vollbild, Leistungstest, Zurück (Qualität gedimmt und übersprungen);
  RB auf der letzten Seite bleibt dort.
- Leistungstest-Seite: ◀▶ zwischen „Leistungstest starten“ und „Zurück“, B → Optionen mit Fokus auf „Leistungstest“;
  B → Titel, gespeichert.
- Absturz-Frage auf dem Titel: Fokus „Bei Arcade bleiben“, B speichert Arcade und entfernt den Marker.
- **Schrift**: kleinste Schrift aller sichtbaren Text-Steuerelemente je Schritt 18,0 px (1280×720 und 1280×800, Streck-
  faktor 1,0). Selbst gezeichneter Text (Karten der Auswahl, Tabelle des Leistungstests, Steuerungstabelle) ist laut
  Code 18–40 px. Bilder angesehen: nichts abgeschnitten, nichts überlappt; 1280×800 zentriert mit freiem Rand unten.
