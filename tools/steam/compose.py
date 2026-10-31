#!/usr/bin/env python3
"""Steam library artwork for "Crossing Europe - A Racing Xperience": composite the final set.

Building blocks (rendered beforehand by the other scripts in tools/steam/):
  --logo-dir   transparent logo lockups from render_logo.gd (Godot, the real title-screen GradientText):
               logo_stacked_left[_glow].png, logo_stacked_center_glow.png, logo_wide.png, monogram_ce.png
               (default: $CE_LOGO_OUT, else /tmp/crossing-europe-steam/logo - render_logo.gd's default)
  --scene-dir  text-free key art from keyart_scene.py (Blender / Cycles), @2x of the Steam sizes:
               portrait.png 1200x1800, landscape.png 1840x860, hero.png 3840x1240, icon_bg.png 1024
               (default: $STEAM_SCENE_OUT, else /tmp/crossing-europe-steam/scene - keyart_scene.py's default)

Output (--out, default $STEAM_ART_OUT, else marketing/steam/ in this repository; an empty .gdignore is
created there when the directory lies inside the Godot project, so Godot neither imports nor exports it):
  grid_portrait_1200x1800.png   grid_portrait_600x900.png    library grid, portrait capsule (with logo)
  grid_landscape_1840x860.png   grid_landscape_920x430.png   library grid, landscape capsule (with logo)
  hero_3840x1240.png            hero_1920x620.png            game page banner (no logo, no text)
  logo.png                                                   stacked lockup (title-screen layout),
                                                             transparent, tightly cropped
  logo_1280x720.png                                          the same on a transparent 1280x720 canvas
  logo_wide.png                                              alternative: one-line lockup, tightly cropped
  icon_512.png  icon_256.png  icon.ico (16 24 32 48 64 128 256)
  preview.png                                                QA: everything + Steam-size thumbnails

Run (python3 with Pillow + numpy, from anywhere; ~20 s; the output is identical on every run):
  python3 tools/steam/compose.py [--logo-dir DIR] [--scene-dir DIR] [--out DIR]

Composition (constants PORTRAIT / LANDSCAPE / ICON / SMALL below):
  * Both grid capsules carry the stacked lockup with its soft glow, so the logo shares the scene's bloom
    instead of looking pasted on. Portrait: centred lockup in the calm starry sky above the sun.
    Landscape: the left-aligned lockup top-left, exactly like on the title screen, in the clear sky
    above the (here lowered) mountain ridges. Every run checks and prints that the logo stays clear of
    the sun, the car, the ridge crests and the edges.
  * Icon: icon_bg (rendered without the road's centre line, so nothing shows between the C and the E)
    with the ground below the horizon calmed (grid inside the letter counters) + the CE monogram. The 16 / 24 / 32 px ICO frames use a simplified variant: ground almost black, the glyphs
    without their baked shadow plus a whole-pixel cyan shadow, a heavier ink outline, and scale and
    sub-pixel offset searched so the glyph edges sit on the pixel grid.

Image handling:
  * All maths in float32 on sRGB-encoded values in [0, 1] - the space Godot's 2D canvas blends in, so the
    logo looks exactly like on the title screen.
  * Layers with alpha are premultiplied right after loading. Resampling (Pillow LANCZOS on 32-bit float
    channels) and the "over" operator work on premultiplied data: no dark or coloured fringes and no 8-bit
    round trips in between. Lanczos overshoot is clamped (alpha to [0, 1], colour to [0, alpha]).
  * The @1x files are downscaled from the float @2x composites.
  * Opaque files: 8-bit RGB PNG. Anything resampled or tinted gets a seeded TPDF dither (reproducible)
    against banding in the dark sky; untouched background pixels of the @2x files stay bit-identical.
  * Transparent files: 8-bit RGBA PNG with straight alpha; the colour is bled into the fully transparent
    pixels, so apps that filter the texture without premultiplying show no dark halos.
"""
import argparse
import os
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
WORK = "/tmp/crossing-europe-steam"     # render_logo.gd / keyart_scene.py write here by default
DEFAULT_LOGO_DIR = os.environ.get("CE_LOGO_OUT", os.path.join(WORK, "logo"))
DEFAULT_SCENE_DIR = os.environ.get("STEAM_SCENE_OUT", os.path.join(WORK, "scene"))
DEFAULT_OUT = os.environ.get("STEAM_ART_OUT", os.path.join(ROOT, "marketing", "steam"))

