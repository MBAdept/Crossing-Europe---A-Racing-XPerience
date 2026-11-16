# AS2b – Lkw, Busse, Polizei: Bericht

Paket AS2b (Welle 4, M2 Teil 2), Arbeitszweig `worktree-wf_72970c4d-66e-3`, Sicherungskopie
`origin/wip/v080-as2b`. Basis: AS2a-Endstand `19aa138e`. Alle Bilder sind mit Software-OpenGL (llvmpipe, Xvfb)
im Kontaktbogen des Repositorys gerendert; wie es auf dem Steam Deck oder einer echten GPU aussieht, ist
**abgeleitet**, nicht gemessen. „gemessen“ = auf dieser VM ermittelt, „abgeleitet“ = gerechnet.

## Ergebnis in Kürze

Jedes Fahrzeug-Set des Spiels hat jetzt ein Modell (gemessen im Manifest: 5 Spieler, 5 Showroom, 33 Verkehr,
18 Polizei – kein Fahrzeug-Platzhalter mehr):

| Modell | Bauer | Sets | Dreiecke lod0 / lod1 / lod2 / Schatten (gemessen) |
|---|---|---|---|
| `traffic/truck` | `ce3d/truck3d.py` | `traffic/truck_white` (Koffer LOGISTIK) | 19 010 / 5 174 / 1 346 / 476 |
| `traffic/truck_transport` | `truck3d` | `traffic/truck_blue` (Koffer TRANSPORT) | 19 134 / 5 260 / 1 346 / 476 |
| `traffic/truck_tarp` | `truck3d` | `traffic/truck_red`, `traffic/truck_green` (Plane) | 23 412 / 5 168 / 1 270 / 476 |
| `traffic/bus` | `ce3d/heavy3d.py` (neu) | `traffic/bus_white`, `_red`, `_blue` | 19 238 / 6 398 / 1 500 / 516 |
| `police/<land>` × 18 | `ce3d/police3d.py` (neu) | je ein Set | 19 778–21 970 / 5 331–5 991 / 1 044–1 185 / 1 020–1 084 |

Budgets (§4.6.9): Lkw/Bus 25 000 / 7 000 / 1 500, Polizei 22 000 / 6 000 / 1 200, Schatten ≤ 3 000 – alle
eingehalten (Prüfer: `CHECK models OK`). Der Bus liegt in `lod2` genau auf 1 500.

## Abnahme

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Prüfer `validate_models.py` | grün | `CHECK models OK`, 37 Modelle, 180 Sets (65 mit Modell), Netze 16,4 MB von 40 MB |
| alle 7 schweren und 18 Polizei-Sets lösen auf | ja | Manifest: kein Fahrzeug-Set ohne `model` (gemessen) |
| Blaulicht A/B wechseln | ja | Nachtbogen je Kanal (Bilder 09, 10): A = linke Hälfte (Kanal 10), B = rechte (Kanal 11), beide mit Lichtanker; Spielkamera-Kachel „Rücklicht + Blaulicht A“ (04–06) |
| Teilquader = Arcade-Teile, Kollision unverändert | ja, mit zwei Überständen aus AS1 (siehe unten) | Netz-Dump der Zwischenstände (gemessen) |
| Lkw/Bus knicken über Gruppen mit Drehpunkten wie der AS1-Sattelzug | Lkw ja (alle drei: `tractor`, `trailer` = Königszapfen), Bus starr | `groups` in `model.json`; R3-Prüfung `kasten`: Sattelzug in 2 Einheiten; der Arcade-Bus ist ein Quader mit einem Teil `body` |
| Budgets §4.6.9 | eingehalten | Tabelle oben |
| `check_sprite_geometry` | 25 von 25 identisch | „Gates“ |
| Export-Determinismus | ja | „Gates“ |
| `tools/run_tests.sh` (einmal, am Ende) | 2 von 79 Prüfungen rot (R3 `kasten`, `leistung`), Unit-Tests grün | „Gates“ |
| `tools/golden.sh check` | 20 von 20 identisch | „Gates“ |

### Teilquader (gemessen, Netz-Dump `lod0`, Modellraum, Front bei −Z)

