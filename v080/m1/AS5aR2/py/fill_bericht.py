S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/"
rep = {
    "bericht_mess.md": [
        ("LOD1SUD", "3 916"), ("LOD1MAI", "2 100"), ("SWAPSUD", "8,2 / 4,3 %"), ("SWAPMAI", "8,6 / 6,0 %"),
        ("SPARKSUD", "0,9 / 0,9 / 1,0 / 1,5 %"), ("SPARKMAI", "0,5 / 0,7 / 1,3 / 1,6 %"),
        ("Südhaus lod1/lod0: vorher 69 %, nachher LOD1PCT (mit den Blattkarten der Fernstufe).",
         "Südhaus lod1/lod0: vorher 69 %, nachher 67 % – die Blattkarten liegen in beiden Stufen (mit weniger Karten in "
         "lod1 sprang die Krone beim Wechsel: 27,5 % bzw. 34,8 % der Pixel)."),
    ],
    "bericht_einordnung.md": [
        ("- **Stufenwechsel** tauschen weiter 9–18 % der Pixel (Südhaus SWAPSUDTXT); Überblenden bleibt R7.",
         "- **Stufenwechsel** tauschen weiter 9–17 % der Pixel (Südhaus jetzt 8,2 % statt 16,4 %); Überblenden bleibt R7."),
    ],
    "bericht_aenderungen.md": [
        ("`lod1_opaque=True` für Mietshaus, Gründerzeit, Südhaus, Lyoner Haus, Haussmann, Eckhaus, Chalet, Loire-Haus; "
         "`leaf_cards` Südhaus und Loire-Haus (Loire-Haus dafür `single_cutout`);",
         "`lod1_opaque=True` für Mietshaus, Gründerzeit, Lyoner Haus, Haussmann, Eckhaus, Chalet; `leaf_cards` Südhaus und "
         "Loire-Haus mit denselben Karten in lod1 (`n1`, `half1`; Loire-Haus dafür `single_cutout`);"),
        ("| `tools/blender/ce3d/cities3d.py` | Blattkarten: `_crown_logger`,",
         "| `tools/blender/ce3d/cities3d.py` | Blattkarten (lod0 und, mit `n1`, lod1): `_crown_logger`,"),
    ],
}
for f, pairs in rep.items():
    s = open(S + f).read()
    for a, b in pairs:
        assert s.count(a) == 1, (f, a[:50])
        s = s.replace(a, b)
    open(S + f, "w").write(s)
print("ok")
