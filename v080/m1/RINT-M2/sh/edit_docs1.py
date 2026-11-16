W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


TB = "docs/renderer-modern-tunnel-bruecken.md"
# NACH-R5 N-02: the paragraph sits inside the table – move it below the table
para = """Jede dieser Regeln ist gegen einen eingebauten Fehler geprüft (FIX-R5: die Mutationen der unabhängigen Prüfung –
`night_albedo` nicht gesetzt, 5 statt 7 Seile, keine Brückenlampen, `set_zone` ohne `has_method`, Portal auf Layer 1 –
fängt je ein benannter Test).
"""
sub(TB, "\n" + para + "| `tests/race3d/render/check_tunnel_bridge.gd` | siehe Abschnitt 7 |\n"
    "| `tests/race3d/check_minimal_structures.gd` | `tunnel`, `bruecke` (seit FIX1) |\n"
    "| `tests/unit/race3d/test_far_ground_water.gd`, Render-Prüfung `terrain_cover` K1 | ZS1-Regel der Scheibe |\n",
    "\n| `tests/race3d/render/check_tunnel_bridge.gd` | siehe Abschnitt 7 |\n"
    "| `tests/race3d/check_minimal_structures.gd` | `tunnel`, `bruecke` (seit FIX1) |\n"
    "| `tests/unit/race3d/test_far_ground_water.gd`, Render-Prüfung `terrain_cover` K1 | ZS1-Regel der Scheibe |\n\n" + para)
sub(TB, "`tunnel.gd` rechnet jedes Bild `tunnel_state` = {`amount`, `inside`, `exit_m`, `portal_m`, `exit_in_sight`, `light`}",
    "`tunnel.gd` rechnet jedes Bild `tunnel_state` = {`amount`, `inside`, `exit_m`, `exit_z`, `portal_m`, `exit_in_sight`, `light`}")

RM = "docs/renderer-modern.md"
# pointer for R6's own document (FIX-R6 note 4, lead note 1)
sub(RM, """der Insel. Bild S2: gleichwertig zu Arcade.

### 14.5 Start- und Zieltor (`builders/gantry.gd`)""", """der Insel. Bild S2: gleichwertig zu Arcade.

Seit R6 (Welle 3) sind Tankstelle, Grenze, Stadtmobiliar, Start-/Zieltor und Blitzer ausgebaut – Einzelheiten,
Sichtlinien-Entscheid der Stützen, abgespannte Dächer und Prüfungen in
[renderer-modern-bauten.md](renderer-modern-bauten.md); die Montage RINT-M2 (§17) hängt Dächer ohne Stütze an einen Mast.

### 14.5 Start- und Zieltor (`builders/gantry.gd`)""")
sub(RM, """Sekunde, alle grün beim Start; Schein über die Ebene `flares`, Farbe und Stärke je Bild aus `view.countdown`).
""", """Sekunde, alle grün beim Start; Schein über die Ebene `flares`, Farbe und Stärke je Bild aus `view.countdown`).
Ausbau mit Fachwerkträger und Flutlichtern (R6/FIX-R6): [renderer-modern-bauten.md](renderer-modern-bauten.md).
""")
# NACH-M2 N-04: four test sets
sub(RM, """`check_vehicle_standin` lädt ein Test-Manifest ohne Modell für `player/kombi`, `traffic/van_white` und
  `traffic/bus_blue` – ein Fall ohne Vergleich ist ein FEHLER (M2S-02)""", """`check_vehicle_standin` lädt ein Test-Manifest ohne Modell für `player/kombi`, `traffic/sports_red`,
  `traffic/van_white` und `traffic/bus_blue` (vier Sätze, `TEST_SETS`) – ein Fall ohne Vergleich ist ein FEHLER (M2S-02)""")
sub(RM, """- **Abblendlicht ohne Glanz** (B-05): die zwei Spots des Abblendlichts (`layers/lights.gd`, `SPOT_SPECULAR` 0) geben
  keinen Glanzanteil mehr.""", """- **Abblendlicht ohne Glanz** (B-05; seit RINT-M2 im Material statt am Licht, §17.1): die zwei Spots des Abblendlichts
  (`layers/lights.gd`, `SPOT_SPECULAR` 0) gaben keinen Glanzanteil mehr.""")
sub(RM, """- **Waldprüfung** (M2S-01): `check_instance_budget_wald.gd` fährt 20 s statt 100 s (der Wald steht ab dem ersten
  Bild; die Fahrzeuge allein prüft `check_instance_budget.gd` über 100 s), meldet Laden und Fahrt getrennt und darf
  1 800 s laufen (Kopfzeile `## render-check-timeout:`);""", """- **Waldprüfung** (M2S-01): `check_instance_budget_wald.gd` fährt 20 s statt 100 s (der Wald steht ab dem ersten
  Bild; die Fahrzeuge allein prüft `check_instance_budget.gd` über 100 s), meldet Laden und Fahrt getrennt und darf
  1 800 s laufen (Kopfzeile `## render-check-timeout:`; seit RINT-M2 mit eingespeistem Verkehr unter Last, §17.4);""")
# 14.11: known gaps of the first test build – now history; the current list stands in §17.9
sub(RM, """### 14.11 Bekannte Lücken im Testbuild (für die Testhinweise)

- **Kein Wetter in der Luft** (R4, M2): kein Regen, kein Schneefall, keine Gischt; nasse Fahrbahn und Schneeränder gibt es.
- Tunnel und Brücken nur als Mindestbauten (14.3, 14.7); keine Grenzstationen (Dach, Kabinen) – Arcade zeigt sie.
- Keine Sonnenscheibe am Tag; kein überstrahltes Draußen an der Tunnelausfahrt.""", """### 14.11 Bekannte Lücken im ersten Testbuild (Stand ZS1; die heutige Liste steht in §17.9)

- **Kein Wetter in der Luft** (R4, M2): kein Regen, kein Schneefall, keine Gischt; nasse Fahrbahn und Schneeränder gibt es.
  *Seit R4 behoben (§15).*
- Tunnel und Brücken nur als Mindestbauten (14.3, 14.7); keine Grenzstationen (Dach, Kabinen) – Arcade zeigt sie.
  *Seit R5 und R6 behoben (§16, renderer-modern-bauten.md).*
- Keine Sonnenscheibe am Tag; kein überstrahltes Draußen an der Tunnelausfahrt. *Seit R4 behoben (§15.6, §15.8).*""")
# NACH-R5 N-02: the portal paragraph under "Wasser im Licht"
sub(RM, """### 16.2 Wasser im Licht

Auch das **Tunnelportal**""", """### 16.2 Portal im Licht

Auch das **Tunnelportal**""")
sub(RM, """Es
bleibt im Licht von Sonne, Mond und Umgebung und wirft seinen Schatten.

Das Wasser ist Boden""", """Es
bleibt im Licht von Sonne, Mond und Umgebung und wirft seinen Schatten.

### 16.3 Wasser im Licht

Das Wasser ist Boden""")
print("ok")