LANCZOS = Image.Resampling.LANCZOS
NEAREST = Image.Resampling.NEAREST

# Brand colours (title screen / UiTheme): outline ink and the cyan accent.
INK = (0x1A, 0x05, 0x33)
CYAN = (0x29, 0xD8, 0xF5)

# ---- layout -------------------------------------------------------------------------------------------
# "body" = glyphs + ink outline of CROSSING / EUROPE (no shadow, no tagline, no glow); "frame" = everything
# the title screen draws (glyphs, outline, cyan shadow, tagline + its shadow). Fractions of the canvas.
PORTRAIT = dict(
    bg="portrait.png",  # rear view into the sun (title-screen composition); portrait_b.png = oncoming car
    logo="logo_stacked_center",
    glow=True,          # *_glow render: the logo glows like the bloomed sun and neon instead of looking pasted on
    body_w=0.86,        # glyph width of "CROSSING" / capsule width
    top=0.05,           # top of the frame / capsule height (the calm starry sky ends at y 0.30)
    scrim=0.0,          # darkening behind the logo (0 = none; the sky is calm and dark enough)
)
LANDSCAPE = dict(
    bg="landscape.png",
    logo="logo_stacked_left",  # left-aligned stack, exactly the title screen's layout
    glow=True,
    body_w=0.37,        # glyph width of "CROSSING" / capsule width (the logo side is x 0 .. 0.47)
    left=0.05,          # left edge of the glyphs
    cy=0.225,           # vertical centre of the frame: top-left like the title screen, in clear sky
    scrim=0.0,          # darkening behind the logo (0 = none: the ridges stay below the tagline)
)
ICON = dict(
    body_w=0.84,        # glyph width of "CE" / icon size
    cy=0.71,            # vertical centre of the glyphs
    horizon=0.58,       # icon_bg horizon (fraction of the height)
    ground=0.45,        # brightness the ground falls to below the horizon (calms the grid in the counters)
)
# Small ICO sizes (<= SMALL_MAX px): simplified high-contrast variant, composed on an `ss` x master and
# box-filtered down; the monogram's scale and sub-pixel offset are chosen so its edges sit on the pixel grid.
SMALL_MAX = 32
SMALL = dict(
    ss=16,              # supersampling factor of the master
    body_w=(0.84, 0.90),  # range searched for the glyph width (fraction of the icon)
    bottom=0.89,        # bottom of the glyphs (fraction of the icon)
    stroke=0.5,         # extra ink outline around glyphs + shadow, in output pixels
    shadow={16: 0, 24: 1, 32: 1},  # cyan shadow offset in whole output pixels (0 = none)
    ground=0.18,        # the ground below the horizon is calmed down to this brightness
)
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)
LOGO = "logo_stacked_left"  # Steam logo: the title screen's stacked lockup (fills Steam's logo box far
                            # better than the 8.9:1 one-line lockup, which ships as logo_wide.png)
LOGO_CANVAS = (1280, 720)
LOGO_CANVAS_MARGIN = 0.05   # free border on each side of the logo_1280x720 canvas
PNG_LEVEL = 6               # zlib level: 9 is ~5 % smaller but ~10x slower


# ---- float image helpers ------------------------------------------------------------------------------
def load(path):
    """PNG -> float32 HxWxC in [0, 1]. Images with alpha come back premultiplied."""
    with Image.open(path) as im:
        has_alpha = "A" in im.getbands() or "transparency" in im.info
        im = im.convert("RGBA" if has_alpha else "RGB")
        arr = np.asarray(im, dtype=np.float32) / 255.0
    if has_alpha:
        arr[..., :3] *= arr[..., 3:4]
    return arr


def clamp(arr):
    if arr.shape[2] == 4:
        a = np.clip(arr[..., 3:4], 0.0, 1.0)
        return np.concatenate([np.clip(arr[..., :3], 0.0, a), a], axis=-1)
    return np.clip(arr, 0.0, 1.0)


def resize(arr, w, h):
    """LANCZOS resample, channel by channel in 32-bit float (premultiplied if the image has alpha)."""
    if arr.shape[0] == h and arr.shape[1] == w:
        return arr.copy()
    chans = [np.asarray(Image.fromarray(np.ascontiguousarray(arr[..., c])).resize((w, h), LANCZOS))
             for c in range(arr.shape[2])]
    return clamp(np.stack(chans, axis=-1))


