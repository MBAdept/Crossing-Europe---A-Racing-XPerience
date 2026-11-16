from compose import *
from PIL import Image
im = Image.open(S + 'nebel_check.png').convert('RGB')
out = title(im, 'Fernbild (je erste Zeile) und Arcade-Sprite (je zweite Zeile) in 300 / 500 / 700 / 850 m im Renn-Nebel, Mittag, Mittel (4x vergrößert)',
            'Eiche, Birke, Fichte, Pappel, Palme: beide verblassen gleich – keine blassen Flecken mehr wie bei AS1b; nur der helle Palmenstamm bleibt in 500 m sichtbar, wo der Sprite-Stamm schon verschwindet')
save(out, '17_fernbild_im_nebel.jpg', q=84)
