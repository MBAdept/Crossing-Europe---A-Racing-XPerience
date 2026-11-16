import sys

import numpy as np
from PIL import Image

D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/'
im = np.array(Image.open(D + 'cs_tree_sun.png').convert('RGB')).astype(float)


def lin(c):
    return (np.array(c) / 255.0) ** 2.2


a = im[120:220, 170:300].reshape(-1, 3).mean(axis=0)
b = im[120:220, 180 + 960:310 + 960].reshape(-1, 3).mean(axis=0)
print('sun %-18s lod1 %s impostor %s  linear ratio lod1/impostor %s' % (sys.argv[1], a.round(0), b.round(0), (lin(a) / lin(b)).round(2)))
