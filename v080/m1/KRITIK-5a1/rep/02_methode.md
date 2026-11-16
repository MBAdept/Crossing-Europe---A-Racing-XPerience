## 2. Wie geprüft wurde

- **Gegenstand.** Zweig `worktree-wf_db8ba6cd-508-1` (gesichert als `origin/wip/v080-as5a1`), Stand **63544b6**, nur
  gelesen. Gerendert und gemessen in einer Kopie im Arbeitsordner (`m1/KRITIK-5a1/tree`: Arbeitsbaum ohne `.git`,
  `build/` und `_cache3d`, mit seinem Import-Cache; Import geprüft, 0 Fehler). Keine Commits, kein Zweig, keine Datei
  des AS5a1-Arbeitsbaums geändert. Alle Läufe mit `nice -n 19`, immer nur ein schwerer Lauf, absolutes
  `XDG_DATA_HOME` und eigener Mesa-Cache im Arbeitsordner.
- **Messgrundlage.** **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig`); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht
  messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.
- **Lage wie im Rennen.** Eigene Zählung der Etappen des Rennens Kiel – Nürnberg und München (`census_k5.gd`,
  `logs/census_k5.log`): Stadthäuser stehen **nur an den Ankünften** (Hamburg km 75–95, Hannover 130–150, Kassel
  145–165, Würzburg 190–210, Nürnberg 90–110, München 150–170 von Nürnberg aus); an den Abfahrten stellt die
  Strecke keine `props/city_*` auf – „Abfahrt“ ist deshalb in diesem Rennen nicht prüfbar. In den Prüfszenen steht
  jedes Modell wie vom Requisiten-Bauer verankert: Anker = Kante + `extent_l` × Maßstab (`edge_anchor_x`), die Kante aus
  der Zählung (Innenstadt 6,6–10 m, Vorort 12–19 m), links gespiegelt.
- **Werkzeuge** (nur in der Kopie benutzt, aufbewahrt unter `m1/KRITIK-5a1/tools_kritik/` – zum Wiederverwenden nach `tools/kritik/` einer Kopie legen; die Kopie selbst ist gelöscht): `k4_scene.gd` der
  KRITIK-4 (`dist2` Spielkamera bei 10/30/100/250 m mit dem Arcade-Platzhalter derselben Lage darunter, `close`
  Nahansichten, `outline2` Umriss in der Sprite-Kamera – Blickwinkel der Stadt-Sprites −20°/−24° aus
  `props_cities._b()` nachgetragen), `prop_scene --mode=lods` (Stufenwechsel), `my_scene --mode=sparkcam` (AS4R:
  Viertelpixel-Kameraschritte, Anteil kippender Pixel), `tint_scene.gd` (AS5a1), neu: `k5_scene.gd --mode=drive`
  (Spielkamera fährt mit 50 km/h durch eine Straße aus Stadthäusern beidseits, 60 Bilder/s, Stufenwahl mit der
  Hysterese des Requisiten-Bauers, wahlweise als Arcade-Platzhalter), `texel_k5.gd` (Texeldichte je Wandrichtung und
  Höhenband aus UV- und Weltfläche der gebackenen Netze), `py/swappop.py` (Stufenwechsel im Film), `py/bldlum.py`
  und `py/boxlum.py` (Helligkeit Modell gegen Sprite bzw. Arcade gegen Modern).
- **Rennen.** `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand, Seed 11, Limousine, Autopilot,
  fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start) an den Stadteinfahrten Hamburg (Stadtrand und
  Innenstadt), Hannover, Nürnberg und München mittags („Hoch“), Hamburg und Nürnberg um 22 Uhr („Hoch“), Hannover zur
  Dämmerung (19:30, „Mittel“). Ein Modern-Lauf mit zwei Bildern brauchte auf der geteilten Maschine 11–21 min
  (gemessen); Kassel und Würzburg habe ich deshalb nicht gefahren (gleiche Modelle wie Hannover bzw. Nürnberg).
