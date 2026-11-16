## 8. Hinweise an andere Pakete und an die Leitung

1. **R2/R7 – Felsen nicht frei drehen:** Die Klippe (und jede Wand mit Schauseite) braucht ein Manifest-Kennzeichen
   und höchstens ±20° Drehung (M2). Eine quer gestellte 26-m-Klippe kann außerdem bis etwa 3 m an die Fahrbahn reichen
   (gefolgert) – auch für F7 prüfen: der Korridor wird nur am Anker gefragt.
2. **R2/R7 – Stufenwechsel:**
   - Die Stufe wird je 96-m-Chunk gewählt; eine ganze Baumreihe springt im selben Bild.
   - `leaves` und `billboard` haben keine Überblendung wie `vpbr` (RINT-B `XFADE_S`).
   - Vorschlag: Dither-Überblendung über 0,3–0,5 s (M6).
3. **R2/R7 – Hang:** Pflanzen an die Bodennormale kippen, Felsen auf den tiefsten Bodenpunkt ihrer Grundfläche setzen
   (M7).
4. **R2/R7 – Fernbild mit eingebackenem Licht:** Ein vorgerendertes Fernbild (Sprite-Rig) mit `baked_light` wie die
   Stand-ins würde Kontrast und Sättigung des Sprites halten (M5). Das Kennzeichen liefert AS3-N.
5. **R2/R7 – Kurvenkorridor (F7, A-3):** Bergstrecken wirken leerer als in Arcade. Im Rennbild fehlen der innere
   Waldrand (Dortmund–Frankfurt km 122) und zwei Klippen (Lyon–Bern km 144,0 / 145,2) (Bild 16). Das hat AS3 schon
   gemeldet; ich bestätige es mit eigenen Bildern.
6. **PIPE/Leitung – Texturbudget:** 37,1 von 60 MB Texturquellen sind belegt, bevor Städte und Wahrzeichen kommen.
   Der gemeinsame Atlas der Varianten spart 15,8 MB sofort (M9).
7. **Prüfer (`validate_models.py`) könnte zusätzlich prüfen:**
   - Bodenkontakt für `tree` / `plant` / `rock`: der tiefste Punkt liegt mindestens 0,1 m unter 0
     (heute nur Räder; `cover_grass` hat 0,00).
   - Byte-gleiche Texturen zwischen Modellen.
8. **R4 – Nacht und Dämmerung:**
   - Nachts im Rennen gleich hell wie Arcade (gemessen); nichts zu tun.
   - In der Dämmerung sind Modern-Bäume 10–22 % heller als das Sprite (AS3 gemessen, hier bestätigt: Fernbild gegen
     Sprite in 200 m).
   - Der Schnee- und Nässe-Term im `leaves.gdshader` fehlt noch; die Normalen der Modelle sind dafür brauchbar,
     außer bei der Zypresse (M11).
9. **R2 – Testpatch:** `tests/unit/race3d/test_props.gd` nimmt `props/tree_beech` als Set ohne Modell (von AS3
   gemeldet, Vorschlag liegt bei AS3). Nicht von mir geprüft.

