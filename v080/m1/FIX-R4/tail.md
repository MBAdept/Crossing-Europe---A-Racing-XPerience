
## 11. Bilder (angesehen; Arcade-Bilder = die der Prüfung QA-R4 am selben Simulationszustand)

Alle in `deliver/FIX-R4/bilder/` als Arcade | Modern R4 (`7f0eae2`) | Modern FIX-R4, „Hoch“ wenn nicht anders genannt.
Modern-Bilder mit `m1/FIX-R4/sh/mshot.sh` (dieselben Argumente wie `tools/ab_shot.sh`, nur der Modern-Lauf; die
Arcade-Bilder der Prüfung gelten, weil Arcade eingefroren und das Bild bestimmt ist – meine R4-Bilder waren
bildpunktgleich mit denen der Prüfung).

| Bild | Stelle | gegen Arcade (ehrlich) |
|---|---|---|
| `01_N2N_22Uhr_Regen_2s_Kegel.jpg` | Dortmund – Frankfurt km 121, 22 Uhr, Regen | **besser in der Luft, jetzt gleichwertig auf der Straße**: der cremefarbene Fleck im Abblendlicht ist weg (Kegel 54 gegen Arcade 61, R4 108), die Markierung im Kegel klar; Regen, Gischt, Himmelsspiegelung bleiben. Arcades Kegel liest sich als etwas hellerer, weicher Fleck – Moderns nasser Kegel ist dezenter (0,88 ×). **Schlechter**: der GT ist hellsilbern statt marineblau-grau (B3, offen) |
| `02_N2N_22Uhr_Regen_4s_Spiegelung.jpg`, `12_B1_Saeule_…jpg` | dieselbe Stelle, 4 s und 6,2 s | die rote Säule über dem Auto 300 m voraus ist weg; die Spiegelung liegt als schmaler roter Streifen unter dem Auto auf der Straße (Arcade: ein Punkt) |
| `03_N2N_SteamDeck_1280x800.jpg` | dieselbe, „Steam Deck“ | dieselbe Behebung im Deck-Preset; Regen sichtbar, 16:10 gefüllt |
| `04_N1_22Uhr_Schnee_2s.jpg`, `05_N1_SteamDeck_1280x800.jpg` | Hamburg – Hannover km 71, 22 Uhr, Schnee | wie R4 (trockene Straße: keine Änderung durch B2); Schneefall, Wälle, Kompakt gelb wie das Sprite – besser als Arcade |
| `06_DEV_21Uhr_Limousine.jpg` | Teststrecke km 48, 21 Uhr | Limousine etwas weniger leuchtend als bei R4 (Sättigung 1,32 → 1,21 × Arcade), weiter etwas blauer als das marineblaue Sprite; sonst gleichwertig |
| `07_C1_19Uhr30.jpg` | Frankfurt km 221, 19:30 | unverändert gegen R4 (gleichwertig bis besser als Arcade) |
| `08_S1_Abend_19Uhr12.jpg` | Kiel – Hamburg km 2, 19:12 | unverändert bis auf die Limousine (minimal blauer); Sonnenscheibe, Gegenlicht – besser als Arcade |
| `09/10/11_Tunnelausfahrt_Tag_….jpg` | Teststrecke km 52,8, 12 Uhr, 1,0 / 2,4 / 3,8 s | gleich R4 (141 km/h: der Weg entscheidet über das Nachglühen); in der Röhre gleichwertig, am Portal milchiger als Arcades sattes Gras (Geschmack, aus R4) |
| `13_Spielerautos_nachts_…jpg` | die vier Fälle von `check_night spielerauto` (Arcade links, FIX-R4 rechts) | GT: hell statt marineblau (offen); Kompakt gleichwertig; Limousine S1 und DEV gleichwertig bis etwas leuchtender |

