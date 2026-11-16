Kein Befund betrifft die Wasser-Behebung selbst; keiner ist ein Blocker. B1–B3 sind Bildmängel, die schon im vorigen
Build steckten (das Spielpaket ist bis auf `far_ground.gdc` gleich) bzw. erst sichtbar wurden, weil das Wasser jetzt
zu sehen ist; B4–B5 sind Text- und Werkzeugpunkte.

### B1 – mittel – In sechs Städten zeigt Modern kein Wahrzeichen

- **Wo:** `scripts/race3d/prop_library.gd` `_resolve()` und `scripts/race3d/builders/props.gd` (Fall „missing“);
  Ursache in den Daten: sechs `landmark_sets` in `data/cities.json` haben nur eine prozedurale Zeichnung (`proc`) und
  weder Sprite (`assets/sprites/manifest.json`) noch Modell (`assets/models/manifest.json`):
  `hram_svetog_save` (Belgrad), `neues_rathaus_hannover` (Hannover), `voelkerschlachtdenkmal` (Leipzig),
  `florianturm` (Dortmund), `phare_calais` (Calais), `cuatro_torres` (Madrid). `Track._build_landmark()` (eingefroren)
  streicht bei `proc` den `fallback`.
- **Was:** Arcade zeichnet diese Wahrzeichen prozedural (Kuppelkirche, Turm, Leuchtturm, Hochhäuser); Modern lässt sie
  weg. Der Kommentar in `props.gd` („Arcade skips it as well“) stimmt für sie nicht. Hannover liegt auf einem der zwei
  Wege des ersten Rennens Kiel – Nürnberg (und auf Wien – Hamburg, München – Bremen), Calais am Ziel von
  Bukarest – Calais.
- **Beleg:** gemessen in Belgrad: `bilder/linux_ada_bruecke_belgrad_km199_1_ab.jpg`,
  `bilder/linux_belgrad_wahrzeichen_fehlt_in_modern_ausschnitt.jpg` (drei Zeitpunkte, Arcade mit Kirche, Modern ohne).
  Die anderen fünf abgeleitet aus dem Datenabgleich (42 Wahrzeichen-Sets in `data/cities.json`, 6 ohne Sprite und ohne
  Modell). Schon im vorigen Build (Spielpaket-Vergleich, Abschnitt 1).
- **Nachstellen:** `tools/xshot.sh linux <out> 1280x720 modern --stage=slavonski_brod_belgrad --from=slavonski_brod
  --hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=198.6
  --start-speed=80 --shot-times=0.3,2,4` (und dasselbe mit `arcade`).
- **Behebung:** Im Props-Builder ein Wahrzeichen ohne Modell und Sprite mit dem `fallback` aus
  `CityData.landmark_info()` vertreten (Sprite `props/church` bzw. `props/building_tall`, `fallback_scale`,
  `fallback_tint`) – oder Arcades prozedurale Zeichnung einmal in eine Billboard-Textur rendern. Dazu ein Unit-Test:
  „jedes Wahrzeichen aus `data/cities.json` ist in Modern Modell oder Vertretung“. Für diesen Testbuild genügt ein Satz
  in `was_neu.md` (B4).

### B2 – mittel – Köhlbrandbrücke: Pylone nachts fast weiß, Pylonfüße bei Tag verwaschen

- **Wo:** der prozedurale Pylon der Schrägseilbrücke (`prefer_proc` „pylon“) mit seinem Material und dem Licht der
  Brückenlampen (Besitz Brücke/Licht, R4/R5).
- **Was:** Um 22 Uhr leuchten Pylone und Seile fast weiß und überstrahlt, Arcade zeigt sie dunkelgrau. Bei Tag wirken
  die Pylonfüße nah an der Kamera weißlich, weich und rundlich. Ursache nicht untersucht (abgeleitet: Lampen-/Poollicht
  oder Emission am Pylon).
- **Beleg (gemessen):** `bilder/linux_koehlbrand_nacht_hoch_km78_8_ab.jpg`, `…km79_6_ab.jpg`,
  `bilder/linux_koehlbrand_nacht_deck_1280x800_km78_1_ab.jpg`, `bilder/linux_koehlbrand_km78_7_pylonfuesse_modern_ausschnitt.jpg`.
  FIX-WASSER hat das Nachtbild ebenso gesehen.
- **Nachstellen:** `tools/ab.sh linux <out> 1280x720 "…" --stage=kiel_hamburg --from=kiel --hour=22 --vehicle=limousine
  --seed=11 --autopilot --no-countdown --traffic-warmup --gfx-preset=high --start-km=77.6 --start-speed=80
  --shot-times=0.3,2,4,6`.
