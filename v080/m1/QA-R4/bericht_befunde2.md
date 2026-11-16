### B3 – mittel – Silberner Gran Turismo nachts im Regen hellgrau statt dunkel-marineblau (offen, schon in der Basis)
- **Wo**: Lack-Look `ModernMaterials.VEHICLE_LOOK` / `vpbr.gdshader` (Klarlack spiegelt den grauen Regen-Nachthimmel,
  `env_night` 0,35; Füll-Schimmer `fill_sheen_tint`).
- **Was** (gemessen, Heck x 520–800 / y 520–720, N2N 22 Uhr): 75. Perzentil der Leuchtdichte Arcade 36,9 / Kopf 40,5
  (+10 %), Median-Sättigung 0,47–0,50 / 0,38 (0,78×); `check_night` „spielerauto“ misst 0,93× / 0,73× (Schranke 0,7×,
  knapp). Bild `bilder/11_N2N_GT_arcade_kopf.png`. In der Basis ebenso grau (`10_N2N_basis_kopf.jpg`) – R4 hat es nicht
  verschlechtert, aber nicht gelöst; R4 meldet es selbst als offen.
- **Nachstellen**: `sh/ab.sh head N2N_high N2N high --shot-times=2`.
- **Behebung**: bei FIX-M2 B-06 / R7: Klarlack-Spiegelung nachts bei Regen auf die Himmelsfarbe des Sprites (blaue
  Nachttönung) statt Grau, oder `env_night` für helle Metallic-Lacke senken; Schranke der Sättigung in `check_night`
  von 0,7× auf 0,85× anheben, wenn es gelöst ist.

### B4 – mittel – Die neuen Prüfungen bewachen die beiden sichtbarsten Fehler nicht
- **Wo**: `tests/race3d/render/check_weather.gd` „nass“ (nur Spiegelung unter dem eigenen Auto auf ebener Strecke und
  Helligkeitsverhältnis fern/nah bei Tag), `check_weather_tabelle*.gd` (Mittel über den ganzen Boden),
  `check_night` „fahrbahn“ (nur N1 Schnee, trocken), `check_weather` „schneewall“ (prüft die Funktion
  `bank_height()`, nicht das gebaute Netz), `test_environment_rig` `test_exit_ramp`.
- **Was**: B1 und B2 gehen durch alle Prüfungen (R4: 23/23 grün). Mutationen (gemessen): U5 (Nachglühen springt bei 60 m
  von 0,39 auf 0) unerkannt; R3 (Profil-Scheitel ×2,6 → 0,78 m hoher Wall im Netz) @@R3@@.
- **Behebung**: `check_night` um „nass_kegel“ (B2) und eine Steigungs-Stelle für Spiegelungen (B1) erweitern;
  „schneewall“ die Höhe aus dem Netz messen (größtes y der Wall-Ecken über dem Boden-Ring, das liefert
  `TerrainBuilder.debug()` schon fast); `test_exit_ramp` zusätzlich Stetigkeit prüfen (`exit_after(EXIT_AFTER_M − 0,5) < 0,02`).

### B5 – niedrig – Wetter-Ebene folgt dem Wächter nicht (`quality_lowered` fehlt)
- **Wo**: `scripts/race3d/layers/weather.gd` hat `apply_quality()`, aber kein `quality_lowered(levels)`;
  `ModernRenderer` ruft beim Herabstufen im Countdown nur Hooks mit dieser Methode (`modern_renderer.gd` Z. ~599).
- **Was** (aus dem Code, abgeleitet): senkt der Langsamkeits-Wächter die Voreinstellung (z. B. „Hoch“ → „Mittel“),
  behält der Niederschlag 4.000 Teilchen im großen Kasten und die volle Gischt – gerade das, was auf llvmpipe die
  Bildzeit „Stadt bei Nacht im Regen“ um 29 % erhöht hat (R4, gemessen 552 → 710 ms).
- **Nachstellen**: `--gfx-preset=high` auf einer langsamen Maschine mit Wächter (ohne `--gfx-sync`), Schnappschuss
  `weather.particles` nach dem Herabstufen.
- **Behebung**: `func quality_lowered(levels): apply_quality(levels); _box = box_for(kind, _level);`
  `_particles.multimesh.instance_count`/`visible_instance_count` auf `_count` setzen und `box_lo/box_hi` neu setzen.

