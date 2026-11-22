import sys
p = sys.argv[1] + "/bericht_gates.md"
t = open(p, encoding="utf-8").read()
rep = {
    "@@VAL@@": "`CHECK models OK`; `CHECK cache_keys OK` (98 Modelle); `CHECK sprite_geometry OK`; `audio_qc`: 98 Klänge, 0 mit Fehlern",
    "@@DET@@": "Kontor und Einfamilienhaus je zweimal: Cache und gebackene Modelle byte-gleich, `git status assets/models` 0 Dateien",
}
for k, v in rep.items():
    assert t.count(k) == 1, k
    t = t.replace(k, v)
t = t.replace("| Prüfer, Schlüssel, Sprites, Klang | `validate_models.py --report`, `export_models.py --check-keys`, `check_sprite_geometry.py`, `audio_qc.py` | @@VSTAND@@ |",
              "| Prüfer, Schlüssel, Sprites, Klang | `validate_models.py --report`, `export_models.py --check-keys`, `check_sprite_geometry.py`, `audio_qc.py` | `ae1fd76`/`dd7d984` (Modelle, Sprites, Klänge seit `cee4590` unverändert) |")
t = t.replace("| Export-Determinismus | zwei AS5a-Modelle zweimal `--force` exportiert und gebacken | @@VSTAND@@ |",
              "| Export-Determinismus | zwei AS5a-Modelle zweimal `--force` exportiert und gebacken | `dd7d984` |")
open(p, "w", encoding="utf-8").write(t)
print("ok")
