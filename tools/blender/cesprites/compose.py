"""Pillow/numpy post-processing: base-layer border fade, light layers (alpha from brightness + glow),
sheet assembly."""
import numpy as np
from PIL import Image


def load(path):
    im = Image.open(path).convert("RGBA")
    return np.asarray(im).astype(np.float32) / 255.0


def to_image(arr):
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def border_fade(alpha, px):
    """Multiplies alpha with a ramp so that nothing touches the cell border (soft clip of shadows/glow)."""
    if px <= 0:
        return alpha
    h, w = alpha.shape
    ys = np.minimum(np.arange(h), np.arange(h)[::-1]).astype(np.float32)
    xs = np.minimum(np.arange(w), np.arange(w)[::-1]).astype(np.float32)
    ry = np.clip((ys - 1.0) / px, 0.0, 1.0)
    rx = np.clip((xs - 1.0) / px, 0.0, 1.0)
    return alpha * np.outer(ry, rx)


def _gauss_kernel(sigma):
    r = max(1, int(sigma * 3.0 + 0.5))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-(x * x) / (2.0 * sigma * sigma))
    return k / k.sum(), r


def blur(img, sigma):
    """Separable gaussian blur of an HxWxC float array."""
    if sigma <= 0.05:
        return img.copy()
    k, r = _gauss_kernel(sigma)
    out = np.pad(img, ((0, 0), (r, r), (0, 0)), mode="constant")
    acc = np.zeros_like(img)
    for i, kv in enumerate(k):
        acc += kv * out[:, i:i + img.shape[1], :]
    out = np.pad(acc, ((r, r), (0, 0), (0, 0)), mode="constant")
    acc2 = np.zeros_like(img)
    for i, kv in enumerate(k):
        acc2 += kv * out[i:i + img.shape[0], :, :]
    return acc2


def base_post(arr, fade_px=4.0, shadow=None, shadow_strength=0.75, shadow_color=(0.02, 0.025, 0.03)):
    """Object render (+ optional separate shadow render, composited underneath) with border fade."""
    out = arr.copy()
    if shadow is not None:
        sa = np.clip((shadow[:, :, 3] - 3.0 / 255.0) * shadow_strength, 0.0, 1.0)[:, :, None]
        fa = out[:, :, 3:4]
        ra = fa + sa * (1.0 - fa)
        rgb = (out[:, :, :3] * fa + np.array(shadow_color, dtype=np.float32) * sa * (1.0 - fa)) / np.maximum(ra, 1e-6)
        out = np.concatenate([rgb, ra], axis=2)
    out[:, :, 3] = border_fade(out[:, :, 3], fade_px)
    return out


def light_post(arr, glows=((1.5, 0.6),), fade_px=4.0, gain=1.0, white_max=0.55):
    """Emission render (straight RGBA, black occluders) -> overlay layer: colour + alpha from brightness.
    glows: [(sigma_px, strength)] blurred copies added to the emission (bloom)."""
    e = np.maximum(arr[:, :, :3] * arr[:, :, 3:4] - 2.0 / 255.0, 0.0) * gain   # noise floor
    c = e.copy()
    for sigma, strength in glows:
        if strength > 0:
            c += blur(e, sigma) * strength
    m = c.max(axis=2)
    alpha = np.clip(m, 0.0, 1.0)
    # straight colour = hue normalised to max channel 1; alpha carries the brightness
    rgb = c / np.maximum(m, 1e-6)[:, :, None]
    # very bright pixels burn towards white (hot core of lamps)
    white = np.clip((m - 1.0) / 5.0, 0.0, white_max)[:, :, None]
    rgb = rgb * (1.0 - white) + white
    out = np.zeros_like(arr)
    out[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    alpha = np.where(alpha < 1.5 / 255.0, 0.0, alpha)
    out[:, :, 3] = border_fade(alpha, fade_px)
    out[:, :, :3] *= (out[:, :, 3:4] > 0.0)
    return out


def sheet(grid, cell):
    """grid: rows (layers) of columns (angles) of float RGBA arrays -> PIL image."""
    cw, ch = cell
    rows = len(grid)
    cols = len(grid[0])
    img = Image.new("RGBA", (cw * cols, ch * rows), (0, 0, 0, 0))
    for r, row in enumerate(grid):
        for c, arr in enumerate(row):
            img.paste(to_image(arr), (c * cw, r * ch))
    return img


def outline(arr, px=2, color=(0.08, 0.09, 0.11), strength=0.85):
    """Dark outline behind an icon (dilated alpha), for readability at small sizes."""
    a = arr[:, :, 3]
    d = a.copy()
    for dy in range(-px, px + 1):
        for dx in range(-px, px + 1):
            if dx * dx + dy * dy > px * px + 0.5:
                continue
            d = np.maximum(d, np.roll(np.roll(a, dy, axis=0), dx, axis=1))
    d = blur(d[:, :, None], 0.6)[:, :, 0] * strength
    out = np.zeros_like(arr)
    out[:, :, :3] = np.array(color, dtype=np.float32)
    out[:, :, 3] = d
    # composite arr over outline
    fa = arr[:, :, 3:4]
    oa = out[:, :, 3:4]
    ra = fa + oa * (1 - fa)
    rgb = (arr[:, :, :3] * fa + out[:, :, :3] * oa * (1 - fa)) / np.maximum(ra, 1e-6)
    res = np.concatenate([rgb, ra], axis=2)
    return res
