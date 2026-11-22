import sys
S = sys.argv[1]


def edit(name, pairs):
    p = S + "/" + name
    t = open(p, encoding="utf-8").read()
    for a, b in pairs:
        assert t.count(a) == 1, (name, a[:70])
        t = t.replace(a, b)
    open(p, "w", encoding="utf-8").write(t)


edit("bericht_teil1.md", [
    ("""Maschine (Xvfb, llvmpipe, Godot 4.7.2 Compatibility), sonst steht **(gefolgert)** dabei. Jeder Spiellauf mit
absolutem `XDG_DATA_HOME` im Arbeitsordner und `--graphics` ausdrücklich; schwere Läufe einzeln über eine
Warteschlange, `nice -n 10`, `LP_NUM_THREADS=2`.""",
     """Maschine (Xvfb, llvmpipe, Godot 4.7.2 Compatibility), sonst steht **(gefolgert)** dabei. Jeder Spiellauf mit
`--graphics` ausdrücklich und einem eigenen absoluten `XDG_DATA_HOME` – **bis auf rund 20 Einzelprüfungen eines
Hilfsskripts, die den echten Benutzerordner trafen (selbst gefunden, §6)**; schwere Läufe einzeln über eine
Warteschlange, `nice -n 10`, `LP_NUM_THREADS=2`."""),
])
edit("bericht_gates.md", [
    ("die Strukturprüfung (`countdown`, `zieltor`, `grenze`, `blitz`) auf dem Endstand `02051f7` erneut OK",
     "die Strukturprüfung (`countdown`, `zieltor`, `grenze`, `blitz`) auf `02051f7` erneut OK"),
])
edit("bericht_teil6.md", [
    ("""  (Requisiten 0,12–4,19 ms in vier Läufen ohne Änderung) – auf dem Gerät nicht gemessen.

- **Regelverstoß""", """  (Requisiten 0,12–4,19 ms in vier Läufen ohne Änderung) – auf dem Gerät nicht gemessen.
- **Regelverstoß"""),
])
edit("bericht_teil7.md", [
    ("(Arcade matt).\n**Gleich**", "(Arcade matt).\n\n**Gleich**"),
    ("die Gotthard-Ausfahrt im Clip.\n**Schlechter**", "die Gotthard-Ausfahrt im Clip.\n\n**Schlechter**"),
    ("## 7. Besser / gleich / schlechter als Arcade (alle angesehenen Bilder)\n\n**Besser**\n", "## 7. Besser / gleich / schlechter als Arcade (alle angesehenen Bilder)\n\n**Besser**\n\n"),
])
print("ok")
