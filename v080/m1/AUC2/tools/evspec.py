"""Event spectrogram sheet: short window (1024), 50 dB range, one row per file, own time axis per row."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import media
from PIL import Image, ImageDraw
def img(x, width, rows, n=1024, floor=50.0):
    mono = x.mean(axis=1)
    hop = max(64, len(mono) // width)
    mono = np.concatenate([mono, np.zeros(n)])
    frames = np.array([mono[i:i + n] * np.hanning(n) for i in range(0, len(mono) - n, hop)])
    S = 20 * np.log10(np.abs(np.fft.rfft(frames, axis=1)).T + 1e-9)
    f = np.fft.rfftfreq(n, 1 / 44100)
    fl = np.geomspace(100, 16000, rows)
    im = S[np.clip(np.searchsorted(f, fl), 0, len(f) - 1)][::-1]
    hi = im.max()
    im = np.clip((im - (hi - floor)) / floor, 0, 1)
    rgb = np.stack([im ** 0.6 * 255, im ** 1.4 * 225, (1 - im) * 70 + im * 30], axis=2).astype(np.uint8)
    return Image.fromarray(rgb).resize((width, rows * 2))
out, paths = sys.argv[1], sys.argv[2:]
W, R = 1200, 100
canvas = Image.new("RGB", (W, len(paths) * (2 * R + 18)), (20, 20, 28))
dr = ImageDraw.Draw(canvas)
for k, p in enumerate(paths):
    x = media.read(p)
    y0 = k * (2 * R + 18)
    dr.text((6, y0 + 2), f"{os.path.basename(p)}  {len(x)/44100:.2f} s  (100 Hz–16 kHz log, 50 dB)", fill=(240, 240, 240), font=media.FONT)
    canvas.paste(img(x, W, R), (0, y0 + 18))
canvas.save(out)
