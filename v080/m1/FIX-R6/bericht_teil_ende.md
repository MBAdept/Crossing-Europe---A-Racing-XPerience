## 5. Abweichungen, Vertragsfragen, Hinweise

### 5.1 Abweichungen

1. **B-01 nicht mit QAs Ein-Zeilen-Vorschlag (a), sondern mit Masten und Zugstangen (b).** Begründung mit Messung in
   Abschnitt 1: der äußere vordere Pfeiler in der Sichtschneise verdeckt an 3 der 5 Dächer 36–174 Sichtlinien zu Autos,
   die Arcades Pfeiler nicht verdeckt; Brief-Entscheidung 7 und A-10 verlangen die strenge Lesart.
2. **Die Pfeiler-/Stützen-Entscheidung liegt jetzt auf dem Hauptthread in `collect()`** (vorher Sichtschneisen-Test in
   `build()`): nur so bekommt ein Dach, das über zwei Stücke reicht, eine Entscheidung, und ein Dach ohne Stütze lässt
   sich erkennen. `bend_corridor_at()` rechnet denselben Test wie `ChunkContext.in_bend_corridor()` aus Track und
   TerrainProfile (Unit-Test vergleicht beide an den DEV-Pfeilern).
3. **Mehr Hauptthread-Arbeit an Tankstellen:** die Sichtlinienprüfung kostet 1–4 ms je Dach (gemessen, Last 12); sie
   wird ein Dach voraus verteilt (höchstens 1,1–6,7 ms je Stück statt 0,1–0,6 ms auf der Basis). Gefolgert: auf echter
   Hardware ohne fremde Last deutlich weniger; auf dem Deck nachmessen.
4. **Neue Lampen über `renderer.add_lamps()`:** drei Flutlichter je Tor (mit Kegel) und ein Shop-Vorplatzlicht je
   Tankstellengebäude (mit Kegel). Sie konkurrieren um die 16 nächsten Kegelplätze der Ebene `lights` (R4) – an der
   Tankstelle mit den Dächern (Render-Prüfung `tankstelle` siehe Abschnitt 2).
5. **Modern-Änderungsmelder erneut geändert** (`tests/golden/modern_slice.md5/.env`, Spalte W3 „–“): Starttor mit Fachwerk
   und weißen Stützen (gewollt); siehe Abschnitt 2. Beim Zusammenführen ohnehin `modern-make` auf dem Gesamtstand (B-07).
6. **Notfall-Endstütze:** ein Dach, das sonst ohne Stütze wäre, behält seine Endstütze auch wenn sie eine ferne Tafel
   teilweise verdeckt (3 Dächer im Netz, Tafeln 6–7 px aus 195–240 m) – lieber das als ein schwebendes Dach.

### 5.2 Vertragsfragen

1. **Strukturen im Kurvenkorridor (F7).** D14 F7 nennt nur Gelände und dekorative Vegetation; die Brief-Entscheidung 7
   schließt Pfeiler und Stützen ein, Arcades eigene Pfeiler sind ausgenommen. Ich habe Arcades Pfeiler an Arcades Stelle
   stehen lassen und jeden anderen aus dem Korridor genommen; die Abspannung liegt ganz über der Platte. Bitte bestätigen,
   dass eine einseitig abgespannte Grenzstation (5 von 48) so gewollt ist – die Alternative (QA a) verdeckt messbar Autos.
2. **Kosten auf dem Hauptthread in `collect()`** (Abweichung 3): der Vertrag hat ein Budget für `render()` und das
   Einhängen, keines für `collect()`. Falls das Deck dort Spitzen zeigt, kann die Sichtlinienprüfung in `prepare()` für
   die ersten Stationen und danach über mehrere Bilder laufen (braucht einen Hook im Streamer – R4).

### 5.3 Hinweise für die Nächsten (genaue Änderungen in fremden Dateien)

