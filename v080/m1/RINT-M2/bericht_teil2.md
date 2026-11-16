
## 3. Leitungsnotizen

### Notiz 3 – Abblendlicht behält seinen Glanz, Fahrzeuge dämpfen im Material (A-20): **erfüllt**

- `layers/lights.gd` `SPOT_SPECULAR` wieder 0,5. `vpbr`/`glass` nehmen die Glanzkeulen eines Lichts von neben dem Auge
  selbst heraus (`eye_lamp_spec` 0 im Renn-Look der Fahrzeuge, 1 im Studio; `eye_lamp_cos` 0,85 … 0,95).
- Lkw/Limousine gegen Arcade (Fahrzeugsonde, 22 Uhr, mittlere Leuchtdichte des Fußabdrucks, Arcade / neu): roter Lkw
  60 m 44,1 / 44,1 (Anteil > 200: 0,66 / 0,44 %), 20 m 57,0 / 63,0 (+10,5 %); Limousine silber 60 m 48,1 / 46,6.
  Mutation `eye_lamp_spec` 1: Lkw 60 m 171,5 (48 % weiß) – die Dämpfung wirkt.
- `check_vehicle_lights` „abblendlicht“ OK (20 m 0,5 % weiß, Mittel 0,24; 60 m 0,0 %, 0,17), `check_night_nass` grün
  (Render-Prüfungen, §4).
- Nasse Fahrbahn N2 22 Uhr Regen: mit `SPOT_SPECULAR` 0 und 0,5 **pixelgleich** (0 Pixel Unterschied) – die Fahrbahn
  liegt auf Ebene 2 und nahm den Spot nie; ihr Glanz kommt aus `inc/headlight.gdshaderinc`/`road.gdshader`. Die
  Annahme von NACH-M2 N-03 (der Spot-Glanz fehle der nassen Fahrbahn) stimmt nicht (Vertragsfrage, §6).
  Bild `n3_N2_22uhr_regen_nasse_fahrbahn.jpg`; N2/DEV auch in den A/B-Bögen.

### Notiz 4 – Brems- und Blaulichtzuschlag nach Tageslicht (A-20): **erfüllt (Bremse), Blaulicht bewusst nicht**

- `model_glow_gain(role, a, lights, dist_m)`: Bremszuschlag 2,2 bei Tag voll; nachts Anteil nach Abstand zur Kamera
  (0,6 bis 22 m, 0,15 ab 60 m, `smoothstep`). Ein Anteil für alle Abstände reichte nicht (gemessen: 0,35 → Sportwagen
  60 m +22 %, Limousine 20 m −32 %; 0,15 → −1 % / −46 %).
- Sonde 22 Uhr, rote Pixel Arcade / neu: **Sportwagen 60 m 95 / 94** (−1 %), **Limousine 20 m 539 / 476** (−12 %),
  Sportwagen 20 m 567 / 454 – alle innerhalb „Arcade + 10 %“ (obere Grenze). Polizei 60 m: Blau nachts 97 gegen
  Arcade 184 – der Blaulicht-Zuschlag bleibt darum nachts (ohne ihn wäre es noch weniger; die Notiz verlangt nur die
  obere Grenze; „blaulicht“ fällt mit Verstärkung 1,0 durch, gemessen in FIX-M2 und hier erneut).
- Prüfung „bremsschein“ (aufsummiertes Rot, das die Bremse hinzufügt): Tag ≥ 29 (Kopf 33,1; **Verstärkung 1,0: 25,0 →
  FEHLER**), Nacht Sportwagen 60 m ≤ 57 (Kopf 28,3; voller Tageszuschlag nachts 68,9 → FEHLER), Limousine 20 m ≤ 500
  (Kopf 436,1; voller Zuschlag 602,8 → FEHLER). Unit-Tests nah/fern/Tag/stetig.

### Notiz 5 – Tönung der Modelle über Instanzdaten (A-19): **erfüllt, nach einem eigenen Fehlschlag**

- `b04d28a` legte die Tönung als MultiMesh-Custom-Daten an Modelle. Die Bilder danach (Kiel km 0,6 und Hamburg-Rand
  km 81,2) zeigten **leuchtend grüne** Fensterrahmen, Garagentore, Giebelkanten, Kronen, Stämme und Windräder.
- Eingegrenzt mit Sonden (`probe/mm_custom*.gd`, `probe/mm_models.gd`): Godot 4.7.2 Compatibility liest
  `INSTANCE_CUSTOM` falsch (a) bei Farbe ohne Custom-Daten: (0, 1, 0, 1); (b) bei Custom-Daten ohne Farbe, über
  `MultiMesh.buffer` gesetzt, auf den echten Modellnetzen (über `set_instance_custom_data()` richtig – je Instanz zu
  teuer). Mit Farbe **und** Custom-Daten stimmt es: grüne Pixel der Modellreihe 0,292 % → 0,002 % (ohne Instanzdaten
  0,006 %). Ohne beides liest es 0, ein `MeshInstance3D` ebenso – die Shader lassen dort die Albedo.
- `a3120e4`: jede Instanz der Requisiten 20 Werte (Transformation, Farbe, Custom); Modell: Farbe weiß, Custom =
  Tönung; Vertretung: Farbe = Tönung, Custom leer. Unit-Test `test_model_instances_carry_the_placement_tint`
  (Pufferlayout, Knoten mit Farbe und Custom-Daten, Shadercode), Doku `docs/modelle.md` „Tönung“, §17.3.
- A/B: `n5_toenung_hamburg_rand.jpg` (Arcade rosa Einfamilienhaus `#e8b8a4` / vorher weiß / jetzt rosa wie Arcade),
  `n5_gruenstich_vorher_nachher.jpg`, `n5_gruenstich_kiel.jpg`, Sonde `n5_sonde_instanzdaten.jpg`.

### Notiz 6 – Instanzbudget ≤ 230 bei „Hoch“, Waldprüfung unter Last (A-19): **erfüllt**

| Prüfung (Hoch) | Verkehr | ganze Szene (≤ 230) | Fahrzeug-Ebene | Ablehnungen |
|---|---|---|---|---|
| `instanzen` Kiel – Hamburg km 2, 100 s | eigener | 141 | 128 (Budget 128) | 0 |
| `instanzen_wald` Dortmund – Frankfurt ab km 40 (Wald km 40–60) | 48 eingespeist | **216** | 208 | 0 |
| `instanzen_stadt` Würzburg – Nürnberg ab km 106 (Ziel in der Stadt) | 48 eingespeist | 171 | 176 | 0 |
| `instanzen_wald` **ohne `VPBR_STATIC`** (Mutation) | 48 eingespeist | 306 | 208 | **144 → FEHLER** |

- Eigene Kopfzeile `## render-check-timeout: 2400`; Belastung verlangt (Fahrzeug-Ebene ≥ 90 % ihres Budgets, sonst
  „nicht belastet“). Mit 48 gezeigten Autos geht die Fahrzeug-Ebene über ihr Budget (sie gibt nur Pool-Autos und
  verborgene Stufen frei) – dort binden die Szenengrenze und die Ablehnung; gezählt wird dann alle 10 Bilder.
- Die Szene im Wald liegt mit 48 gleichzeitig gezeigten Autos 14 Instanzen unter der Grenze (§6).