def over(dst, src, x, y):
    """In place: premultiplied `src` over `dst` (opaque RGB or premultiplied RGBA), top-left at (x, y)."""
    hd, wd = dst.shape[:2]
    hs, ws = src.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + ws, wd), min(y + hs, hd)
    if x0 >= x1 or y0 >= y1:
        return dst
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    a = s[..., 3:4]
    d[...] = (s[..., :3] if dst.shape[2] == 3 else s) + d * (1.0 - a)
    return dst


def bbox(mask):
    ys = np.flatnonzero(mask.any(axis=1))
    xs = np.flatnonzero(mask.any(axis=0))
    return (int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1)


def straight(arr):
    """Premultiplied RGBA -> straight RGB (colour of fully transparent pixels: 0)."""
    a = arr[..., 3:4]
    return np.where(a > 1e-6, arr[..., :3] / np.maximum(a, 1e-6), 0.0)


def _box(x, r, axis):
    """Sum over a window of 2r+1 along `axis` (zero padded)."""
    n = x.shape[axis]
    pad = [(0, 0)] * x.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(x.astype(np.float64), pad), axis=axis)
    return np.take(c, np.arange(2 * r + 1, n + 2 * r + 1), axis=axis) - np.take(c, np.arange(n), axis=axis)


def bleed(rgb, a):
    """Give fully transparent pixels the alpha-weighted mean colour of their visible neighbourhood."""
    out = rgb.copy()
    done = a > 0
    num = rgb * a[..., None]
    r = 1
    while not done.all() and r <= 2 * max(a.shape):
        n = _box(_box(num, r, 0), r, 1)
        d = _box(_box(a, r, 0), r, 1)
        m = ~done & (d > 1e-9)
        out[m] = n[m] / d[m][:, None]
        done |= m
        r *= 2
    return out


def dilate(a, r):
    """Max filter with a disc of radius r (pixels) on a 2D array."""
    out = a.copy()
    ri = int(np.ceil(r))
    h, w = a.shape
    p = np.pad(a, ri)
    for dy in range(-ri, ri + 1):
        for dx in range(-ri, ri + 1):
            if dx * dx + dy * dy <= r * r:
                np.maximum(out, p[ri + dy:ri + dy + h, ri + dx:ri + dx + w], out=out)
    return out


