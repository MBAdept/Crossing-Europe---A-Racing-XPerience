### 13.8 Instanzbudget: Godots globaler Shader-Puffer

Der Compatibility-Renderer legt die Instanz-Uniforms (`instance uniform` in `vpbr`, `glass`, `vehicle_sprite`) im
globalen Shader-Puffer ab, **16 Plätze je Instanz**, ob sie sichtbar ist oder nicht. Der Puffer ist so groß wie der
Uniform-Block der GPU: 64 KB = 4096 Plätze mit llvmpipe und den meisten Desktop-Treibern (die Projekteinstellung
`rendering/limits/global_shader_variables/buffer_size` kann ihn nicht darüber heben) – nach den globalen Uniforms etwa
**250 Instanzen in der ganzen Szene**. Darüber lehnt Godot ab („Too many instances using shader instance variables“)
und zeichnet die Instanz mit den Werten einer anderen (Lack, Lampen, Ausblendung).

Die Pools der Fahrzeug-Ebene (6 freie Autos je Set) behielten ihre gebauten Stufen – lod0 allein sind 6 Instanzen
(Karosserie, vier Räder, Schattenhülle). Gemessen (Kiel–Hamburg km 2, Spieler steht, Verkehr zieht vorbei): die
Instanzen der gebauten Stufen wuchsen ohne Ende (30 → 159 in 720 Bildern bei doppelter Zeit, ganze Szene 227); in
900 Bildern ohne Budget 15 bzw. 17 Ablehnungen (Stand b473e90 bzw. vor der Abhilfe). Der Rest der Szene (Requisiten in
`vpbr`, Bögen der Ersatzbilder) belegte dabei 34–72 Instanzen, das Aufwärmen hinter dem Ladebild bis 135.

Abhilfe in `layers/vehicles.gd`: **`INSTANCE_BUDGET` = 128** für die Instanzen aller gebauten Stufen (aktive und
gepoolte Autos, `perf()`: `vehicle_instances`, `vehicle_instances_peak`, `vehicle_trims`). Darüber gibt die Ebene am
Ende von `update()` zuerst gepoolte Autos frei (aus dem vollsten Pool), dann Stufen aktiver Autos, die weder gezeigt
werden noch ausblenden; eine freigegebene Stufe wird beim nächsten Bedarf neu gebaut. Gemessen mit Budget: ganze
Szene höchstens 196–229 Instanzen, keine Ablehnung.
Prüfungen: `check_vehicles` → `instanzen` (headless, 180 s Verkehr bei vierfacher Zeit: höchstens 128, Zähler =
Knoten, das Budget gibt frei), Render-Prüfung `check_instance_budget.gd` (100 s Verkehr bei sechsfacher Zeit, ein
`Logger` fängt jede Ablehnung der Engine; ganze Szene unter 230), und `tools/run_render_checks.sh` lässt jede
Render-Prüfung scheitern, deren Ausgabe eine Ablehnung enthält.