### B6 – niedrig – Nachglühen nach der Tunnelausfahrt hängt am Ort, nicht an der Zeit
- **Wo**: `environment_rig.gd` `exit_after(exit_behind(...))` – Stärke als Funktion der Kamerastrecke hinter dem Portal
  (60 m), keine Uhr.
- **Was** (aus dem Code, abgeleitet): steht das Auto innerhalb von 60 m hinter einer Ausfahrt (Stau, Unfall, Polizei),
  bleibt das ganze Bild dauerhaft überbelichtet (bei 10 m: Stärke 0,37 → × 1,43 + 0,15); bei 140 km/h dauert es wie
  gewollt ~1,5 s, bei 30 km/h 7 s. Am Portal (TEXIT 3,8 s) ist der Himmel fast weiß und das Gras blass, während Arcade
  sein normales Draußen zeigt (Bild `06_TEXIT_arcade_basis_kopf.jpg`, dritte Zeile) – Arcade kennt kein Nachglühen.
- **Behebung**: Stärke = Ortsgesetz × Abklingen über `view.time` seit dem Verlassen (z. B. 1,2 s), beides mit
  `--gfx-sync` bestimmt; oder das Nachglühen weglassen und nur das Viereck im Portal behalten (das ist Arcades Gesetz).

### B7 – niedrig – Limousine nachts satter als ihr Sprite (Königsblau statt Marine)
- **Wo**: Nacht-Füll-Licht `fill_sheen_tint` 0,8 (`ModernMaterials.VEHICLE_LOOK`, `vpbr.gdshader`).
- **Was** (gemessen, DEV 21 Uhr, Auto-Ausschnitt): Leuchtdichte 32,9 gegen 30,3 (1,09×, in Ordnung), Median-Sättigung
  0,87 gegen 0,63 (**1,38×**); Kofferraumdeckel 0,87 gegen 0,68. Bild `12_DEV_limousine_arcade_kopf.png`. Die Basis war
  dort fast schwarz (0,49×) – insgesamt ein Fortschritt, aber `check_night` hat nur eine Untergrenze der Sättigung.
- **Behebung**: Obergrenze (≤ 1,25×) in `check_night` „spielerauto“ und die DEV-Stelle als vierten Fall; den Tint des
  Schimmers nach der Sättigung des Lacks begrenzen.

### B8 – niedrig – Blendviereck der Ausfahrt kann durchsichtige Dinge dahinter überschreiben (abgeleitet)
- **Wo**: `environment_rig.gd` `GLARE_SHADER` (`ALPHA = 1.0`, liest `hint_screen_texture`) – die Kopie des Bildes enthält
  nur das Undurchsichtige; was im durchsichtigen Durchgang **vor** dem Viereck gezeichnet wurde (Lichtpunkte, Regen,
  Glas jenseits des Portals) wird überschrieben. Die Reihenfolge ergibt sich aus der Tiefe der AABB-Mitte; die
  Lichtpunkt-Ebenen haben eine riesige AABB um den Weltursprung (bis 2.000 m hinter der Kamera nach einem
  Ursprungsversatz).
- **Was**: nur bei Tag an Tunnelausfahrten; ein Bremslicht oder Blinker eines Autos direkt hinter dem Ausgang könnte
  verschwinden, solange die Kamera in der Röhre ist (F6). Nicht beobachtet in den Bildern, aus dem Code abgeleitet.
- **Behebung**: dem Blend-Material `render_priority = -128` geben (wird vor allen anderen durchsichtigen Dingen
  gezeichnet) oder die Lichtpunkt-Materialien höher priorisieren; Probe: TEXIT mit bremsendem Auto 20 m hinter dem
  Ausgang.

### B9 – niedrig – Dateibesitz und Zusammenführung
- `flare.gdshader` ohne W3-Besitzer geändert (R4 hat es gemeldet); `tests/golden/modern_slice.{md5,env}` ohne
  W3-Besitzer neu erzeugt (Konflikt mit FIX-M2, R5, R6; `docs/renderer-modern.md` mit R5). Behebung: RINT-M2 löst die
  Hash-Dateien nicht von Hand, sondern erzeugt sie nach dem Zusammenführen mit `golden.sh modern-make` neu (nach
  Ansicht der Bilder); den Abschnitt in `renderer-modern.md` beider Pakete hintereinanderstellen.
