## 4. Code-Durchsicht (gelesen; Belege mit Datei und Zeile des Stands `bd1803b`)

Geprüft und in Ordnung (gelesen, wo nötig nachgerechnet):

- `lod_bands()` (props.gd 226–253): Nachbarbänder schließen exakt aneinander (lod0 aus = lod1 ein, lod1 aus = Fernbild ein),
  eine Darstellung für mehrere Stufen bekommt die Vereinigung; `d1 = max(d1, d0 + w0 + w1 + 2)` verhindert Überlappung.
  Nachgerechnet für alle 77 Modelle × 3 Detailstufen (3.2).
- Raster (`inc/lod_band.gdshaderinc` `ce_lod_discard`): die beiden Stufen zeigen t ∈ [0, fout) bzw. [1 − fin, 1) mit
  fin = 1 − fout bei gleichem Band – komplementär, kein Pixel doppelt, keins fehlt. Instanzen außerhalb des Bandes fallen
  im Vertex-Shader auf einen Punkt.
- Schattendurchgang: genau eine Stufe wirft (die feinere bis `in1`/`out1`); Modelle mit eigenem Schattennetz
  (`caster`) werfen über einen Knoten ohne Band (`rep_materials()` lässt Schattenteile aus) – keine Lücke in den
  Schatten naher Häuser.
- Gemeinsame Materialien: die Materialien je Netz teilt `props.gd` nur mit Bausteinen, die dieselben Netze zeichnen –
  `city.gd` zeichnet die Straßenlaterne (einstufig → Band „immer“), `bridge.gd` zeichnet die Brücken-Sets, die
  `props.gd` dann auslässt (`item_set()` bei `skip_bridge`) – kein fremdes Band auf fremden Instanzen.
- Fernlicht: `shadow_far` = (0,85, 1) × Reichweite entspricht `directional_shadow_fade_start = 0.85` von
  `environment_rig.gd`; ohne werfende Klasse (Steam Deck: Schatten „Niedrig“, Gebäude werfen nicht) bleibt `far_sun` 1.
- Phase: Custom-a = 1 + Phase ≤ 1,999 (halbe Gleitkommazahl 1 + 1023/1024), nie 2,0; alle Shader lesen die Tönung
  weiter bei a > 0,5 (`test_model_instances_carry_the_placement_tint` grün).
- Fernbild-Relief: die kleinste Mip der Impostor-Bilder ist ihre Mittelfarbe – die transparenten Texel tragen die
  Mittelfarbe (alle 18 Baumbilder nachgemessen: Abweichung < 0,01), Mipmaps sind an.
- Anbauten: gehen durch `_place()` und damit durch `drop_reason()` (Band, Korridor, Dichte) – nur ohne Wache (3.3).
- `quality_lowered()` setzt Bänder auf Materialien und Knoten neu (Test grün); `apply_quality()` ruft die Sitzung nur
  einmal beim Start (race_session.gd 487) – kein Wechsel mitten im Rennen, der alte Bänder auf Knoten ließe.

Auffällig (Befunde in Abschnitt 6):

- **Verzögertes Einschalten der Stufenknoten** (props.gd 364–366, 1222–1225): `update()` schaut nur alle
  `LOD_STEP_M` = 2 m Fahrt auf die Stücke, und ein Knoten wird ohne Spielraum sichtbar, sobald `span.x <= band.w`.
  Bis zur nächsten Prüfung kann eine nähere Stufe schon im Band sein, ihr Knoten aber noch aus: das gröbere Raster
  blendet bereits aus, das feinere fehlt – bei einem Stadthaus bei „Mittel“ (Band 30,8–39,2 m) bis 2/8,4 = 24 % der
  Pixel als Löcher, für höchstens 2 m Fahrt (gefolgert, nicht im Bild gesehen; der Kasten der Instanz-Ursprünge
  liegt meist näher als das Haus selbst und fängt das bei seitlichem Abstand ab).
- **Anbauten jenseits des Stücks** (props.gd 905–915): der Anbau steht bei `z − off.z × sc`; liegt das hinter der
  letzten Reihe des Stücks, liest `ctx.ground()`/`drop_reason()` die Randreihe (Höhe am Hang falsch). Latent – kein
  Modell nutzt `attach`.
- **Raster bei stehendem Wagen**: das Band hängt am Weg, nicht an der Zeit (Abweichung von A-16). Steht der Wagen (Start,
  Stau, Polizeistopp) mit einem Haus im Band, bleibt das Haus im geordneten Raster zweier Stufen stehen (Abschnitt 5,
  Startbild).
