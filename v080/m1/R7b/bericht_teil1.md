# R7b – Wahrzeichen, Skyline und Hintergrund (Welle 5, Schub M2)

Zweig `wip/v080-r7b` (Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2`,
lokaler Zweig `worktree-wf_ba4424b4-294-2`), Basis `9b02f05` (RINT-M2). Endstand: siehe §10.
„gemessen“ = auf dieser VM (llvmpipe unter Xvfb, vier geteilte Kerne, Last 12–14); „gefolgert“ = nicht messbar hier.

## 1. Kurz

- Neuer Builder `scripts/race3d/builders/landmarks.gd` und Shader `assets/shaders/modern/landmark.gdshader`: jedes
  Wahrzeichen, das Arcade zeigt, steht an Arcades Stelle auf dem Pfad, sobald es in Arcades Wahrzeichenreichweite
  kommt (bis `render.landmark_far_m` = 1.900 m; nachts bis dahin mit seiner Beleuchtung), mit Arcades Dunst- und
  Ausblendgesetz (`RoadRenderer.landmark_fade`) – **weich** ausgeblendet: ab 0,70 L zeichnet die durchscheinende
  Variante statt des geordneten Rasters (B-09).
- Darstellung (Entscheidung 3, Schnittstelle für AS6): Modell aus dem Manifest → sonst Arcades Bild → sonst Arcades
  prozedurale Art **als 3D-Form** (Kuppelkirche, Fernsehturm, Leuchtturm mit Strahlen, Hochhausgruppe; N2) → sonst
  Ersatz-Set. Nachts: Anstrahlung, warme Fenster, rote Flugwarnlichter, Leuchtfeuer.
- Hintergrund `layers/backdrop.gd`: Skyline der Zielstadt wie Arcade (Sprite-Silhouetten und Arcades prozedurale
  2D-Zeichnungen über eine nie eingehängte `RoadRenderer`-Instanz), ausgeblendet, solange das 3D-Wahrzeichen in
  Reichweite ist.
- `builders/props.gd` blieb unverändert: die Ente-Typ-Weiche `_skip_landmarks` stand schon im Code (Zeilen 88, 122,
  329, 539, 741).