| Teil | Modell | Arcade-Teil | Abweichung |
|---|---|---|---|
| Auflieger (alle drei) | x ±1,275 (Plane ±1,276) · y 0,21–4,00 · z −5,35…8,291 | `trailer` ±1,275 · 0–4,0 · −5,35…8,25 | hinten 41 mm (Unterfahrschutz, Leuchtenträger) |
| Fahrerhaus ohne Spiegel | x ±1,24 · bis 3,878 m · über 1,5 m z −8,26…−5,46 | `cab` ±1,25 · 0–3,80 · −8,25…−5,75 | Dachspoiler +78 mm, Rückwand 0,29 m im Spalt zwischen den Teilen (aus AS1, unverändert) |
| Spiegel Zugmaschine | bis ±1,535 | – | wie AS1 |
| Bus ohne Spiegel | x ±1,275 · y 0,37–3,65 · z ±6,43 | `body` ±1,275 · 0–3,65 · ±6,4 | Stoßfänger je 30 mm |
| Bus-Spiegel | bis ±1,505, 0,435 m vor der Front in 2,2–2,9 m Höhe | – | über jedem Pkw-Dach |
| Polizei (z. B. `de`) | x ±1,075 (Spiegel) · bis 1,647 m · z ±2,40 | Objekt 1,84 × 4,80 × 1,65 | innerhalb der Toleranz des Prüfers |

Die Kollision rechnet weiter mit den Arcade-Teilen aus dem Sprite-Manifest; kein Modell ändert sie.

## Was gebaut wurde

**Sattelzüge** (`truck3d.py`, Modell aus AS1 erweitert): drei Bauarten wie `heavy.TRUCK_VARIANTS` – Koffer mit
Streifen und Schriftzug (Glyphen der Sprite-Schrift, `paint3`), Planenauflieger mit gewellter Plane und 22 Gurten
(Schnallen in `lod0`). Fahrerhaus mit Glas-Scheiben (Klasse `glass`), Dachleuchten (Kanal 9), Seitenblinkern.
Ein Modell je Bauart, die Farbsets sind Lack (Instanz-Uniforms). Heck bei 20–150 m: Konturmarkierung (Kanal 14),
Leuchtenträger, Dreiecke, Kennzeichen, Unterfahrschutz, Schmutzfänger – Bild 01/02.

**Bus** (`heavy3d.py`, neu): Loft-Hülle mit gerundeten Enden und echten Radläufen, Fensterband mit sieben
Scheiben, Doppeltür, Fahrerfenster, Streifen, Gepäckklappen, Zielanzeige (LED, Kanal 13), hohe Rückleuchten,
dritte Bremsleuchte, Umrissleuchten, Lüftungsgitter, Stoßfänger mit Kennzeichen, Radlaufverkleidungen, Spiegel an
Armen, Räder des Lkw (0,5 m, hinten Zwillingsräder). Bild 03, 16.

**Polizei** (`police3d.py`, neu): das Verkehrsauto aus AS2a (`traffic3d`) mit der Lackierung des Sprite-Katalogs in
die Karosserie geschnitten (eine Lage), dem Landeswort auf Flanken und Heck (Glyphen, nur `lod0`) und einem
Lichtbalken mit Tiefe (Glaskuppeln über je drei LED-Modulen, weißes Mittelteil; `lod1`/`lod2` leuchtende Blöcke auf
derselben Fläche). Die Polizei hakt sich zur Laufzeit in drei Schritte von `traffic3d` ein (`police3d._hooks`), die
Dateien von AS2a bleiben unberührt; eine Nacharbeit an den Verkehrsautos erreicht die Polizei mit. Bilder 04–10, 13–15.

## Runden (bauen, ansehen, ändern)

1. Polizei erste Fassung: Budget weit überschritten (Bänder über der ganzen Karosserie, Fächer der Endkappen) →
   Lackierungslinien als Loft-Zeilen, Endkappen mit den Linien neu trianguliert, Schwellen für kleine Dreiecke,
   gröbere Lofts je Basis. Das „L“ von POLIZEI fehlte (fette Glyphen überlappen, Loch-Test per Enthaltensein) →
   Umlaufrichtung der Randkanten.
2. Bus: über Budget → gröbere Stationen, Zeilen im Loft, ferne Reifen ohne innere Flanke; Schattenfleck am
   Radlauf (Rundung 6 cm) → 3 cm.
3. Planenauflieger: `lod2` über Budget → Gurte nur bis `lod1`; Spalt zwischen Plane und Rahmen → Randzeilen.
4. Blaulicht: in `lod0` kleiner und dunkler als die Blöcke von `lod1` → größere Module, Kuppel klarer, ferne
   Blöcke auf die Modulfläche.
