"""KRITIK-FAHRBAHN: small static charts with PIL (no matplotlib here). Palette and chrome: the dataviz reference
palette (light mode), categorical slots in fixed order, 2-px lines, hairline grid, legend for >= 2 series."""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageFont

S = 2  # supersampling
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK2 = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
SLOTS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
SHADE = "#f0efec"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def _font(px, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, int(px * S))


def de_num(v, nd=0):
    s = f"{v:.{nd}f}"
    return s.replace(".", ",").replace("-", "−")


def freq_label(f):
    if f >= 1000:
        k = f / 1000.0
        return (de_num(k, 0) if abs(k - round(k)) < 1e-6 else de_num(k, 1)) + " k"
    return de_num(f, 0) if abs(f - round(f)) < 1e-6 else de_num(f, 1)


class Chart:
    def __init__(self, w=1400, h=820, title="", subtitle="", left=90, right=260, top=96, bottom=96):
        self.w, self.h = w, h
        self.img = Image.new("RGB", (w * S, h * S), SURFACE)
        self.d = ImageDraw.Draw(self.img)
        self.x0, self.y0 = left, top
        self.x1, self.y1 = w - right, h - bottom
        if title:
            self.d.text((24 * S, 18 * S), title, font=_font(19, True), fill=INK)
        if subtitle:
            self.d.text((24 * S, 48 * S), subtitle, font=_font(13.5), fill=INK2)

    # --- scales
    def axes(self, xlim, ylim, xlog=False, xticks=None, yticks=None, xlabel="", ylabel="", xfmt=None, yfmt=None):
        self.xlim, self.ylim, self.xlog = xlim, ylim, xlog
        d = self.d
        for yt in (yticks or []):
            y = self.py(yt)
            d.line([(self.x0 * S, y), (self.x1 * S, y)], fill=GRID, width=1 * S)
            d.text((self.x0 * S - 10 * S, y), (yfmt or (lambda v: de_num(v, 0)))(yt), font=_font(12), fill=MUTED, anchor="rm")
        for xt in (xticks or []):
            x = self.px(xt)
            d.line([(x, self.y0 * S), (x, self.y1 * S)], fill=GRID, width=1 * S)
            d.text((x, self.y1 * S + 10 * S), (xfmt or (lambda v: de_num(v, 0)))(xt), font=_font(12), fill=MUTED, anchor="mt")
        d.line([(self.x0 * S, self.y1 * S), (self.x1 * S, self.y1 * S)], fill=AXIS, width=1 * S)
        d.line([(self.x0 * S, self.y0 * S), (self.x0 * S, self.y1 * S)], fill=AXIS, width=1 * S)
        if xlabel:
            d.text(((self.x0 + self.x1) / 2 * S, (self.y1 + 38) * S), xlabel, font=_font(12.5), fill=INK2, anchor="mt")
        if ylabel:
            d.text((self.x0 * S, (self.y0 - 14) * S), ylabel, font=_font(12.5), fill=INK2, anchor="lb")

    def px(self, v):
        a, b = self.xlim
        if self.xlog:
            t = (math.log10(max(v, 1e-9)) - math.log10(a)) / (math.log10(b) - math.log10(a))
        else:
            t = (v - a) / (b - a)
        return (self.x0 + t * (self.x1 - self.x0)) * S

    def py(self, v):
        a, b = self.ylim
        t = (v - a) / (b - a)
        return (self.y1 - t * (self.y1 - self.y0)) * S

    def clip_y(self, v):
        return max(self.ylim[0], min(self.ylim[1], v))

    def shade_x(self, a, b, label=""):
        xa, xb = self.px(max(a, self.xlim[0])), self.px(min(b, self.xlim[1]))
        self.d.rectangle([xa, self.y0 * S, xb, self.y1 * S], fill=SHADE)
        if label:
            self.d.text((xa + 6 * S, self.y0 * S + 6 * S), label, font=_font(11.5), fill=INK2)

    def hline(self, v, label="", dash=True):
        y = self.py(v)
        x = self.x0 * S
        while x < self.x1 * S:
            self.d.line([(x, y), (min(x + 8 * S, self.x1 * S), y)], fill=INK2, width=1 * S)
            x += 14 * S if dash else 8 * S
        if label:
            self.d.text((self.x1 * S - 4 * S, y - 4 * S), label, font=_font(11.5), fill=INK2, anchor="rb")

    def vline(self, v, label=""):
        x = self.px(v)
        y = self.y0 * S
        while y < self.y1 * S:
            self.d.line([(x, y), (x, min(y + 8 * S, self.y1 * S))], fill=INK2, width=1 * S)
            y += 14 * S
        if label:
            self.d.text((x + 4 * S, self.y0 * S + 4 * S), label, font=_font(11.5), fill=INK2, anchor="lt")

    def line(self, xs, ys, slot, width=2, markers=False):
        col = SLOTS[slot % len(SLOTS)]
        pts = [(self.px(x), self.py(self.clip_y(y))) for x, y in zip(xs, ys)]
        if len(pts) > 1:
            self.d.line(pts, fill=col, width=width * S, joint="curve")
        if markers:
            r = 4 * S
            for p in pts:
                self.d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col, outline=SURFACE, width=2 * S)

    def legend(self, items, x=None, y=None):
        """items: [(slot, label)] – placed in the right margin."""
        x = (self.x1 + 18) * S if x is None else x * S
        y = self.y0 * S if y is None else y * S
        for slot, label in items:
            col = SLOTS[slot % len(SLOTS)]
            self.d.line([(x, y + 9 * S), (x + 22 * S, y + 9 * S)], fill=col, width=3 * S)
            lines = label.split("\n")
            for j, ln in enumerate(lines):
                self.d.text((x + 30 * S, y + j * 16 * S), ln, font=_font(12), fill=INK, anchor="lt")
            y += (16 * len(lines) + 10) * S

    def note(self, text, x=None, y=None):
        x = 24 if x is None else x
        y = self.h - 30 if y is None else y
        self.d.text((x * S, y * S), text, font=_font(11.5), fill=INK2)

    def save(self, path):
        self.img.resize((self.w, self.h), Image.LANCZOS).save(path, optimize=True)


