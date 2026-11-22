"""band.py <png...> : scene band (rows 25-80 %) mean luminance (0-255) and share of near-white pixels (gray >= 240),
the metric of QA's lumtrace.py, for single pictures."""
import sys
import numpy as np
from PIL import Image

for p in sys.argv[1:]:
    a = np.asarray(Image.open(p).convert('L')).astype(np.float64)
    h = a.shape[0]
    b = a[int(h * 0.25):int(h * 0.80)]
    print('%-34s lum %6.1f  white %.3f' % (p.split('/')[-1], b.mean(), (b >= 240).mean()))
