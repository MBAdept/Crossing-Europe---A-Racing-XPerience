p = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6/bericht_teil_look.md"
s = open(p).read()
rep = {
    "BASIS_STATION": "Tag: kaum Unterschied (FIX1 hatte schon Insel, Dach, Stützen); Nacht: R6 weiße Leuchtkästen und Arcades weißer Schein statt der orangen Punktlampen der Basis, Unterseite heller, Vorplatz – näher an Arcade, **nicht schlechter** (Bild 03, 03b)",
    "BASIS_KH": "wie DEV (Bild 25)",
    "BASIS_RADAR": "Basis ohne Blitzschein, R6 mit kleinem weißem Schein am Kopf – besser (Bild 26)",
    "BASIS_CITY": "praktisch gleich (die Basis zeichnete die Laternen über `props.gd`); R6-Kegel heller (0,55 statt 0,30 in der Mitte), im Bild kaum zu sehen (Bild 26)",
    "BASIS_START": "Basis: „START“ nachts reinweiß (heller als Arcade), R6: hellgrau wie Arcade, dazu roter Schein um die Lampe wie Arcade – gleichwertig (Bild 26, 27)",
    "BASIS_FINISH": "Basis: Banner nachts fast schwarzrot, R6: rot mit Schachbrett – besser als die Basis, aber noch dunkler als Arcade (Bild 26)",
}
for k, v in rep.items():
    s = s.replace(k, v)
open(p, "w").write(s)
print([k for k in rep if k in s])