5. Diese Runde (Bilder aller Abnahmepunkte, Stufenwechsel gemessen):
   - Belgien/Schweiz/Litauen/Lettland/Rumänien verloren bei 40 m die Karos (29,9 % der Autopixel wechselten) →
     `lod1` zeigt die Karos auf den Stoßfängern (Heck und Front); die Enden der Karosserie liegen hinter den
     Stoßfängern und werden nicht mehr geschnitten (770 verdeckte Dreiecke gespart), dafür je Radlauf und Ende eine
     Station weniger: 18,8 %.
   - Bus: Lüftungsgitter fehlte in `lod1` (das Sprite zeigt dort das graue Feld; 16,7 %) → Gitter in `lod1`
     (6,7 %), in `lod2` zwei breite Stäbe.
   - Schattenwerfer: Endflächen des Bus-Werfers lagen in der Ebene von Heck und Front (im Bogen `--caster` das
     ganze Heck rot) → 3 cm innen; der Werfer-Block des Lichtbalkens umschloss Module und Leuchtblöcke (sie lagen
     bei Tag im eigenen Schatten) → aus Teilen, überall 1 cm innen.
   - Sattelzug bei 180 m: `lod2` hatte ein glattes Heck ohne die vier Verschlussstangen (27,5 % der Lkw-Pixel
     wechselten) → Stangen als Leisten wie in `lod1` (+48 Dreiecke): 1,2 %.

## Stufenwechsel (gemessen, Spielkamera von hinten, Tag)

Anteil der Fahrzeugpixel, die sich beim Wechsel um mehr als 24 Stufen ändern (Werkzeug wie AS1R/AS2a: Fahrzeugpixel
= mehr als 24 Stufen neben dem Zeilenmedian des Hintergrunds):

| Modell | nah | fern |
|---|---|---|
| `police/de` | 40 m: 13,8 % | 120 m: 35,6 % |
| `police/be` | 40 m: 18,8 % (vorher 29,9 %) | 120 m: 59,0 % (vorher 41,0 %) |
| `traffic/bus` | 60 m: 6,7 % (vorher 16,7 %) | 180 m: 23,2 % (vorher 9,7 %) |
| `traffic/truck_tarp` | 60 m: 2,4 % | 180 m: 1,2 % (vorher 27,5 %) |

Karos und Gitter wechseln jetzt beim fernen Wechsel (Fahrzeug 11 × 10 bzw. 10 × 14 Bildpunkte); in Bildpunkten
bei 1280 × 720 zusammen weniger als vorher: Belgien 270 statt 374, Bus 151 statt 302 (abgeleitet).
Zum Vergleich AS2a (Verkehrsautos): 40 m 4,7–9,3 %, 120 m 32–37 %.

## Schwächen (ehrlich)

- **Lichtbalken bei Tag:** Die Glaskuppel von `lod0` wirkt heller als die Blöcke von `lod1` (der Hauptteil der
  13,8 % bei 40 m, dazu Wörter und Kennzeichenzeichen, die es nur in `lod0` gibt).
- **Karos auf den Flanken** zeigt `lod1` nur in der Mischfarbe (bei Tag ein blasses Oliv/Beige, im übersteuerten
  Kontaktbogen fast Gelb); der Wechsel bei 120 m ist bei Belgien mit 59 % der größte aller Modelle.
- **Weißer Lack** (Koffer, weißer Bus, Polizei) erscheint im Kontaktbogen als reines Weiß ohne Form – Belichtung des
  Renderers (bekannt seit AS1R), nicht im Netz lösbar.
- **Kein Innenraum** in Fahrerhaus und Bus, dunkles Glas. Der Bus ist starr (das Sprite kennt keinen Gelenkbus).
- **Polizei hängt an `traffic3d`:** Die Laufzeit-Hooks setzen Funktionsnamen und -signaturen von AS2a voraus
  (`traffic_design`, `decalgeo.car_surfaces`, `SmoothCar.lower_half`, `bumper_half_fn`); ändert die Nacharbeit
  der Verkehrsautos sie, bricht der Export der Polizei laut ab (kein stilles Fehlbild).
- `lod2` des Busses steht genau auf dem Budget (1 500).
- Rote Räder im Werfer-Bogen der Polizei: die Trommeln des Verkehrsauto-Werfers (AS2a), wie bei allen
  Verkehrsautos.

## Vertragsprobleme

Siehe Rückgabe (`contract_issues`); ausführlich:

