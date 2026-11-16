"""Review pictures for AU-A (static PNG, light surface): the loudness plan measured, and the equaliser finding.

Colours: the validated default palette of the chart guidance (blue / orange / aqua categorical, two blue steps for
before -> after), text in ink tokens, hairline grid. Drawn 3x and scaled down for smooth lines.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A"
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-A"
S = 3
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK2 = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
BLUE = "#2a78d6"
BLUE_LIGHT = "#86b6ef"
ORANGE = "#eb6834"
AQUA = "#1baf7a"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(px, bold=False):
    return ImageFont.truetype(SANS_BOLD if bold else SANS, int(px * S))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGB", (w * S, h * S), SURFACE)
        self.d = ImageDraw.Draw(self.img)

    def line(self, pts, fill, width=1.0):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill, width=max(1, int(round(width * S))), joint="curve")

    def dot(self, x, y, r, fill, ring=2.0):
        if ring > 0:
            rr = r + ring
            self.d.ellipse([(x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S], fill=SURFACE)
        self.d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=fill)

    def rect(self, x0, y0, x1, y1, fill):
        self.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill)

    def text(self, x, y, s, px=13, fill=INK2, anchor="la", bold=False):
        self.d.text((x * S, y * S), s, font=font(px, bold), fill=fill, anchor=anchor)

    def text_w(self, s, px=13, bold=False):
        return self.d.textlength(s, font=font(px, bold)) / S

    def save(self, path):
        self.img.resize((self.w, self.h), Image.LANCZOS).save(path, optimize=True)
        print("geschrieben:", path)


def de(v, digits=1):
    return ("%.*f" % (digits, v)).replace(".", ",").replace("-", "−")


# --- 1. loudness per phase ------------------------------------------------------------------------------------------

def chart_loudness():
    data = json.load(open(os.path.join(W, "mix", "pegelplan_messung.json"), encoding="utf-8"))
    by = {}
    for rec in data if isinstance(data, list) else data.get("files", data.get("captures", [])):
        key = (rec.get("profile"), rec.get("scenario"))
        by[key] = {p["name"]: p for p in rec["phases"]}
    rows = [("Leerlauf", "idle", -24.0), ("Vollgas durch die Gänge", "full_throttle", -16.0),
            ("Höchsttempo", "flat_out", -16.0), ("130 km/h", "cruise_130", -21.0)]
    c = Canvas(1200, 470)
    c.text(40, 30, "Lautheit je Fahrabschnitt: Arcade, Modern und das Ziel des Pegelplans", 19, INK, bold=True)
    c.text(40, 60, "Gran Turismo, feste Fahrt, Standardregler · Aufnahme des Master-Busses, Lautheit nach BS.1770 (gemessen) · "
           "Modern spielt hier noch die Arcade-Bank über die neuen Busse", 12.5, INK2)
    # legend
    lx, ly = 40, 96
    c.dot(lx + 6, ly, 6, BLUE_LIGHT, 0)
    c.text(lx + 20, ly, "Arcade (v0.7.0)", 13, INK2, "lm")
    lx += 20 + c.text_w("Arcade (v0.7.0)", 13) + 28
    c.dot(lx + 6, ly, 6, BLUE, 0)
    c.text(lx + 20, ly, "Modern, Platzhalter-Bausteine", 13, INK2, "lm")
    lx += 20 + c.text_w("Modern, Platzhalter-Bausteine", 13) + 28
    c.rect(lx + 4, ly - 9, lx + 7, ly + 9, INK2)
    c.text(lx + 20, ly, "Ziel des Pegelplans", 13, INK2, "lm")
    x0, x1 = 250, 1150
    lo, hi = -26.0, -12.0
    top, row_h = 140, 62

    def X(v):
        return x0 + (v - lo) / (hi - lo) * (x1 - x0)

    bottom = top + row_h * len(rows)
    for v in range(int(lo), int(hi) + 1, 2):
        c.line([(X(v), top - 6), (X(v), bottom - 10)], GRID, 1)
        c.text(X(v), bottom + 4, de(v, 0), 12, MUTED, "ma")
    c.text(x1, bottom + 26, "LUFS (lauter →)", 12, MUTED, "ra")
    for i, (label, key, plan) in enumerate(rows):
        y = top + row_h * i + row_h * 0.38
        a = float(by[("arcade", "drive")][key]["lufs"])
        m = float(by[("modern", "drive")][key]["lufs"])
        c.text(40, y, label, 14, INK, "lm")
        c.line([(X(a), y), (X(m), y)], AXIS, 2)
        c.rect(X(plan) - 1.5, y - 13, X(plan) + 1.5, y + 13, INK2)
        c.dot(X(a), y, 6, BLUE_LIGHT)
        c.dot(X(m), y, 6, BLUE)
        txt = de(m)
        # the value of Modern beside its dot, on the side away from the connector and the plan tick
        side = -1 if m < a else 1
        if abs(X(plan) - (X(m) + side * 12)) < 44 and (X(plan) - X(m)) * side > 0:
            c.text(X(m), y - 24, txt, 13, INK, "mm", bold=True)
        else:
            c.text(X(m) + side * 13, y, txt, 13, INK, "rm" if side < 0 else "lm", bold=True)
    c.text(40, bottom + 52, "Vollgas trifft das Ziel (audio.modern.levels.MSfx = −3 dB). Leerlauf und Reisetempo folgen dem "
           "Lautstärkeverhältnis der Arcade-Bank – das stellt der Motor v3 (AU-B) ein.", 12.5, INK2)
    c.save(os.path.join(OUT, "pegelplan_arcade_modern.png"))


# --- 2. equaliser response ------------------------------------------------------------------------------------------

def response(name):
    d = os.path.join(W, "probe", "ir_chart")
    n = 1 << 17
    ref = np.abs(np.fft.rfft(np.fromfile(os.path.join(d, "none.f32"), dtype="<f4").astype(np.float64), n))
    mag = np.abs(np.fft.rfft(np.fromfile(os.path.join(d, name + ".f32"), dtype="<f4").astype(np.float64), n))
    db = 20.0 * np.log10(np.maximum(mag, 1e-12) / np.maximum(ref, 1e-12))
    freqs = np.geomspace(20.0, 20000.0, 700)
    return freqs, np.interp(freqs, np.arange(db.size) * 44100.0 / n, db)


def chart_eq():
    c = Canvas(1200, 600)
    c.text(40, 30, "Renn-EQ der Musik: Godots Band-Equalizer ist nicht neutral", 19, INK, bold=True)
    c.text(40, 60, "Verstärkung über der Frequenz, aus Impulsantworten gemessen (Godot 4.7.2, Bus mit 44,1 kHz)", 12.5, INK2)
    series = [("shelves", BLUE, "Renn-EQ jetzt: zwei Kuhschwanzfilter"),
              ("eq10_flat", ORANGE, "AudioEffectEQ10, alle Bänder auf 0 dB"),
              ("eq10_old", AQUA, "AudioEffectEQ10 mit 62 Hz −1 dB, 500 Hz −3 dB (Renn-EQ bisher)")]
    lx, ly = 40, 96
    for _name, col, label in series:
        c.line([(lx, ly), (lx + 22, ly)], col, 2.5)
        c.text(lx + 30, ly, label, 13, INK2, "lm")
        lx += 30 + c.text_w(label, 13) + 26
    assert lx - 26 <= 1160, lx
    x0, x1, y0, y1 = 80, 1150, 130, 520
    lo, hi = -4.0, 4.0

    def X(f):
        return x0 + (math.log10(f) - math.log10(20.0)) / (math.log10(20000.0) - math.log10(20.0)) * (x1 - x0)

    def Y(v):
        return y1 - (v - lo) / (hi - lo) * (y1 - y0)

    for v in range(int(lo), int(hi) + 1):
        c.line([(x0, Y(v)), (x1, Y(v))], AXIS if v == 0 else GRID, 1)
        c.text(x0 - 10, Y(v), ("+" if v > 0 else "") + de(v, 0), 12, MUTED, "rm")
    c.text(x0 - 10, y0 - 22, "dB", 12, MUTED, "rm")
    for f, label in [(31, "31"), (62, "62"), (125, "125"), (250, "250"), (500, "500"), (1000, "1 k"), (2000, "2 k"),
                     (4000, "4 k"), (8000, "8 k"), (16000, "16 k")]:
        c.line([(X(f), y1), (X(f), y1 + 5)], AXIS, 1)
        c.text(X(f), y1 + 10, label, 12, MUTED, "ma")
    c.text(x1, y1 + 34, "Hz (die Mittenfrequenzen der zehn Bänder)", 12, MUTED, "ra")
    curves = {}
    for name, col, _label in reversed(series):
        freqs, db = response(name)
        curves[name] = (freqs, db)
        c.line([(X(f), Y(max(lo, min(hi, v)))) for f, v in zip(freqs, db)], col, 2)

    def at(name, hz):
        freqs, db = curves[name]
        return float(db[int(np.argmin(np.abs(freqs - hz)))])

    # selective direct labels: one statement per line
    v = at("eq10_flat", 62.0)
    c.dot(X(62), Y(v), 4, ORANGE)
    c.text(X(62) + 2, Y(v) - 16, "+" + de(v) + " dB statt 0 dB", 13, INK, "mm", bold=True)
    v = at("eq10_old", 500.0)
    c.line([(X(500), Y(v) + 8), (X(500), Y(0.0) + 12)], AXIS, 1)
    c.dot(X(500), Y(v), 4, AQUA)
    c.text(X(500), Y(0.0) + 24, "+" + de(v) + " dB – gewollt waren −3 dB", 13, INK, "mm", bold=True)
    v = at("shelves", 500.0)
    c.dot(X(500), Y(v), 4, BLUE)
    c.text(X(500), Y(v) + 20, de(v) + " dB bei 500 Hz", 13, INK, "mm", bold=True)
    c.text(X(6000), Y(0.0) + 18, "0 dB ab 4 kHz", 13, INK, "mm", bold=True)
    c.text(40, 572, "Der EQ10 summiert Bandpässe: neutral gestellt hebt er um 1,4 bis 3,3 dB an – die Musik lag im Rennen "
           "2 dB über dem Plan. Kuhschwanzfilter sind außerhalb ihrer Stufe exakt 0 dB.", 12.5, INK2)
    c.save(os.path.join(OUT, "renn_eq_frequenzgang.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["loudness", "eq"]
    if "loudness" in which:
        chart_loudness()
    if "eq" in which:
        chart_eq()
