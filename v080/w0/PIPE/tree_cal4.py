"""scratch: crown of lod1 (tile 1) against the impostor (tile 3) in cs_probe.png; display values and the
ratio of the linear values behind them (inverse of the renderer's show())."""
import sys

import numpy as np
from PIL import Image

D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/'
im = np.array(Image.open(D + 'cs_probe.png').convert('RGB')).astype(float)


def lin(c):
    return ((np.array(c) / 255.0 + 0.055) / 1.055) ** 2.4


a = im[120:220, 170:300].reshape(-1, 3).mean(axis=0)
b = im[120:220, 180 + 960:310 + 960].reshape(-1, 3).mean(axis=0)
print('%-34s lod1 %-18s impostor %-18s impostor/lod1 display %s  linear %s' % (
    sys.argv[1], a.round(1), b.round(1), (b / np.maximum(a, 0.5)).round(2), (lin(b) / lin(a)).round(2)))
