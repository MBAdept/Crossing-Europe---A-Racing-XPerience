# FLACKER-NACHSTELLEN: Ein weißer Pkw verliert kurz seine Lackierung (ZS1, Kassel–Erfurt)

Rolle: nachstellen und messen. Kein Commit, kein Push, kein eigener Branch. Gemessen wurde im Worktree
`wf_17007edf-ec9-1` auf dem Testbuild **ZS1 = 39849f0** und danach auf dem **M2-Kopf = 6e48405**.

Alle Bilder und Zahlen stammen von dieser VM: llvmpipe (Software-OpenGL) unter Xvfb, 4 Kerne, die sich bis zu acht
Agenten teilen. „Gemessen“ heißt: auf dieser VM gemessen. Was für die Grafikkarte des Nutzers unter Windows gilt, ist
**abgeleitet** und so markiert.

(Entwurf – Abschnitte werden mit den laufenden Messungen gefüllt.)

## 1. Ergebnis in Kürze

PLATZHALTER

## 2. Was der Nutzer gefahren ist

- Etappe `erfurt_kassel` (155 km, A4 · B7 · A44, ab km 20 Wald- und Hügelland `forest_hills`).
- Im Rennen kommt sie nur in **Dresden–Dortmund** vor, Richtung **Erfurt → Kassel** (FLACKER-ANALYSE, gemessen über
  `RoadNetwork.race_routes`). **Kassel → Erfurt** gibt es nur als „Einzelne Etappe“.
- Windows-PC mit eigener Grafikkarte: Stufe „ok“ → der erste Start wählt **Modern** und das Preset **Mittel**
  (`Gfx.recommended_preset("ok")`, abgeleitet). Mittel: Detailstufe lod0 → lod1 bei 38–42 m (Kamera → Wagenmitte,
  Wegstrecke), Schattenkaskaden-Grenze bei 36 m ohne Überblendung. Steam Deck: dieselbe Stufengrenze (38–42 m),
  Kaskadengrenze 24 m. Hoch: Stufengrenze 57–63 m, Kaskadengrenze 40 m mit Überblendung.
- Weiße Pkw in ZS1: `traffic/hatch_white` und `traffic/wagon_white` sind 3D-Modelle, `traffic/suv_white` und
  `traffic/van_white` fahren als Arcade-Bild (Ersatzbild).
