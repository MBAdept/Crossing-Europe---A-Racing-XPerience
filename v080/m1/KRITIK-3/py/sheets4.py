from compose import *
from PIL import Image

# M impostor flatness: selected rows of the levels sheet (noon)
lv = Image.open(S + 'v_levels_sel.png').convert('RGB')
out = title(lv, 'M5 – Stufen an den Umschaltentfernungen (Mittel: 60 / 200 m): lod0, lod1 in 60 m | lod1, Fernbild, Arcade-Sprite in 200 m (vergrößert)',
            'Gemessen (innere Pixel, Mittag): Fernbild gegen lod1 Sättigung −5 … −19 %, Kontrast (Streuung der Helligkeit) −32 … −80 %; die Birke wird blass, die Fichte verliert ihre Etagen. Zeilen: Eiche, Birke, Buche, Pappel, Fichte, Palme')
save(out, '12_M5_stufen_fernbild_flach.jpg', q=86)

# sparkle sheet
sp = Image.open(S + 'sparkle.png').convert('RGB')
out = title(sp, 'Flimmern: Anteil der Pixel, die bei einer Viertel-Pixel-Verschiebung kippen (Modell und darunter das Arcade-Sprite, 40 / 80 / 150 m)',
            'Gemessen, 8 Schritte je Entfernung: Modell 0,7–13,9 %, Sprite 0,6–12,4 % – Kiefer und Fichte in 80–150 m 1,3–1,6-mal so viel wie ihr Sprite, sonst gleich')
save(out, '13_flimmern_subpixel.jpg', q=84)

# outlines lod0
ug = Image.open(S + 'umriss_lod0_grid.png').convert('RGB')
out = title(ug, 'Umriss lod0 in der Sprite-Kamera (orthografisch, 6°) über dem Sprite-Umriss: grün beide, orange nur Modell, blau nur Sprite')
save(out, '04_umrisse_lod0_gegen_sprite.png')
