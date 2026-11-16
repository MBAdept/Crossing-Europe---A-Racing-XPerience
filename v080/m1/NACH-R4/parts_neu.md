- **N1 – niedrig – Leistung der Laternen-Profile in Städten nicht gemessen.** `flares.gd _lamp_profile()` rechnet je
  Laterne mit Spiegelung und Bild ein Profil (7 `height_at()`), auch wenn sich die Kamera kaum bewegt hat. Gemessen
  (Einzeltest headless, Last 8+): 4,2 µs je `road_profile()` → 100 Streifen ≈ 0,42 ms je Bild auf dieser VM; FIX-R4 hat
  nur die Autobahn Kiel – Hamburg gemessen (+0,02–0,06 ms). Vorschlag: Profil je Laterne zwischenspeichern und erst neu
  rechnen, wenn die Kamera ≥ 2–5 m weiter ist; an C1 21:30 Regen messen (PERF / QA-M2-BILD). Steam Deck abgeleitet.
- **N2 – niedrig – Prüflücke Laternen-Streifen.** `check_night_nass` „spiegelung“ prüft nur die Rückleuchten eines
  Verkehrsautos; den Laternenweg (`_drop_of()` merkt die Straßenstelle, `_lamp_profile()`) bewacht nur das Bild der
  Köhlbrandbrücke (`bilder/04`). Vorschlag: einen Fall mit statischen Lampen auf einer Rampe (Köhlbrandbrücke km 79,
  22 Uhr, Regen) in „spiegelung“ aufnehmen.
- Keine weiteren neuen Befunde: keine eingefrorene Datei, keine Datei außerhalb von R4s W3-Besitz außer den bekannten
  (B9), statische Modelle nachts unverändert, trockene Fahrbahn rechnerisch unverändert, Tagesbilder bit-gleich
  (Modern-Änderungsmelder 6/6).

## 11. Vertragsfragen

1. `assets/shaders/modern/flare.gdshader` hat in §5 (A-8) keinen W3-Besitzer; R4 und FIX-R4 haben ihn geändert. Vorschlag
   (wie FIX-R4): der Besitzer von `layers/flares.gd` besitzt seinen Shader.
2. `tests/golden/modern_slice.{md5,env}` (W3 „–“): FIX-R4 hat den Hash `modern_s1_nacht` ersetzt – nachvollziehbar
   (modern-check 6/6). RINT-M2 erzeugt die Liste nach dem Zusammenführen mit `golden.sh modern-make` neu.
3. §6 R4 kennt die nasse Nacht nicht als Abnahme; `check_night_nass.gd` (Kegel 0,7–1,15 × Arcade, Randlinie ≥ 0,8 ×,
   keine Spiegelung über dem Dach) sollte dort stehen.

## 12. Für die nächsten Pakete

1. **FIX-M2 B-06 / R7 (Lack)**: B3 – GT nachts im Regen Sättigung 0,77 × (`check_night`) bzw. 0,70 × (Ausschnitt), Helligkeit
   gleich; danach `CAR_SAT_MIN` auf 0,85. Schnell: `check_night -- --only=spielerauto --fall=Turismo`.
2. **RINT-M2**: Konflikte erwartet nur in `tests/golden/modern_slice.*` und `docs/renderer-modern.md`; nach dem
   Zusammenführen `golden.sh modern-make` und die Nachtbilder ansehen (Limousine: FIX-M2 Tag-Entsättigung + `sheen_wash`).
3. **PERF / QA-M2-BILD**: N1 (Laternen-Profile in der Stadt bei Nacht und Regen messen; ggf. zwischenspeichern).
4. **R4-Nachfolger / QA**: N2 (Laternenfall in „spiegelung“); B8 und B6 (langsame Ausfahrt) sind weiter nur aus dem Code
   bzw. Einheitstest belegt.
5. **Look**: Limousine unter Laternen im Regen 1,21 × Sättigung (Grenze 1,25 ×) – knapp; die vielen orangen
   Laternenstreifen in Frankfurt sind kräftig, aber stimmig.
