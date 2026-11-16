# AS5a1 – Stadthäuser german, german_old und hanse als Echtzeit-Modelle (Bericht)

Paket **AS5a1** von v0.8.0 „Modern“ (Stadtgebäude Teil 1, Charge 1 von 2). Zweig `worktree-wf_db8ba6cd-508-1`,
gesichert als `origin/wip/v080-as5a1`; Basis `6e48405` (origin/wip/v080-m2int), Endstand `{{HEAD}}`. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1`. Das Paket lief über mehrere
Neustarts des Containers (drei Nachfolger); dieser Bericht beschreibt den Endstand.

Zahlen sind **(gemessen)** oder **(gefolgert / gerechnet)**; ohne Zusatz in Tabellen gilt „gemessen“. Gemessen heißt:
auf dieser VM (4 Kerne, mit anderen Aufträgen geteilt, Last 17–26), Software-OpenGL (llvmpipe) unter Xvfb, Renn-Look
der Prüfszene (`prop_scene --look=race`) bzw. `tools/ab_shot.sh`. Alles über echte Grafikkarten, das Steam Deck oder
die Wirkung auf einen Menschen ist gefolgert.

## Kurzfassung

Die elf Stadthaus-Sets der Stilfamilien `hanse`, `german` und `german_old` – die Städte des Rennens Kiel – Nürnberg
(Kiel, Hamburg, Bremen, Rostock; Hannover, Kassel, Dortmund, Frankfurt; Würzburg, Nürnberg, Fulda, Erfurt und über
gemischte Stile Leipzig, Magdeburg, München, Passau, Regensburg, Bern) – sind keine Arcade-Bilder mehr, sondern echte
Modelle aus derselben Blender-Geometrie wie die Sprites, mit Tiefe an der Straße, gebackenem Atlas mit
Umgebungsverdeckung, Nachtlicht derselben Fenster wie in Arcade und geschlossenen Rückseiten. Reihenfolge nach
Häufigkeit auf Kiel – Nürnberg (gezählt): Einfamilienhaus 282, Fachwerkzeile 99, Turmhaus 95, Mietshaus 77,
Gründerzeithaus 72, Giebelzeile 54, Barock 32, Speicher 10, Büroturm 7, Kontor 4, Kran 3.

Neu ist der Bauer `city` (`tools/blender/ce3d/cities3d.py`) auf dem Gebäudebauer von AS4 (`buildings3d.py` unverändert –
die AS4-Modelle bleiben byte-gleich). Budget: 427–9 865 Dreiecke lod0, 2 Aufrufe je Stufe; Archivanteil der Charge
{{ARCHIV}}. Gates siehe unten; das Schwächste: Flimmern und Stufenwechsel der Fachwerkhäuser, Geländer ab 100 m.

## Ergebnis je Modell (Budget)

{{BUDGET}}

Spalten: Dreiecke je Stufe (`model.json`, nach dem Godot-Bake); Zeichenaufrufe = Oberflächenklassen je Stufe
(`baked`/`baked_cutout` + `vpbr`); Atlas = Albedo- und Lichtatlas; px/m Straße = Texeldichte der Straßenwände aus dem
Bake (Modellmaß; Minimum = Obergeschosse, Maximum = Erdgeschoss/erstes Obergeschoss bzw. Schaufenster); Rückseite =
abgewandte Wände, die die Texel der Straßenwand gespiegelt mitbenutzen („reused walls on the far side“), gegen Wände
mit eigenen Texeln; Bytes = Netze (`.res` + `model.json`) und importierte S3TC-Texturen im PCK, in Klammern deflate -9
wie im Archiv; Export s = Bauen + Backen in Blender (CE_THREADS=3, ein Worker, nice 19, unter Last 17–26).
