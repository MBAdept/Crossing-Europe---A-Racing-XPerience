S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080"
head = open(S + "/deliver/AU-R4/bericht.md", encoding="utf-8").read()
body = open(S + "/m1/AU-R4/bericht_body.md", encoding="utf-8").read()
gates = ("`tools/run_tests.sh` 662 Tests, 0 fehlgeschlagen, 92 CHECK OK, 0 FEHLER (623 s); `tools/golden.sh check` "
         "„20 von 20 identisch“; `check_arcade_lean` OK; eingefrorene Pfade gegen v0.7.0 unverändert.")
detail = """| Gate | Ergebnis (gemessen) |
|---|---|
| `tools/run_tests.sh` (einmal, Endstand `f253687`) | „662 Tests, 0 fehlgeschlagen“, 92 CHECK-Zeilen OK, 0 FEHLER, „Tests bestanden (623 s)“ – Protokoll `pruefung_run_tests.txt` |
| `tools/golden.sh check` (einmal) | „GOLDEN arcade: 20 von 20 identisch (186 s)“ – `pruefung_golden.txt` |
| `check_arcade_lean` (in `test_modern_checks.gd`) | OK: 0 von 35 Skripten des Modern-Klangs, -Renderers und der Modell-Datenbank geladen |
| `test_arcade_identity.gd` | 6 von 6 grün (Motor-Mischer, SfxSynth, Verkehr/Raum, eingefrorene Klänge) |
| Regel 1: eingefrorene Pfade `v0.7.0..HEAD` | 0 Dateien geändert |
| geänderte Dateien `b6339ad..HEAD` | nur eigene: `audio_feed.gd`, zwei Testdateien, `config/game_config.json` (`audio.modern`, `audio._doc_modern`), `docs/audio-modern.md` |
| `audio_qc.py --determinism` | nicht nötig: keine Klangdatei, kein Generator geändert |
| Mutationen (Endstand) | 40 von 40 rot (`res/mutations_final.json`) |"""
body = body.replace("<<GATES>>", gates).replace("<<GATESDETAIL>>", detail)
out = head.replace("<<BODY>>", body.strip() + "\n")
assert "<<" not in out
open(S + "/deliver/AU-R4/bericht.md", "w", encoding="utf-8").write(out)
print(len(out.splitlines()), "Zeilen")
