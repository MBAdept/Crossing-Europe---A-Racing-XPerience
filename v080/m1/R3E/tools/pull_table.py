"""For every sprite set: picture height, lowest row below the anchor and the pull factor of the flat picture on a
level road (camera 3.4 m above the road, no pitch) - how much nearer the picture is drawn than the car."""
import json, sys
root = sys.argv[1]
sm = json.load(open(root + '/assets/sprites/manifest.json'))
for sid, s in sorted(sm['sets'].items()):
    if s.get('render') == 'box' or 'cell' not in s:
        continue
    cw, ch = s['cell']
    w = float(s.get('image_width_m', 0.0))
    piv = s.get('pivot', s.get('anchor', [0.5, 1.0]))
    if isinstance(piv, dict):
        ay = piv.get('y', 1.0)
    else:
        ay = piv[1] if isinstance(piv, list) else 1.0
    h = w * ch / cw
    vb = (ay - 1.0) * h
    for m in (0.02, 0.15):
        pass
    k = 3.4 / (3.4 - vb + 0.02)
    print('%-24s cell %4dx%-4d w %.2f m  h %.2f m  anchor_y %.3f  v_bot %.3f m  k %.3f  persp %s' % (
        sid, cw, ch, w, h, ay, vb, k, bool(s.get('perspective', False))))