- **Behebung:** Mit `--gfx-debug=nolight` gegenprüfen, woher das Licht kommt; den Beitrag der Lampen/Pools am Pylon
  begrenzen (Pylonhelligkeit nachts am Arcade-Grau messen); Fuß-Geometrie und Normalen des Pylons prüfen.

### B3 – niedrig – Ufer an hohen Brücken: keine Kaimauer, keine Böschung

- **Wo:** Brückenbau (R5, „Uferwände“ noch offen) und die Uferreihen des Geländes (R2).
- **Was:** Am Ende der Köhlbrandbrücke zeigt Arcade eine graue Kaimauer, Modern Wasser mit weichem Übergang in grünes
  Ufer; an der Holtenauer Hochbrücke zeigt Arcade hinter dem Kanal grüne Böschung, Modern Wasser bis zum Horizont mit
  olivbraunem Streifen – der Kanal wirkt wie ein See. Erst sichtbar, seit das Wasser nicht mehr verdeckt ist; kein
  Rückschritt, kein Loch (2.8).
- **Beleg (gemessen):** `bilder/linux_koehlbrand_tag_hoch_km80_2_brueckenende_ab.jpg`,
  `bilder/linux_holtenau_ab_hamburg_km86_0_ab.jpg`.
- **Behebung:** Kaimauern/Böschungen im Brückenbau; ein fernes Ufer bzw. Fernwasser im Fernboden (Vertragsfrage 3).

### B4 – niedrig – Nutzerdokumente: drei ungenaue Stellen, drei Lücken

- **Wo:** `deliver/FIX-WASSER/was_neu.md`, `deliver/FIX-WASSER/steamdeck_checkliste.md`, `build/SHA256SUMS`.
- **Was und Behebung (Sätze zum Einsetzen):**
  1. `was_neu.md`, Bergetappen (QA-ZS1-B4, offen): „Vor und in Kurven fehlen auf der Innenseite noch Bäume und Felsen
     (absichtlich, damit nichts die Sicht nimmt) – auch auf flachen Etappen, z. B. links am Start von Kiel – Hamburg;
     Bodendecker kommen noch.“
  2. Checkliste, Notfall: das Spiel liest Startargumente nur **nach** `--` (`scripts/core/cli_args.gd` →
     `OS.get_cmdline_user_args()`); für Windows schreiben: „Windows: an das Ziel der Verknüpfung
     ` -- --graphics=arcade` anhängen (mit den zwei Strichen davor, wie bei Steam).“
  3. `SHA256SUMS` nennt zwei nicht gelieferte Dateien – `sha256sum -c SHA256SUMS` meldet „FAILED open or read“ (QA-ZS1-B3,
     offen): in der Checkliste `sha256sum -c --ignore-missing SHA256SUMS` nennen oder `tools/build_testbuild.sh` die
     Summen nur der gelieferten Dateien schreiben lassen.
  4. `was_neu.md`, „Was noch fehlt“, ergänzen: „Nachts leuchten die Pylone der Köhlbrandbrücke noch viel zu hell.“ –
     „In Belgrad, Hannover, Leipzig, Dortmund, Calais und Madrid fehlt in Modern noch das Wahrzeichen.“ – „An hohen
     Brücken fehlen noch Kaimauern und Böschungen; hinter breiten Flüssen zeigt der Horizont einen Streifen Wiese statt
     des fernen Ufers.“
- **Beleg:** Texte gelesen, Code gelesen (`cli_args.gd` Zeile 13), `sha256sum -c` wie bei QA-ZS1; Bilder zu 4 oben.

### B5 – niedrig – Werkzeuge: alte Regel in der Draufsicht, keine Render-Prüfung am Wasser

- **Wo:** `tests/race3d/check_terrain_plan.gd` Zeile 350 (`--dump` schreibt `far_y` = tiefste Straße − 4 m);
  `tests/race3d/render/check_terrain_cover.gd` (T1–T4, S1, C1 – keine Position mit Wasser).
- **Was:** Die Draufsicht-Daten zeigen an tiefen Brücken eine falsche Scheibenhöhe (nur Debug); ein Rückfall der
  Behebung im Bild würde keine Render-Prüfung rot machen (der Unit-Test bewacht die Rechnung, 4.3).
- **Beleg:** Code gelesen; meine Messung 2.8 zeigt, dass die Prüfung an der Köhlbrandbrücke grün wäre (0 Löcher).
- **Behebung:** `check_terrain_plan.gd` über `FarGround.target_height()` rechnen; in `check_terrain_cover.gd` eine
  Position „Köhlbrandbrücke km 78,1“ (Kiel – Hamburg ab Kiel, Deck-Stufe) mit der Grenze 0,2 % Magenta aufnehmen.