def hbar_chart(path, title, subtitle, rows, series_labels, xlim, xticks, xlabel, note="", w=1400, row_h=34, left=330):
    """Horizontal grouped bars: rows = [(label, [v_series0, v_series1, ...])]; values may be negative (bars from 0)."""
    n_s = len(series_labels)
    h = 120 + len(rows) * (row_h * n_s + 14) + 90
    c = Chart(w, h + 30, title, subtitle, left=left, right=260, top=100, bottom=100)
    c.axes(xlim, (0, 1), False, xticks, [], xlabel, "", xfmt=lambda v: de_num(v, 0))
    y = c.y0 + 10
    for label, vals in rows:
        c.d.text(((c.x0 - 12) * S, (y + row_h * n_s / 2) * S), label, font=_font(12.5), fill=INK, anchor="rm")
        for k, v in enumerate(vals):
            if v is None:
                continue
            col = SLOTS[k % len(SLOTS)]
            xa, xb = sorted([c.px(0), c.px(max(xlim[0], min(xlim[1], v)))])
            c.d.rounded_rectangle([xa, (y + k * row_h + 4) * S, max(xb, xa + 2 * S), (y + (k + 1) * row_h - 4) * S], radius=4 * S, fill=col)
            tx = xb + 6 * S if v >= 0 else xa - 6 * S
            c.d.text((tx, (y + k * row_h + row_h / 2) * S), de_num(v, 1), font=_font(11.5), fill=INK2, anchor="lm" if v >= 0 else "rm")
        y += row_h * n_s + 14
    if n_s >= 2:
        c.legend([(k, s) for k, s in enumerate(series_labels)])
    if note:
        c.note(note)
    c.save(path)
