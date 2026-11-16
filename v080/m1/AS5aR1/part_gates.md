Endstand `7153381` auf `origin/wip/v080-as5ar1`. Alle Läufe mit `nice -n 19`, ein schwerer Lauf zur Zeit, absolutes
`XDG_DATA_HOME` im Arbeitsordner.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` – Netze 18,86 von 40 MB, Texturen 57,53 von 240 MB im Grafikspeicher, Quellen 30,41 von 60 MB. Zwischendurch einmal rot (17 verkehrt gewickelte Dreiecke in der Gartenstufe des Hauses bei Dezimierung 0,15) – behoben, siehe Runde 3 |
| Sprite-Geometrie | `check_sprite_geometry.py --only props --jobs 1` (nach der letzten Änderung von `props_cities.py`) | `86 Sprite-Sets gebaut in 286 s: 86 identisch … 0 verändert, 0 fehlen` – `CHECK sprite_geometry OK` (der Hash umfasst auch die Materialien) |
| Schlüssel | `export_models.py --check-keys` | `CHECK cache_keys OK 98 Modelle` |
| Determinismus | Büroturm und Kran nach dem echten Export ein zweites Mal erzwungen exportiert und gebacken (`--force`, CE_THREADS=3) | beide **byte-gleich** (Hash der GLB und des Modellordners vorher = nachher) |
| AS4-Modelle | `git diff 63544b6 -- assets/models` | außerhalb `props/city_*` nur `manifest.json`; `buildings3d.py` unverändert. Die Modelle mit `props_cities.py` im Schlüssel (`bridge_pylon`, `bridge_pylon_bare`, `bridge_truss_arch`, `bridge_lamp`, `houseboat`) neu exportiert: byte-gleich |
| Rennen in Modern | `tools/ab_shot.sh`, 10 Läufe an vier Stadteinfahrten (siehe unten) | alle Bilder da, Exit 0, **0 Skriptfehler** in 20 Protokollen |
| Tests | `tools/run_tests.sh` (einmal, vollständig, 957 s für die Einheitstests) | alle Schritte grün bis auf einen Zeit-Test des Klangs: `test_engine3_checks :: test_engine_thread_in_a_running_game` (69 Aussetzer des Generators unter Last, 6 Hänger à 400 ms). Gefiltert wiederholt (`tools/run_tests.sh engine3_checks`): **2 Tests, 0 fehlgeschlagen** (0 Aussetzer). Derselbe Lastausreißer wie bei AS5a1; berührt keine Datei dieses Pakets. `test_music_checks` war diesmal grün |
| Arcade | `tools/golden.sh check` (einmal) | `GOLDEN arcade: 20 von 20 identisch`, `GOLDEN arcade-ui: 17 von 17 identisch` |
| Modern | `KEEP=… tools/golden.sh modern-check` | `GOLDEN modern: 4 von 6 identisch`; anders `modern_s4_mittel` (km 80,6) und `modern_s5_niedrig` (Ziel Hamburg) – dort stehen die neu exportierten Stadthäuser (Fensterflanke der Giebelzeile, Rahmenring); beide Bilder angesehen, gewollt; `modern-gles` OK (max. 2/255, PSNR 73,2 dB). Liste aus den behaltenen Bildern geschrieben (dieselbe Renderfunktion wie `modern-make`), Commit `7153381` |
| Archiv | `share.py` (deflate -9 je Datei der `.res`, `model.json` und importierten `.ctex`, wie `tools/pck_report.py`) | Netze **0,82 MB**, Texturen **5,36 MB** im Archiv (Anteil der Charge ≤ 3 / ≤ 7 MB; vorher 0,79 / 5,25 MB). Kein eigener Linux-Build (Abweichung) |