Clip: `deliver/FIX-R4/clip_nacht_regen_verkehr_N2N.mp4` (A/B, 20 s, 60 fps, „Hoch“) – CLIP_STATUS.
Nicht neu gerendert: Tunnelausfahrt- und Schneefall-Clip (meine Änderungen ändern dort nichts Sichtbares: Tunnel
bei 141 km/h nach dem Weg, Schnee ohne nasse Straße – R4s Clips gelten).

## 12. Tore (auf dem Endstand, Befehle und Ausgaben)

GATES_TABLE

## 13. Leistung (llvmpipe, gemessen; echte Hardware abgeleitet)

STAGE_TABLE

## 14. Vertragsfragen

1. `assets/shaders/modern/flare.gdshader` hat in §5 W3 keinen Besitzer; R4 und FIX-R4 haben ihn geändert (der Shader
   der Ebene `flares.gd`, die R4 gehört). Vorschlag: der Besitzer von `flares.gd` besitzt ihn.
2. `tests/golden/modern_slice.{md5,env}` (W3 „–“): `modern_s1_nacht` hat sich durch B3/B7 gewollt geändert; ich habe die
   eine Zeile mit dem Hash des von `modern-check` gerenderten Bildes ersetzt (gleich dem Ergebnis von `modern-make`,
   die übrigen fünf sind identisch). RINT-M2 erzeugt die Liste nach dem Zusammenführen ohnehin neu.
3. §6 R4 Abnahme kennt die nasse Nacht nicht (QA-R4 Vertragsfrage 3) – jetzt geprüft durch `check_night_nass.gd`
   (Kegel 0,7 … 1,15 × Arcade, Randlinie ≥ 0,8 ×, keine Spiegelung über dem Dach); Vorschlag, das in §6 aufzunehmen.
4. Die Instanzbasis der Streifen trägt Daten statt einer Drehung (Profil der Straße) – nur möglich, weil die Knoten der
   Ebene eine eigene `custom_aabb` haben und der Shader die Basis sonst nicht nutzt; bei einer Änderung des
   MultiMesh-Formats (z. B. 2D-Transform) muss das Profil umziehen. Nicht vertragsrelevant, aber eine Falle.

## 15. Für die nächsten Pakete

1. **FIX-M2 B-06 / R7 (Lack)**: der silberne Gran Turismo nachts im Regen (B3): Sättigung 0,77 × Arcade, hell statt
   marineblau-grau. Der gespiegelte Himmel ist es nicht (mit vollem Himmelston 0,78 ×). Zu prüfen: die Helligkeit der
   senkrechten Metallflächen nachts (das untere Heck liest sich hell), danach `CAR_SAT_MIN` in `check_night` auf
   0,85 heben. `check_night -- --only=spielerauto --fall=Turismo` misst in 90 s.
2. **RINT-M2**: Konflikte wie bei R4 nur in `tests/golden/modern_slice.{md5,env}` (alle) und `docs/renderer-modern.md`
   (R5); `vehicles.gd` mischt sich mit FIX-M2 automatisch (gemessen mit `git merge-tree`). Nach dem Zusammenführen
   `golden.sh modern-make` (Bilder ansehen). FIX-M2s `player_paint()` (Entsättigung bei Tag) und mein `sheen_wash`
   (Nacht) ergänzen sich – die Limousine in der Dämmerung danach ansehen (beide wirken dort zum Teil).
3. **Pakete mit eigenen Spiegelungen** (R5 Wasser, R6 Tankstelle): Streifen auf nasser Straße bekommen ihr
   Höhenprofil über `flares.gd` `road_profile()` / `put_profile()`; statische Lampen über `add_lamps()` bekommen es
   automatisch.
4. **PERF**: das Profil kostet je Auto mit Spiegelung 7 Aufrufe `height_at()` (gemessen +0,06 ms `vehicles`,
   +0,03 ms `flares` im Mittel der nassen Nachtetappe); auf dem Deck abgeleitet vernachlässigbar.
5. **QA**: `test_chunk_services` „threaded“ und `test_engine3_checks` „thread“ sind lastabhängig (QA-R4) – falls sie im
   Vollauf rot sind, nicht FIX-R4.
