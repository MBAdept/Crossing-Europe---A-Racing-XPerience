import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import numpy as np
import kritik_lib as K
from PIL import Image
lines = ['Silhouette: Sprite (Alpha > 0,9, ohne Bodenschatten) gegen Modell (rote Maske), gleiche Kamera']
ims = []
def model_mask(img):
    a = np.asarray(img.convert('RGB')).astype(int)
    return (a[..., 0] > 200) & (a[..., 1] < 80) & (a[..., 2] < 80)
def overlay(sm, mm):
    o = np.zeros(sm.shape + (3,), np.uint8)
    o[sm & mm] = (150, 150, 150)
    o[sm & ~mm] = (255, 60, 60)
    o[~sm & mm] = (60, 160, 255)
    return Image.fromarray(o)
def stats(sm, mm):
    iou = (sm & mm).sum() / max(1, (sm | mm).sum())
    return iou, int((sm & ~mm).sum()), int((~sm & mm).sum())
for car, sid in (("sedan", "traffic/sedan_red"), ("hatch", "traffic/hatch_red"), ("wagon", "traffic/wagon_green")):
    m = K.sprite_meta(sid); cw, ch = m["cell"]
    for yaw, ang in ((0, 'c'), (24, 'l24')):
        s = K.sprite_cell(sid, ang, 'base').resize((cw * 2, ch * 2), Image.LANCZOS)
        sm = np.asarray(s)[..., 3] > 230
        for lod in ('lod0', 'lod2'):
            mm = model_mask(K.tile(f'{car}_sil_{lod}_y{yaw}', 's'))
            iou, a, b = stats(sm, mm)
            lines.append(f'  {car:6s} {yaw:+3d}° {lod}: IoU {iou:.3f}, nur Sprite {a:5d} px, nur Modell {b:5d} px (bei 104 px/m)')
            if lod == 'lod0':
                ims.append(K.caption(overlay(sm, mm).resize((cw * 4, ch * 4), Image.NEAREST), f'{car} {yaw:+d}° lod0: IoU {iou:.2f}', 13))
for car in ('limousine', 'kompakt'):
    mm = model_mask(K.tile(f'{car}_sil_g9', 's'))
    m = K.sprite_meta('player/' + car); ax, ay = m['anchor']
    sc = 1.65 / m['supersample']      # the cell is rendered supersample times the screen size
    cell = K.sprite_cell('player/' + car, 'c', 'base')
    cell = cell.resize((round(cell.width * sc), round(cell.height * sc)), Image.LANCZOS)
    cw, ch = cell.size
    px, py = 640 * 1.65, (324 + 3.4 * 711 / 9) * 1.65
    x0, y0 = round(px - ax * cw), round(py - ay * ch)
    smc = np.asarray(cell)[..., 3] > 230
    mmc = mm[y0:y0 + ch, x0:x0 + cw]
    iou, a, b = stats(smc, mmc)
    lines.append(f'  {car:9s} Spielkamera 9 m (1,65x): IoU {iou:.3f}, nur Sprite {a} px, nur Modell {b} px')
    ims.append(K.caption(overlay(smc, mmc), f'{car} 9 m (1,65x): IoU {iou:.2f}', 13))
sheet = K.grid(ims, 2)
sheet = K.title(sheet, 'Silhouette: Sprite (Generator, Cycles) gegen Echtzeit-Modell, gleiche Kamera',
                sub='grau = beide, rot = nur im Sprite, blau = nur im Modell')
print(K.save_jpg(sheet, K.DELIVER + '/18_silhouette_sprite_modell.jpg', q=90))
open(K.OUT + '/silhouette.txt', 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
