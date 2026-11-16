Alle Gates liefen auf dem Endstand `09f679b` (Modelle seit `8dd2fef` unverändert), eines nach dem anderen mit
`nice -n 19` und einer Arbeitsinstanz. Logs im Scratch unter `m1/AS4R/gates/`.

| Gate | Ergebnis (gemessen) |
|---|---|
| `validate_models.py --report` | **CHECK models OK** – 42 Modelle, 183 Sets (54 mit Modell); Netze 4,92 MB von 40 MB, Texturen 28,77 MB im Grafikspeicher von 240 MB, Quellen 14,75 MB von 60 MB |
| Budgettabelle | oben; alle 15 AS4R-Modelle unter Dreiecks- und Aufrufbudget |
| `check_sprite_geometry.py --only props --jobs 1` | **CHECK sprite_geometry OK** – 86 Sprite-Sets: 86 identisch, 0 verändert, 0 fehlen, kein „ANDERS“ (240 s) |
| `export_models.py --check-keys` | **CHECK cache_keys OK** (136 s) |
| zweiter, erzwungener Export aller 15 Modelle (`--force`, mit Bake, Import, Manifest) | Arbeitsbaum danach **unverändert** (`git status` leer) = byte-identisch (2 022 s) |
| `tools/ab_shot.sh` (Arcade gegen Modern) | sechs Läufe an fünf Stellen (Kiel–Hamburg km 77,4 und km 82,9 mit Deck, Paris–Tours km 129 mittags und nachts, Dortmund–Bremen km 1,9 nachts, Dresden–Leipzig km 111 nachmittags): **0 Skriptfehler** in jedem Modern-Protokoll |
| `tools/run_tests.sh` (einmal, `XDG_DATA_HOME` absolut im Scratch) | **Tests bestanden** – 692 Tests, 0 fehlgeschlagen; 156 CHECK-Zeilen OK, 0 FEHLER (833 s) |
| `tools/golden.sh check` (einmal, `TMPDIR` im Scratch) | **GOLDEN arcade: 20 von 20 identisch** (155 s) |

Die Prüfwerkzeuge der Kritik (`tools/kritik/`, unversioniert) wurden vor `run_tests.sh` gelöscht; sie liegen mit den
eigenen Werkzeugen im Scratch (`m1/AS4R/install_tools.sh`).