def scrim(rgb, cx, cy, rx, ry, strength):
    """Soft elliptical darkening centred on (cx, cy), in place: gaussian falloff exp(-1.5 d^2) over the
    elliptical distance d (in radii rx, ry), tapered to exactly zero at d = 2 - pixels outside stay
    untouched."""
    if strength <= 0:
        return rgb
    h, w = rgb.shape[:2]
    x0, x1 = max(0, int(cx - 2 * rx)), min(w, int(np.ceil(cx + 2 * rx)) + 1)
    y0, y1 = max(0, int(cy - 2 * ry)), min(h, int(np.ceil(cy + 2 * ry)) + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d2 = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2
    g = np.clip((np.exp(-1.5 * d2) - np.exp(-6.0)) / (1.0 - np.exp(-6.0)), 0.0, 1.0)
    rgb[y0:y1, x0:x1] *= (1.0 - strength * g)[..., None]
    return rgb


def to_u8(arr, dither=True, seed_name=""):
    """Float [0, 1] -> uint8. dither: TPDF (+-1 LSB, seeded by the file name) on every value that is not
    already an exact 8-bit level, so untouched pixels of an 8-bit source stay bit-identical."""
    v = arr * 255.0
    if dither:
        rng = np.random.default_rng(zlib.crc32(seed_name.encode()))
        n = rng.random(v.shape, dtype=np.float32) - rng.random(v.shape, dtype=np.float32)
        v = v + n * (np.abs(v - np.round(v)) > 1e-3)
    return np.clip(np.floor(v + 0.5), 0, 255).astype(np.uint8)


def save_rgb(arr, path):
    Image.fromarray(to_u8(arr[..., :3], True, os.path.basename(path)), "RGB").save(path, compress_level=PNG_LEVEL)


def rgba_image(arr):
    """Premultiplied float RGBA -> 8-bit straight-alpha PIL image, colour bled under alpha 0."""
    a8 = np.clip(np.floor(arr[..., 3] * 255.0 + 0.5), 0, 255)
    rgb = bleed(np.clip(straight(arr), 0.0, 1.0), np.where(a8 > 0, arr[..., 3], 0.0))
    out = np.dstack([np.clip(np.floor(rgb * 255.0 + 0.5), 0, 255), a8]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ---- logo geometry ------------------------------------------------------------------------------------
def body_box(img):
    """Glyphs + ink outline: opaque pixels that are not cyan (cyan = shadow, tagline, cyan glow)."""
    rgb = straight(img)
    cyan = (rgb[..., 0] < 0.47) & (rgb[..., 1] > 0.59) & (rgb[..., 2] > 0.70)
    return bbox((img[..., 3] >= 0.98) & ~cyan)


class Logo:
    """A logo render with its geometry in source pixels. The _glow renders have the same layout on a
    bigger canvas; their frame/body are the plain render's, shifted by the measured body offset."""

    def __init__(self, logo_dir, name, glow=False):
        plain = load(os.path.join(logo_dir, name + ".png"))
        self.frame = bbox(plain[..., 3] > 0)
        self.body = body_box(plain)
        self.img = plain
        if glow:
            self.img = load(os.path.join(logo_dir, name + "_glow.png"))
            gb = body_box(self.img)
            dx, dy = gb[0] - self.body[0], gb[1] - self.body[1]
            self.frame = (self.frame[0] + dx, self.frame[1] + dy, self.frame[2] + dx, self.frame[3] + dy)
            self.body = gb

    @property
    def body_w(self):
        return self.body[2] - self.body[0]

    def place(self, canvas, scale, src_pt, dst_pt):
        """Scale by `scale`, composite so that source point src_pt lands on dst_pt. Returns the placed
        frame and body rectangles in canvas pixels."""
        h, w = self.img.shape[:2]
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
        sx, sy = nw / w, nh / h
        x = round(dst_pt[0] - src_pt[0] * sx)
        y = round(dst_pt[1] - src_pt[1] * sy)
        over(canvas, resize(self.img, nw, nh), x, y)

        def tr(b):
            return (x + b[0] * sx, y + b[1] * sy, x + b[2] * sx, y + b[3] * sy)
        return tr(self.frame), tr(self.body)


# Sun, car and ridge-crest boxes of the key-art renders (fractions x0, y0, x1, y1; from keyart_scene.py's
# framing and render log). The placed logo frame must not touch them (checked and reported on every run).
SCENE_BOXES = {
    "portrait.png": {"sun": (0.23, 0.30, 0.77, 0.57), "car": (0.36, 0.63, 0.91, 0.89)},
    "portrait_b.png": {"sun": (0.23, 0.35, 0.77, 0.58), "car": (0.23, 0.53, 0.83, 0.74)},
    "landscape.png": {"sun": (0.53, 0.093, 0.77, 0.53), "car": (0.61, 0.53, 0.95, 0.90),
                      "ridge crests": (0.0, 0.40, 0.47, 0.53)},
}


def check_layout(name, frame, w, h, log):
    r = (frame[0] / w, frame[1] / h, frame[2] / w, frame[3] / h)
    msg = ["logo frame x %.3f-%.3f y %.3f-%.3f" % (r[0], r[2], r[1], r[3])]
    if r[0] < 0.02 or r[1] < 0.02 or r[2] > 0.98 or r[3] > 0.98:
        msg.append("WARNING: closer than 2% to the edge")
    for what, b in SCENE_BOXES.get(name, {}).items():
        gap = max(b[0] - r[2], r[0] - b[2], b[1] - r[3], r[1] - b[3])   # > 0: separated
        msg.append(("clear of the %s" % what) if gap > 0 else ("WARNING: overlaps the %s" % what))
    log("    " + ", ".join(msg))


# ---- assets -------------------------------------------------------------------------------------------
def compose_portrait(scene_dir, logo_dir, cfg=PORTRAIT, log=print):
    """Portrait capsule @2x: stacked lockup centred on its glyphs in the calm sky above the sun."""
    bg = load(os.path.join(scene_dir, cfg["bg"]))
    h, w = bg.shape[:2]
    logo = Logo(logo_dir, cfg["logo"], cfg["glow"])
    scale = cfg["body_w"] * w / logo.body_w
    src = ((logo.body[0] + logo.body[2]) / 2, logo.frame[1])
    dst = (w / 2, cfg["top"] * h)
    fh = (logo.frame[3] - logo.frame[1]) * scale
    scrim(bg, w / 2, dst[1] + fh / 2, 0.62 * w, 0.75 * fh, cfg["scrim"])
    frame, _ = logo.place(bg, scale, src, dst)
    log("  portrait:  %s + %s%s" % (cfg["bg"], cfg["logo"], "_glow" if cfg["glow"] else ""))
    check_layout(cfg["bg"], frame, w, h, log)
    return bg


def compose_landscape(scene_dir, logo_dir, cfg=LANDSCAPE, log=print):
    """Landscape capsule @2x: stacked lockup in the calm left part, glyphs starting at cfg left."""
    bg = load(os.path.join(scene_dir, cfg["bg"]))
    h, w = bg.shape[:2]
    logo = Logo(logo_dir, cfg["logo"], cfg["glow"])
    scale = cfg["body_w"] * w / logo.body_w
    src = (logo.body[0], (logo.frame[1] + logo.frame[3]) / 2)
    dst = (cfg["left"] * w, cfg["cy"] * h)
    fw = (logo.frame[2] - logo.frame[0]) * scale
    fh = (logo.frame[3] - logo.frame[1]) * scale
    scrim(bg, dst[0] + fw / 2, dst[1], 0.75 * fw, 0.85 * fh, cfg["scrim"])
    frame, _ = logo.place(bg, scale, src, dst)
    log("  landscape: %s + %s%s, scrim %.2f" % (cfg["bg"], cfg["logo"], "_glow" if cfg["glow"] else "",
                                                cfg["scrim"]))
    check_layout(cfg["bg"], frame, w, h, log)
    return bg


def calm_ground(bg, horizon, floor, ramp=0.10):
    """Darken the ground below the horizon towards `floor` brightness over `ramp` (fractions of the height);
    the glowing horizon line and the sky / sun stay untouched. In place."""
    h = bg.shape[0]
    hy = int(round(horizon * h))
    t = np.clip(np.arange(h - hy, dtype=np.float32) / max(ramp * h, 1.0), 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    bg[hy:] *= (1.0 - (1.0 - floor) * t)[:, None, None]
    return bg


def icon_frame(size, icon_bg, mono, cfg=ICON):
    """The detailed icon at `size` px: icon_bg + the CE monogram (optically centred on its glyphs)."""
    bg = calm_ground(resize(icon_bg, size, size), cfg["horizon"], cfg["ground"])
    scale = cfg["body_w"] * size / mono.body_w
    src = ((mono.body[0] + mono.body[2]) / 2, (mono.body[1] + mono.body[3]) / 2)
    mono.place(bg, scale, src, (size / 2, cfg["cy"] * size))
    return bg


def glyphs_only(img):
    """The monogram without its baked-in cyan shadow (premultiplied): every cyan pixel is dropped. Mixed
    edge pixels are judged by colour; at the tiny icon sizes one source pixel is ~1/50 output pixel."""
    rgb = straight(img)
    cyan = (rgb[..., 0] < 0.47) & (rgb[..., 1] > 0.59) & (rgb[..., 2] > 0.70)
    return img * (~cyan)[..., None]


def _luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def _reduce(arr, f):
    """Exact box filter (area average) by an integer factor."""
    h, w, c = arr.shape
    return arr.reshape(h // f, f, w // f, f, c).mean(axis=(1, 3))


def _grad(img, axis):
    d = np.abs(np.diff(_luma(img), axis=axis))
    return float((d * d).sum()), float(d.sum())


def icon_small(size, icon_bg, mono, cfg=SMALL):
    """High-contrast icon for tiny sizes. Sky + sun of icon_bg over a ground calmed almost to black, the CE
    glyphs without the baked-in shadow (it fills the letter counters at this size), a cyan shadow of whole
    output pixels instead, and a heavier ink outline around both. Composed on an ss x master, box-filtered.
    The glyph width (within cfg body_w) and the sub-pixel offset are chosen for the crispest result:
    offsets by gradient energy, widths by energy / total variation (= edge sharpness, independent of how
    much edge there is). Returns (rgb float, info str)."""
    ss = cfg["ss"]
    m = size * ss
    bg = calm_ground(resize(icon_bg, m, m), ICON["horizon"], cfg["ground"], ramp=0.05)
    ink = np.array(INK, np.float32) / 255.0
    cyan = np.array(CYAN, np.float32) / 255.0
    glyphs = glyphs_only(mono.img)
    k = cfg["shadow"].get(size, 1) * ss
    pad = int(np.ceil(cfg["stroke"] * ss)) + 2
    best = None
    for bw in np.linspace(cfg["body_w"][0], cfg["body_w"][1], 7):
        scale = bw * m / mono.body_w
        h, w = glyphs.shape[:2]
        nw, nh = round(w * scale), round(h * scale)
        g = resize(glyphs, nw, nh)
        layer = np.zeros((nh + 2 * pad + k, nw + 2 * pad + k, 4), np.float32)
        if k:
            sa = 0.9 * g[..., 3:4]
            over(layer, np.concatenate([cyan * sa, sa], axis=-1), pad + k, pad + k)
        over(layer, g, pad, pad)
        st = dilate(layer[..., 3], cfg["stroke"] * ss)
        layer = over(np.dstack([ink * st[..., None], st]), layer, 0, 0)
        sx, sy = nw / w, nh / h
        x0 = int(round(m / 2 - ((mono.body[0] + mono.body[2]) / 2 * sx + pad)))
        y0 = int(round(cfg["bottom"] * m - (mono.body[3] * sy + pad)))

        def render(dx, dy):
            img = bg.copy()
            over(img, layer, x0 + dx, y0 + dy)
            return _reduce(img, ss)
        offsets = range(-ss // 2, ss // 2)
        dx = max(offsets, key=lambda d: _grad(render(d, 0), 1)[0])
        dy = max(offsets, key=lambda d: _grad(render(dx, d), 0)[0])
        img = render(dx, dy)
        (ex, tx), (ey, ty) = _grad(img, 1), _grad(img, 0)
        score = (ex + ey) / (tx + ty)
        if best is None or score > best[0]:
            best = (score, img, "glyph width %.3f, offset (%+.2f, %+.2f) px, shadow %d px"
                    % (bw, dx / ss, dy / ss, k // ss))
    return best[1], best[2]


def downscale2(arr):
    h, w = arr.shape[:2]
    return resize(arr, w // 2, h // 2)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--logo-dir", default=DEFAULT_LOGO_DIR, help="render_logo.gd output")
    ap.add_argument("--scene-dir", default=DEFAULT_SCENE_DIR, help="keyart_scene.py output")
    ap.add_argument("--out", default=DEFAULT_OUT, help="output directory (default: marketing/steam/)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    out = lambda name: os.path.join(args.out, name)  # noqa: E731
    gdignore(args.out)

    print("grid capsules")
    p2 = compose_portrait(args.scene_dir, args.logo_dir)
    save_rgb(p2, out("grid_portrait_1200x1800.png"))
    save_rgb(downscale2(p2), out("grid_portrait_600x900.png"))
    l2 = compose_landscape(args.scene_dir, args.logo_dir)
    save_rgb(l2, out("grid_landscape_1840x860.png"))
    save_rgb(downscale2(l2), out("grid_landscape_920x430.png"))

    print("hero (no logo, no text)")
    hero = load(os.path.join(args.scene_dir, "hero.png"))
    save_rgb(hero, out("hero_3840x1240.png"))
    save_rgb(downscale2(hero), out("hero_1920x620.png"))

    print("logo")
    for src, dst in ((LOGO, "logo.png"), ("logo_wide", "logo_wide.png")):
        with Image.open(os.path.join(args.logo_dir, src + ".png")) as im:   # untouched pixels, trimmed
            im = im.convert("RGBA")
            im.crop(im.getchannel("A").getbbox()).save(out(dst), compress_level=PNG_LEVEL)
    logo = Logo(args.logo_dir, LOGO)
    cw, ch = LOGO_CANVAS
    fw, fh = logo.frame[2] - logo.frame[0], logo.frame[3] - logo.frame[1]
    scale = min(cw * (1 - 2 * LOGO_CANVAS_MARGIN) / fw, ch * (1 - 2 * LOGO_CANVAS_MARGIN) / fh)
    canvas = np.zeros((ch, cw, 4), np.float32)
    logo.place(canvas, scale, ((logo.frame[0] + logo.frame[2]) / 2, (logo.frame[1] + logo.frame[3]) / 2),
               (cw / 2, ch / 2))
    rgba_image(canvas).save(out("logo_1280x720.png"), compress_level=PNG_LEVEL)
    print("  %s: %dx%d on the 1280x720 canvas" % (LOGO, round(fw * scale), round(fh * scale)))

    print("icon")
    icon_bg = load(os.path.join(args.scene_dir, "icon_bg.png"))
    mono = Logo(args.logo_dir, "monogram_ce")
    for s in (512, 256):
        save_rgb(icon_frame(s, icon_bg, mono), out("icon_%d.png" % s))
    frames = []
    for s in sorted(ICO_SIZES, reverse=True):
        if s <= SMALL_MAX:
            img, info = icon_small(s, icon_bg, mono)
            print("  ico %3d px: simplified, %s" % (s, info))
        else:
            img = icon_frame(s, icon_bg, mono)
        frames.append(Image.fromarray(to_u8(img, s >= 128, "icon%d" % s), "RGB").convert("RGBA"))
    frames[0].save(out("icon.ico"), format="ICO", sizes=[(s, s) for s in ICO_SIZES], append_images=frames[1:])

    print("preview sheet")
    contact_sheet(args.out, out("preview.png"))
    print("done:", args.out)


def gdignore(out_dir):
    """An empty .gdignore in an output directory inside the Godot project: Godot then neither imports the
    PNGs (no .import files, no editor scan) nor exports them into the game build."""
    out_dir = os.path.abspath(out_dir)
    inside = os.path.commonpath([out_dir, ROOT]) == ROOT and out_dir != ROOT
    path = os.path.join(out_dir, ".gdignore")
    if inside and os.path.exists(os.path.join(ROOT, "project.godot")) and not os.path.exists(path):
        open(path, "w").close()
        print("created", path)


# ---- contact sheet (QA) -------------------------------------------------------------------------------
def _font(size, bold=False):
    for p in ("/usr/share/fonts/opentype/inter/Inter-%s.otf" % ("Bold" if bold else "Medium"),
              "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else "")):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size)


def _checker(w, h, s=12):
    yy, xx = np.mgrid[0:h, 0:w]
    m = ((xx // s + yy // s) % 2 == 0)[..., None]
    return Image.fromarray(np.repeat(np.where(m, 74, 54), 3, axis=2).astype(np.uint8), "RGB")


def _over_pil(base, rgba, xy=(0, 0)):
    out = base.convert("RGBA")
    out.alpha_composite(rgba, xy)
    return out.convert("RGB")


def contact_sheet(out_dir, path):
    """Every deliverable at a glance, a Steam game-page mock-up (hero + logo), thumbnails at the sizes Steam
    shows them (1:1) and the small icon frames from icon.ico (1:1 and 4x nearest-neighbour)."""
    def img(name, mode="RGB"):
        with Image.open(os.path.join(out_dir, name)) as im:
            return im.convert(mode)
    portrait, landscape = img("grid_portrait_600x900.png"), img("grid_landscape_920x430.png")
    hero, icon512, icon256 = img("hero_1920x620.png"), img("icon_512.png"), img("icon_256.png")
    logo, logo_c, logo_w = img("logo.png", "RGBA"), img("logo_1280x720.png", "RGBA"), img("logo_wide.png", "RGBA")
    with Image.open(os.path.join(out_dir, "icon.ico")) as ico:
        frames = {s: ico.ico.getimage((s, s)).convert("RGB") for s in (16, 24, 32, 48, 64)}

    W, M = 2240, 40
    BG, FG, DIM = (23, 32, 44), (232, 236, 242), (140, 152, 170)
    f_title, f_lbl, f_sub = _font(34, True), _font(21, True), _font(17)
    rows = [100, 1086, 1782, 2280]       # label line of each row; images start 30 px below
    sheet = Image.new("RGB", (W, 2790), BG)
    d = ImageDraw.Draw(sheet)

    def label(x, y, text, sub=""):
        d.text((x, y), text, font=f_lbl, fill=FG)
        if sub:
            d.text((x + d.textlength(text, font=f_lbl) + 12, y + 3), sub, font=f_sub, fill=DIM)

    def fit(im, w, h):
        k = min(w / im.width, h / im.height)
        return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), LANCZOS)

    d.text((M, 26), "Crossing Europe – A Racing Xperience · Steam library artwork", font=f_title, fill=FG)
    d.text((M + 2, 70), "final set · composed by tools/steam/compose.py · all images at 1:1 unless noted",
           font=f_sub, fill=DIM)

    y = rows[0]
    label(M, y, "Grid portrait 600×900", "(+ 1200×1800)")
    sheet.paste(portrait, (M, y + 30))
    x2 = M + 600 + M
    label(x2, y, "Grid landscape 920×430", "(+ 1840×860)")
    sheet.paste(landscape, (x2, y + 30))
    yl = y + 30 + 430 + 26
    label(x2, yl, "logo_1280x720.png", "transparent canvas, shown at 50 % on checkerboard")
    sheet.paste(_over_pil(_checker(640, 360), logo_c.resize((640, 360), LANCZOS)), (x2, yl + 30))
    x3 = x2 + 920 + M
    label(x3, y, "Icon 512", "icon_512.png")
    sheet.paste(icon512, (x3, y + 30))
    label(x3, y + 30 + 512 + 26, "Icon 256", "icon_256.png")
    sheet.paste(icon256, (x3, y + 30 + 512 + 56))

    y = rows[1]
    label(M, y, "Hero 1920×620", "(+ 3840×1240) · no logo, no text · left ~45 % kept calm for Steam's logo overlay")
    sheet.paste(hero, (M, y + 30))

    y = rows[2]
    label(M, y, "Mock-up: Steam game page", "hero + logo.png in a bottom-left box of ~50 % × 50 % "
          "(approximation of Steam's default; adjustable in Steam)")
    mw, mh = 1280, 413
    mock = hero.resize((mw, mh), LANCZOS)
    lg = fit(logo, 0.5 * mw, 0.5 * mh)
    mock = _over_pil(mock, lg, (round(0.025 * mw), round(mh - 0.05 * mh) - lg.height))
    sheet.paste(mock, (M, y + 30))
    xl = M + mw + M
    pw = (W - xl - M - 20) // 2
    label(xl, y, "logo.png", "%d×%d, trimmed · on checkerboard / dark" % logo.size)
    lg = fit(logo, pw - 40, 400)
    ph = lg.height + 40
    sheet.paste(_over_pil(_checker(pw, ph), lg, ((pw - lg.width) // 2, 20)), (xl, y + 30))
    sheet.paste(_over_pil(Image.new("RGB", (pw, ph), (12, 8, 24)), lg, ((pw - lg.width) // 2, 20)),
                (xl + pw + 20, y + 30))
    yw = y + 30 + ph + 26
    label(xl, yw, "logo_wide.png", "%d×%d · alternative one-line logo" % logo_w.size)
    lg = fit(logo_w, 2 * pw + 20 - 40, 200)
    sheet.paste(_over_pil(Image.new("RGB", (2 * pw + 20, lg.height + 40), (12, 8, 24)), lg, (20, 20)),
                (xl, yw + 30))

    y = rows[3]
    label(M, y, "Steam-size thumbnails (1:1)", "portrait 300×450 and 150×225, landscape 230×107")
    sheet.paste(portrait.resize((300, 450), LANCZOS), (M, y + 30))
    sheet.paste(portrait.resize((150, 225), LANCZOS), (M + 320, y + 30))
    sheet.paste(landscape.resize((230, 107), LANCZOS), (M + 320, y + 30 + 245))
    xi = M + 320 + 230 + 60
    d.text((xi, y + 30), "icon.ico frames 16 / 24 / 32 / 48 / 64 at 1:1", font=f_sub, fill=DIM)
    x = xi
    for s in (16, 24, 32, 48, 64):
        sheet.paste(frames[s], (x, y + 60 + 64 - s))
        x += s + 24
    d.text((xi, y + 150), "the same, 4× nearest-neighbour", font=f_sub, fill=DIM)
    x = xi
    for s in (16, 24, 32, 48, 64):
        sheet.paste(frames[s].resize((4 * s, 4 * s), NEAREST), (x, y + 180 + 256 - 4 * s))
        x += 4 * s + 24
    sheet.save(path, compress_level=PNG_LEVEL)


if __name__ == "__main__":
    main()
