from compose import *
from PIL import Image
A = K + '/ab/'
a = Image.open(A + 'bm42_hoch_arcade_01.png').convert('RGB')
m = Image.open(A + 'bm42_hoch_modern_01.png').convert('RGB')
box = (360, 230, 1280, 440)
ca = a.crop(box).resize((1840, 420), Image.NEAREST); cm = m.crop(box).resize((1840, 420), Image.NEAREST)
label(ca, 'Arcade'); label(cm, 'Modern')
out = Image.new('RGB', (1840, 848), (255, 255, 255)); out.paste(ca, (0, 0)); out.paste(cm, (0, 428))
out = title(out, 'Rennen Barcelona–Montpellier km 43, Mittag, Hoch (2x): Olive in etwa 20 m silbergrau und feiner als das Sprite; Palme in 60 m dünner und heller, Zypressen gleich',
            'tools/ab_shot.sh, gleicher Simulationszustand')
save(out, '18_rennen_mittelmeer.jpg')
