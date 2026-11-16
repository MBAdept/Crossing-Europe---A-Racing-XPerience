import json, sys
from PIL import Image
import numpy as np
root = sys.argv[1]
sm = json.load(open(root + '/assets/sprites/manifest.json'))
for sid in ['traffic/sports_red', 'traffic/van_white', 'police/de', 'player/kombi', 'traffic/suv_grey']:
    s = sm['sets'][sid]
    im = np.asarray(Image.open(root + '/assets/sprites/' + s['file']).convert('RGBA')).astype(np.float32)
    cw, ch = s['cell']
    n = len(s['angles'])
    g = s['grid_cols']
    i = n // 2 + 2  # base layer, a turned cell
    x, y = (i % g) * cw, (i // g) * ch
    c = im[y:y + ch, x:x + cw]
    a = c[..., 3] / 255.0
    lum = (0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]) / 255.0
    # shadow: semi-transparent and dark, or any pixel in the bottom 25 % rows right of the centre
    semi = (a > 0.02) & (a < 0.98)
    dark = semi & (lum < 0.08)
    hist = np.histogram(a[dark], bins=[0.02, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.98])[0]
    print(sid, 'dunkle halbtransparente Pixel nach Alpha:', list(hist), ' max', round(float(a[dark].max()) if dark.any() else 0, 3))
