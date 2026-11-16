S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
g = open(S + "bericht_gates.md").read()
txt = ("`tools/run_tests.sh engine3_checks` → `2 Tests, 0 fehlgeschlagen` (der Motortest war ein Lastausreißer); "
       "`tools/run_tests.sh music_checks` → wieder rot: der Schlag nach dem Einzähler kommt in beiden Läufen "
       "gleich 239,2 ms nach „LOS!“ (zwei Treiber-Schübe später als die 53,4 ms, die der Test im Kommentar nennt; "
       "erlaubt waren 278 bzw. 186 ms je nach längstem Bild). Der Test läuft kopflos mit `--graphics=arcade` "
       "(`tests/unit/audio_modern/check_music.gd`) – er lädt weder den Modern-Renderer noch ein Modell; dieses Paket "
       "ändert keine Klang- oder Spieldatei. **Nicht von AS5a1 verursacht** (gefolgert aus dem Code); auf der Basis "
       "nicht gegengeprüft (Zeit)")
g = g.replace("{{RETEST}}", txt)
open(S + "bericht_gates.md", "w").write(g)
print("ok" if "{{" not in g else "Platzhalter übrig")