1. **AS-Modellpaket (A-16):** `props/fuel_station` (und `props/customs_booth`) – Fenster und Leuchtband in den
   Nachtlicht-Atlas der Klasse `baked`; das ist der eine Hebel, der die Tankstelle bei Nacht klar besser als Arcade macht
   (Arcades Gebäude leuchtet als Ganzes).
2. **R4 `layers/lights.gd`:** Stärke je Bild aus den Einträgen lesen (wie `flares`), dann bekommt der Blitzer einen
   kurzen Lichtkegel auf der Fahrbahn (B-03 Blitzer).
3. **R4 `layers/flares.gd`:** Einträge mit Rolle `"on"` und `energy` 0 überspringen (QA-R6); optionale Schlüssel `glow`
   und `halo` (R6).
4. **R4 `docs/renderer-modern.md` §14.4/§14.5:** ein Satz mit Verweis auf `docs/renderer-modern-bauten.md`.
5. **RINT-M2:** `tools/golden.sh modern-make` einmal auf dem Gesamtstand (R4, R5, R6/FIX-R6 ändern `modern_slice.md5`).
6. **Leitung, B-05:** Stadtzäune im Kurvenkorridor folgen der Korridor-Entscheidung (FIX-M2 B-01); `city.gd` übernimmt
   eine Änderung von `in_bend_corridor()` von selbst.
7. **QA / später:** die Grenzpfeiler am Dachende (nicht Arcades) verdecken in Kurven noch 8 + 15 Tafel-Paare
   (`border_end` 8, davon 0 mit ≥ 6 px; `border_end_out` 15, davon 1; `scan_f1`); dieselbe Sichtlinienprüfung wie an der
   Tankstelle ließe sich dort übernehmen.

## 6. Commits (alle auf `origin wip/v080-fix-r6`)

| Commit | Inhalt |
|---|---|
| `ffca594` | B-01 Abspannung (`support_plan`, `supports_in_chunk`, Masten, Zugstangen, Randträger), B-02 erste Sichtlinienprüfung, B-04 Arcades Literale in den Tests |
| `fc312bf` | Stützen je Dach einmal entschieden (Zwischenspeicher), Sichtlinien beidseitig bis 600 m, Notfall-Endstütze; Tore mit Fachwerk, Flutlicht, weißen Stützen, Nachtbild 0,8 |
| `d5c5b52` | Zugstangen kreuzungsfrei, Kameras alle 5 m, Shop-Vorplatzlicht, hellere Grenzblende nachts, Doku |
| `b185bb8` | Kommentar und Doku: Zahl der Notfall-Endstützen |
| `2c75af0` | Sichtlinienprüfung billiger (nur nötige Kameras, Sinus statt Winkel, ein Dach voraus), gleiche Entscheidungen |
| (Abschnitt 2) | Modern-Änderungsmelder neu |

Geänderte Dateien (alle im Besitz von R6 bzw. Leitungsausnahmen von R6): `scripts/race3d/builders/{border,station,
gantry}.gd`, `tests/unit/race3d/test_structures.gd`, `docs/renderer-modern-bauten.md`, `tests/golden/modern_slice.{md5,env}`.
Keine eingefrorene Arcade-Datei, keine Datei von R4/R5.

## 7. Werkzeuge und Rohdaten (Scratch, nicht committet)

`…/scratchpad/v080/m1/FIX-R6/`: `bin/border_probe.gd` (Pfeiler und Sichtlinien zu Autos je Grenzdach), `bin/scan_all.gd`
und `bin/scan_f1.gd` (Kopien von QA-R6, `scan_all` zählt Masten), `bin/canopy_time.gd` und `bin/collect_time.gd`
(Hauptthread-Kosten), `bin/mutate.sh` (B-04), `bin/shots1.sh`, `bin/shots2.sh`, `bin/gates.sh` (Gate-Kette, neu startbar);
Logs in `logs/`, `gates/` (Lauf 1 auf `b185bb8` in `gates/run1/`), `perf/`; Einzelbilder in `shots/`.
