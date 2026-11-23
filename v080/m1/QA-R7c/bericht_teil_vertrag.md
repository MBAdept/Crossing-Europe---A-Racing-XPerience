## 8. Abweichungen des Pakets und Vertragsfragen (Urteil der Prüfung)

| Abweichung (laut R7c) | nachgeprüft | Urteil |
|---|---|---|
| lod0-Entfernungen in `graphics.modern.props.lod0_m` statt `max_dist_m` in `model.json` (A-22) | ja: Mechanik liest `max_dist_m` (alle 60), Ersatz greift je Modell/Tag | vertretbar (model.json gehört den Asset-Paketen); **aber der Tag-Ersatz `tag:city` geht über den Leitentscheid hinaus** (QR7c-01) |
| Stufe nach geradem Abstand je Instanz statt Wegabstand je Stück | ja (Shader und `_span()` gleich) | richtig und besser; Folge: im Mittel weniger lod0 als vorher (weniger Primitive, aber QR7c-01) |
| Band über den Weg (±12 %, 4–25 m) statt Zeitblende 0,3–0,5 s (A-16) | ja | Vertragsfrage: im Stand bleibt das Raster stehen (QR7c-06) – Leitung entscheidet |
| `vpbr_static` per Texteinschub (`STATIC_INJECT`) | ja, Test bewacht die Marker | Notlösung; zerbricht still, falls jemand `vec3 lc = LIGHT_COLOR * ATTENUATION * k;` umformuliert – der Test fängt das (Marker fehlen) |
| `environment_rig.gd` nicht benutzt; Fernlicht nur auf Modellen von `props.gd` | ja | in Ordnung (Ausnahme war freiwillig); Tankstelle/Grenze/Brücke ohne Fernlicht – notiert |
| Modern-Goldens vom Paket erneuert (Brief gegen A-18) | ja, `modern_slice.*` geändert | Brief hat Vorrang; die Montage erneuert sie ohnehin |
| Flimmern ≤ 2× Sprite nicht überall (Fachwerk lod1 2,0–2,25×, Südhaus 3× bei 40 m) | nicht nachgemessen (Werkzeug `my_scene --mode=sparkcam` des Pakets) | offen wie gemeldet |
| Arcade-Goldens nur auf `965b8a9` | auf `bd1803b` neu: Abschnitt 3.5 | erledigt durch diese Prüfung |
| Paris-Clip vor der Korrektur des Schattendurchgangs | Clip-Bilder Kachel für Kachel ausgewertet (`sh/tilepeaks.py`): keine Stufen-Spitze, Spitzen am Bildrand = Laternen/Häuser in Bewegung; Spitzen-Verteilung wie Arcade (p99 60,6 / 57,8 %) | kein Stufensprung zu sehen; ein Clip auf dem Endstand fehlt weiter (QA-mid) |

Vertragsfragen (contract_issues):

1. **A-22 „max_dist_m in model.json“ gegen Besitz:** `model.json` gehört den Asset-Paketen, der Exporter schreibt überall 60.
   Vorschlag: der Vertrag nennt `graphics.modern.props.lod0_m` als gültigen Übergang **je Modell** (nicht je Tag), bis
   `cities3d.py` die Werte exportiert.
2. **A-16 „Zeitblende 0,3–0,5 s“ gegen Wegband:** eine Zeitblende braucht Zustand je Instanz (Instanz-Uniforms sind nach
   A-19 tabu). Die Leitung sollte das Wegband annehmen und festlegen, ob ein stehendes Raster (Start, Stau) hinnehmbar ist.
3. **Leitentscheid 1 „etwa 35 m für Fachwerk“ gegen Leitentscheid 3 „≤ 2× Sprite“:** R7c hat 3 über 1 gestellt und alle
   Stadthäuser gekürzt; das kostet bei „Mittel/Deck“ sichtbare Details (QR7c-01). Die Leitung sollte festlegen, welches
   Ziel bei Stadthäusern ohne Balkenflimmern gilt.
4. **A-18 Modern-Goldens:** Brief und Vertrag widersprechen sich (Paket erneuert / nur die Montage) – einheitlich regeln.