1. `tests/race3d/check_vehicles.gd`, Prüfung `kasten` (R3): verlangt, dass `traffic/sports_red` und `police/at`
   **keine** Modelle haben und als Kasten erscheinen. Seit AS2a (Sportwagen) und AS2b (Polizei) hat jedes
   Fahrzeug-Set ein Modell – die Prüfung kann so nicht mehr grün werden. Sie braucht ein Prüf-Manifest mit einem
   Set ohne Modell (Eigentümer R3).
2. Polizei-Budget `lod1` 6 000 / `lod2` 1 200 = Verkehrsauto, obwohl Lackierung, Wörter und Lichtbalken
   dazukommen: Die Polizei-Lofts sind gröber als die der Verkehrsautos (`POLICE_DETAIL`), die Karos der Flanken
   gibt es nur in `lod0`.
3. Eigentum §5: Die Polizei braucht Eingriffe in `traffic3d`/`decalgeo`/`carbody` (AS2a/AS1). Gelöst als
   Laufzeit-Hooks in `police3d` (Kontextmanager), ohne die Dateien zu ändern; sauberer wären offizielle
   Hook-Parameter in `traffic3d` (bei der Nacharbeit von AS2a).
4. Eigentums-Muster `assets/models/traffic/{truck_*,bus_*}` nennt Ordner je Set; die Modelle sind je Bauart
   (AS1: `traffic/truck` für alle Lkw-Sets). Ich habe `traffic/truck` (AS1, mit meinem `truck3d` neu erzeugt)
   behalten und den Bus `traffic/bus` genannt – beide liegen außerhalb des wörtlichen Musters, gehören aber keinem
   anderen Paket.
5. Arcade-Teil `cab` (3,80 m hoch, endet bei −5,75) gegen das Fahrerhaus aus AS1 (3,878 m, Rückwand bis −5,46):
   Das Modell ragt 78 mm über und 0,29 m hinter den Teilquader – unverändert gelassen, die Kollision rechnet mit
   den Arcade-Teilen.
6. `check_vehicles.gd` `leistung` (R3) verlangt null Knotenbauten in 120 Bildern, die Fahrzeug-Ebene baut eine Stufe
   aber beim ersten Gebrauch: Ein Verkehrsauto der Etappe (`traffic/sports`, AS2a), das die 120-m-Grenze überquert,
   reicht (diagnostiziert, unabhängig von AS2b). Entweder baut die Ebene die Stufen vorab, oder die Prüfung schließt
   Stufenwechsel aus (Eigentümer R3).

## Hinweise für die Nächsten

- Die Nacharbeit der Verkehrsautos (AS2a-Kunstkritik) erreicht die Polizei automatisch; danach die Polizei
  neu exportieren und die Budgets prüfen (`lod1` liegt bei bis zu 5 991 / 6 000).
- Renderer (R3/R4): `groups` der drei Sattelzüge auswerten (Knicken um den Königszapfen); unbeleuchtete Lampen
  dunkler (`lamp_off`); Weiß nicht übersteuern.
- `tests/race3d/check_vehicles.gd` `kasten`: Prüf-Manifest mit einem Set ohne Modell.
- Ein Gelenkbus braucht zuerst ein Sprite-Set mit zwei Teilen.

## Gates (gemessen, Endstand)

| Gate | Ergebnis |
|---|---|
| `validate_models.py --report` | **CHECK models OK** (37 Modelle, 180 Sets, 65 mit Modell; Netze 16,44 MB von 40 MB) |
| Budgets §4.6.9 | eingehalten (Höchstwerte: Polizei 21 970 / 5 991 / 1 185, Lkw/Bus 23 412 / 6 398 / 1 500, Schatten 1 084) |
| `check_sprite_geometry.py --only traffic/truck,traffic/bus,police --jobs 1` | **25 von 25 identisch** (67 s); `cesprites` ist in AS2b unverändert |
| Determinismus | erzwungener Export + Bake aller 22 AS2b-Modelle → `git status` leer (byte-genau die eingecheckten Dateien); weiterer Bake byte-gleich (142 Dateien); `--check-keys`: **CHECK cache_keys OK** |
| `tools/run_tests.sh` (einmal, 593 s) | 241 Skripte fehlerfrei, **594 Unit-Tests, 0 fehlgeschlagen**, 79 CHECK-Zeilen, davon **2 rot** in `tests/race3d/check_vehicles.gd` (R3): `kasten` und `leistung` – siehe unten |
| `tools/golden.sh check` (einmal) | **GOLDEN arcade: 20 von 20 identisch** (215 s) |

