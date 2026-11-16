S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
s = open(S + "bericht_ab.md").read()
s = s.replace("(`fahrt_wuerzburg_altstadt_50kmh.mp4`, `tools/ab_clip.sh`, Kassel–Würzburg\nab km 202,0, 12 Uhr, „Hoch“, 10 s, 60 Bilder/s fest, Arcade | Modern): {{CLIP}}",
              "(`fahrt_wuerzburg_altstadt.mp4`, `tools/ab_clip.sh`, Kassel–Würzburg\nab km 202,0, 12 Uhr, „Hoch“, 10 s, 60 Bilder/s fest, Arcade | Modern): 600 Bilder je Seite, 960×540 je Hälfte, 7,4 MB "
              "(gemessen; Modern-Lauf 2 176 s, Arcade 193 s). **Abweichung:** fliegender Start mit 50 km/h, aber der Autopilot "
              "beschleunigt trotz Tempo 50 auf 128 km/h (5 s) und bremst dann auf 60 km/h (9,5 s) – eine feste Geschwindigkeit "
              "bietet die Rennszene nicht, und ein zweiter Lauf (40 min) war nicht drin. Angesehen (Standbilder bei 1, 5 und 9,5 s in "
              "`fahrt_wuerzburg_altstadt_standbilder.jpg`): Fachwerkzeilen, Turmhäuser und Barockhäuser stehen beidseits wie in "
              "Arcade, mit Tiefe und richtiger Perspektive; kein Aufblitzen, kein Loch, keine fehlenden Häuser in den Bildern; ob "
              "das Umschalten der Stufen in Bewegung auffällt, ist im Film bei dieser Fahrt nicht sicher zu sehen (gefolgert: bei "
              "60 m und 10–32 % Pixelwechsel möglich, siehe Messungen).")
assert "{{CLIP}}" not in s
open(S + "bericht_ab.md", "w").write(s)
l = open(S + "bericht_lieferung.md").read()
l = l.replace("| `bericht.md` | dieser Bericht |",
              "| `golden_modern_s4_hamburg_stadtrand_neu.jpg`, `golden_modern_s5_hamburg_ziel_neu.jpg` | die beiden geänderten "
              "Modern-Goldens (Stadthäuser statt Arcade-Bilder), angesehen vor dem Neuschreiben der Liste |\n| `bericht.md` | dieser Bericht |")
open(S + "bericht_lieferung.md", "w").write(l)
print("ok")
