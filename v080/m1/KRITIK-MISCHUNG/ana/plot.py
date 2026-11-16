"""Tiny PIL chart helper (no matplotlib here): line charts with log or linear x, grid, legend, German captions."""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# colour-blind friendly categorical palette (Okabe-Ito) + greys
PAL = ["#000000", "#E69F00", "#56B4E9", "#009E73", "#D55E00", "#0072B2", "#CC79A7", "#999999", "#F0E442"]


def font(size: int, bold: bool = False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def _wrap(draw, text, fnt, width):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for w in words:
            t = (cur + " " + w).strip()
            if draw.textlength(t, font=fnt) <= width:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = w
        lines.append(cur)
    return lines


class Chart:
    def __init__(self, w=1400, h=760, title="", caption="", xlog=True, xr=(20, 20000), yr=(-40, 0), xlabel="",
                 ylabel="", xticks=None, yticks=None, xticklabels=None, legend_cols=1, cap_lines=3):
        self.W, self.H = w, h
        self.cap_h = 26 * cap_lines + 20 if caption else 10
        self.img = Image.new("RGB", (w, h + self.cap_h), "white")
        self.d = ImageDraw.Draw(self.img)
        self.L, self.R, self.T, self.B = 90, w - 30, 60, h - 70
        self.xlog, self.xr, self.yr = xlog, xr, yr
        self.d.text((self.L, 15), title, fill="black", font=font(24, True))
        # grid
        xt = xticks or ([20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000] if xlog else None)
        for i, x in enumerate(xt or []):
            px = self.px(x)
            self.d.line([(px, self.T), (px, self.B)], fill="#e3e3e3")
            lab = (xticklabels[i] if xticklabels else (f"{x/1000:g}k" if x >= 1000 else f"{x:g}"))
            tw = self.d.textlength(lab, font=font(16))
            self.d.text((px - tw / 2, self.B + 6), lab, fill="#333", font=font(16))
        yt = yticks or list(range(int(math.ceil(yr[0] / 5) * 5), int(yr[1]) + 1, 5))
        for y in yt:
            py = self.py(y)
            self.d.line([(self.L, py), (self.R, py)], fill="#e3e3e3")
            lab = f"{y:g}"
            tw = self.d.textlength(lab, font=font(16))
            self.d.text((self.L - tw - 8, py - 9), lab, fill="#333", font=font(16))
        self.d.rectangle([self.L, self.T, self.R, self.B], outline="#888")
        self.d.text((self.L + (self.R - self.L) / 2 - self.d.textlength(xlabel, font=font(18)) / 2, self.B + 32), xlabel,
                    fill="black", font=font(18))
        # y label rotated
        if ylabel:
            tmp = Image.new("RGBA", (int(self.d.textlength(ylabel, font=font(18))) + 4, 24), (255, 255, 255, 0))
            ImageDraw.Draw(tmp).text((0, 0), ylabel, fill="black", font=font(18))
            tmp = tmp.rotate(90, expand=True)
            self.img.paste(tmp, (12, int(self.T + (self.B - self.T) / 2 - tmp.size[1] / 2)), tmp)
        self.legend = []
        self.legend_cols = legend_cols
        if caption:
            yy = h + 6
            for ln in _wrap(self.d, caption, font(18), w - 60)[:cap_lines + 2]:
                self.d.text((30, yy), ln, fill="#222", font=font(18))
                yy += 26

    def px(self, x):
        if self.xlog:
            a, b = math.log10(self.xr[0]), math.log10(self.xr[1])
            v = (math.log10(max(x, 1e-9)) - a) / (b - a)
        else:
            v = (x - self.xr[0]) / (self.xr[1] - self.xr[0])
        return self.L + v * (self.R - self.L)

    def py(self, y):
        v = (y - self.yr[0]) / (self.yr[1] - self.yr[0])
        v = min(max(v, -0.02), 1.02)
        return self.B - v * (self.B - self.T)

    def line(self, xs, ys, color, label="", width=3, dash=False):
        pts = [(self.px(x), self.py(y)) for x, y in zip(xs, ys) if y is not None and not (isinstance(y, float) and math.isnan(y))]
        if len(pts) > 1:
            if dash:
                on, off = 14.0, 9.0
                carry, draw = 0.0, True
                for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
                    seg = math.hypot(x1 - x0, y1 - y0)
                    pos = 0.0
                    while pos < seg:
                        left = (on if draw else off) - carry
                        step = min(left, seg - pos)
                        if draw:
                            a, b = pos / seg, (pos + step) / seg
                            self.d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)],
                                        fill=color, width=width)
                        pos += step
                        carry += step
                        if carry >= (on if draw else off) - 1e-9:
                            carry, draw = 0.0, not draw
            else:
                self.d.line(pts, fill=color, width=width, joint="curve")
        if label:
            self.legend.append((label, color, dash))

    def hline(self, y, color="#555", label="", width=2):
        self.d.line([(self.L, self.py(y)), (self.R, self.py(y))], fill=color, width=width)
        if label:
            self.legend.append((label, color, False))

    def text(self, x, y, s, color="black", size=16):
        self.d.text((self.px(x), self.py(y)), s, fill=color, font=font(size))

    def bars(self, groups, series, colors, ymin=None):
        """groups: labels on x (linear 0..n), series: list of (label, values)."""
        n = len(groups)
        k = len(series)
        gw = (self.R - self.L) / n
        bw = gw * 0.8 / k
        y0 = self.py(ymin if ymin is not None else max(self.yr[0], 0))
        for gi, g in enumerate(groups):
            x0 = self.L + gi * gw + gw * 0.1
            for si, (lab, vals) in enumerate(series):
                v = vals[gi]
                if v is None:
                    continue
                y1 = self.py(v)
                self.d.rectangle([x0 + si * bw, min(y0, y1), x0 + (si + 1) * bw - 2, max(y0, y1)], fill=colors[si])
            tw = self.d.textlength(g, font=font(15))
            self.d.text((self.L + gi * gw + gw / 2 - tw / 2, self.B + 6), g, fill="#333", font=font(15))
        for si, (lab, _v) in enumerate(series):
            self.legend.append((lab, colors[si], False))

    def save(self, path, legend_pos="tr"):
        if self.legend:
            f = font(17)
            cols = self.legend_cols
            rows = int(math.ceil(len(self.legend) / cols))
            colw = max(self.d.textlength(l, font=f) for l, _c, _d in self.legend) + 60
            bw, bh = colw * cols + 10, rows * 26 + 12
            x0 = self.R - bw - 10 if legend_pos.endswith("r") else self.L + 10
            y0 = self.T + 10 if legend_pos.startswith("t") else self.B - bh - 10
            self.d.rectangle([x0, y0, x0 + bw, y0 + bh], fill="white", outline="#aaa")
            for i, (lab, col, dash) in enumerate(self.legend):
                c, r = i // rows, i % rows
                xx, yy = x0 + 8 + c * colw, y0 + 8 + r * 26
                if dash:
                    self.d.line([(xx, yy + 10), (xx + 12, yy + 10)], fill=col, width=4)
                    self.d.line([(xx + 22, yy + 10), (xx + 34, yy + 10)], fill=col, width=4)
                else:
                    self.d.line([(xx, yy + 10), (xx + 34, yy + 10)], fill=col, width=5)
                self.d.text((xx + 42, yy), lab, fill="black", font=f)
        self.img.save(path, optimize=True)