**`kasten`** (rot, erwartet): verlangt Kästen für `traffic/sports_red` und `police/at` – beide haben jetzt Modelle
(AS2a bzw. AS2b). Der zweite Teil der Prüfung ist grün: Der Sattelzug wird in `lod0` in **zwei Einheiten**
(Zugmaschine, Auflieger) gezeichnet – die Gruppen der AS2b-Modelle funktionieren in der Fahrzeug-Ebene von R3.

**`leistung`** (rot, nicht durch AS2b): „keine Knoten gebaut, solange dieselben Autos fahren (34 → 35)“. Diagnose
mit einem Nachbau der Prüfung (Skript im Scratch, nicht im Repository): Der eine Bau ist Verkehrsauto 1 der Etappe,
`traffic/sports_yellow` (Modell `traffic/sports` aus AS2a), das sich entfernt und bei Bild 31 die 120-m-Grenze
überquert (`lod1` → `lod2`, 118,3 → 126,2 m): Die Fahrzeug-Ebene baut eine Stufe beim ersten Gebrauch. Keines der
AS2b-Modelle wechselt in diesem Fenster die Stufe (alle 23 eingespielten Autos stehen). Die Zeit je Auto lag im
Lauf von `run_tests.sh` bei 34,6 µs (Grenze 40), in einem Einzel-Lauf danach bei 44,8 µs (VM unter Last).

## Bilder

Alle im Ordner dieses Berichts; Kontaktbogen des Repositorys (`tools/models/contact_sheet.gd`, Voreinstellung
`low`), Spielkamera = Brennweite 711 px, Horizont 324, Höhe 3,4 m bei 1280 × 720, Kacheln vergrößert (Faktor in
der Beschriftung). Arcade-Vergleich: Quader (Lkw/Bus, Heckfläche des hintersten Arcade-Teils) bzw. Sprite (Polizei,
Zelle mit Heckanker) an derselben Stelle der Spielkamera.

| Bild | Inhalt |
|---|---|
| `01_lkw_koffer_heck_20_60_150m.jpg` | Koffer-Sattelzug, Heck in 20 / 60 / 150 m neben dem Arcade-Quader; Nacht: Rücklicht, Bremslicht + Blinker |
| `02_lkw_plane_transport_heck.jpg` | Planen-Sattelzug (grün) und Transport-Koffer (blau) neben dem Arcade-Quader |
| `03_bus_heck_20_60_150m.jpg` | Bus neben dem Arcade-Quader, Tag und Nacht |
| `04/05/06_polizei_{de,be,it}_heck.jpg` | Polizei neben dem Arcade-Sprite, 20 / 60 / 150 m; Nacht mit Blaulicht A |
| `07_polizei_alle_18_tag.jpg` | alle 18 Polizeiautos, `lod0` |
| `08_polizei_stufen.jpg` | Österreich, Belgien, Deutschland: alle Stufen und Schattenwerfer |
| `09/10_polizei_{de,be}_nacht_alle_kanaele.jpg` | jeder Lampenkanal einzeln, Blaulicht A links, B rechts |
| `11_lkw_bus_stufen_tag.jpg` | Bus und drei Sattelzüge in allen Stufen, Farbsets |
| `12_lkw_bus_nacht_alle_kanaele.jpg` | Sattelzug und Bus, jeder Lampenkanal einzeln |
| `13/14/15_polizei_{de,be,it}_nah.jpg` | Nahansichten: Lichtbalken, Schriftzug, Lackierung |
| `16_bus_nah.jpg` | Bus aus der Nähe, Räder in Radläufen, Heck bei Nacht |
| `17_planen_lkw_nah.jpg` | Plane mit Gurten, Räder, Heck bei Nacht |
| `18_lkw_fahrerhaus_nah.jpg` | Fahrerhaus: Scheiben, Spiegel, Dachleuchten, Tritte, Tank, Radhaus |
| `19_ton_ansicht.jpg` | Formen ohne Farbe |
| `20_schattenwerfer.jpg` | Werfer rot über dem Modell (rot = was aus der Hülle ragt) |
| `21_stufenwechsel.jpg` | Stufenwechsel: Polizei 40 / 120 m, Bus und Plane 60 / 180 m, je Zeile `lod0` / `lod1` / `lod2` |
