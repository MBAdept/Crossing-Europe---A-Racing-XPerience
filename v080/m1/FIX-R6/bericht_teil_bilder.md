## 4. Bilder und Urteil gegen Arcade (eigene Bilder, gerendert und angesehen)

Alle mit `tools/ab_shot.sh` (gleicher Simulationszustand, links Arcade, rechts Modern), Modern „Hoch“ bei 1280 × 720,
die Deck-Bilder `--gfx-preset=deck` bei 1280 × 800; Mesa llvmpipe unter Xvfb, `nice -n 10` (gemessen). Die Argumente
stehen unter jedem Bildpaar; Basis-Argumente wie QA-R6 (`--weather=normal --vehicle=limousine --seed=11 --autopilot
--autopilot-refuel=never --traffic-warmup --no-countdown`). Dateien in `…/scratchpad/v080/deliver/FIX-R6/`.

| Datei | Ort | Urteil gegen Arcade (angesehen) |
|---|---|---|
| `01_dev_grenze_tag_mittel_masten.jpg` | DEV km 64,3 + 1,4 s, 12 Uhr | **besser**: das Dach liest sich als abgespannt – Mast links über dem Dach, zwei Zugstangen nach rechts, der zweite Mast hinten; Unterseite, Häuschen als Modelle. Arcade: zwei weiße Pfeiler rechts |
| `02_dev_grenze_tag_nah.jpg` | dieselbe Stelle + 2,0 s | **gleich bis besser**: aus der Nähe verdeckt die Blende die Zugstangen; rechts kein Pfeiler (dort steht in Arcade seiner hinter dem Schild), links der Mast über dem Dach; das Schild „Tankstelle 15 km“ ganz frei |
| `03/04_dev_grenze_nacht_*.jpg` | 21 Uhr | **gleich bis besser**: Lichtbänder, Häuschen mit warmen Fenstern, Masten und Zugstangen gegen den Nachthimmel; die Blende jetzt hellgrau statt grau – Arcades Blende bleibt heller |
| `05_dev_ziel_tag.jpg` | DEV km 129,4 + 2,5 s, 12 Uhr | **klar besser**: weiße Stützen wie Arcade, Fachwerkträger über dem Banner mit drei Flutlichtern – ein echtes Zieltor statt Arcades Balken mit Tafel |
| `06_dev_ziel_nacht.jpg` | 21 Uhr | **klar besser** (vorher leicht schlechter): Banner so rot wie Arcades, Stützen und Träger hell angestrahlt, Flutlichter leuchten, die Ziellinie liegt im Licht |
| `07_dev_start_tag_los.jpg` | DEV km 0, 0,6 s nach „LOS!“ | **besser**: Träger und Flutlichter über dem Startbanner, Lampen grün wie Arcade, Auto wie Arcade |
| `08/09_dev_start_nacht_*.jpg` | 21 Uhr, Countdown „3“ und „LOS!“ | **klar besser**: das Tor steht hell im Flutlicht, Startlinie beleuchtet, „START“ leuchtet (heller als Arcades graue Schrift) |
| `10_kh_ziel_tag.jpg` | Kiel – Hamburg km 94,2 + 1,8 s | **besser** (wie DEV) |
| `11_dev_tankstelle_tag.jpg` | DEV km 18,5 + 2,6 s | **besser** (unverändert gegen R6 bis auf die Endstützen nach Sichtlinien) |
| `12/13_dev_tankstelle_nacht_*.jpg` | 21 Uhr | **gleichwertig, nicht besser**: Dächer, Leuchtkästen und Zapfsäulen hell, ein warmer Lichtfleck vor dem Shop (neu); Arcades ganze, hell leuchtende Gebäudefront fehlt weiter (Modell AS1b) |
| `14/15_kh_tankstelle_km15_*.jpg` | Kiel – Hamburg km 13,4 (Tutorial-Stopp), 12 und 21 Uhr | Tag gleich bis besser; Nacht gleichwertig (wie DEV) |
| `16_deck_grenze_tag.jpg` | Deck 1280 × 800 | wie „Hoch“: Masten und Zugstangen sichtbar |
| `17_deck_tankstelle_nacht.jpg` | Deck | wie „Hoch“ |
| `18_deck_ziel_nacht.jpg` | Deck | wie „Hoch“: Zieltor im Flutlicht |
| `19_ausschnitt_grenze_masten_vorher_gekreuzt.jpg` | erste Fassung | die Zugstangen kreuzten sich am Mast – behoben (`STAY_T` 1,0 / 0,55) |
| `20_ausschnitt_grenze_masten_tag_nacht.jpg` | Endstand | Mast, Zugstangen, Randträger; nachts hellere Blende |
| `21_ausschnitt_zieltor_fachwerk.jpg` | Endstand | Fachwerk, Flutlichtgehäuse |

**Gesamturteil Look (ehrlich):** Start und Ziel sind jetzt bei Tag und vor allem bei Nacht klar besser als Arcade (QA:
„kein Gewinn“, nachts „leicht schlechter“). Die Grenze schwebt nicht mehr und ist bei Tag besser, nachts gleich bis
besser. Die Tankstelle bei Nacht bleibt **gleichwertig, nicht besser** – der Hebel ist das Nachtbild des Shop-Modells
(A-16), nicht R6s Code. Der Blitzer ist unverändert „leicht besser“ (QA). Stadt nicht angefasst (B-05: Leitungsfrage).
