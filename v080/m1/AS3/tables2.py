"""AS3 scratch: markdown tables for the report – overdraw at 20 m and outlines.
   python3 tables2.py overdraw | umriss"""
import os
import re
import sys

S = os.path.dirname(os.path.abspath(__file__))


def overdraw():
    px = {}
    for line in open(os.path.join(S, "logs", "f_d20.txt")):
        if line.startswith("STUFEN"):
            name = line.split()[1]
            m = re.search(r'lod0@20m rgb\(\d+,\d+,\d+\) (\d+) px', line)
            if m:
                px[name] = int(m.group(1))
    print("| Modell | Kuppeln/Karten lod0 | Laub-Dreiecke lod0 | Laubfläche (px, Summe) | gedeckte Pixel | Überzeichnung |")
    print("|---|---|---|---|---|---|")
    for line in open(os.path.join(S, "logs", "f_overdraw20.txt")):
        if not line.startswith("UEBERZEICHNUNG"):
            continue
        m = re.match(r'UEBERZEICHNUNG (\S+) @(\d+) m Kuppeln/Karten (\d+) Dreiecke leaves (\d+) Bildfläche (\d+) px', line)
        if not m:
            continue
        name, cards, tris, area = m.group(1), int(m.group(3)), int(m.group(4)), int(m.group(5))
        cov = px.get(name, 0)
        od = "%.1f×" % (area / cov) if cov else "–"
        print("| %s | %d | %d | %s | %s | %s |" % (name.split("/")[1], cards, tris, format(area, ",").replace(",", " "),
                                                format(cov, ",").replace(",", " "), od))


def umriss():
    print("| Modell | Modell außerhalb des Sprite-Umrisses | Sprite vom Modell gedeckt |")
    print("|---|---|---|")
    for line in open(os.path.join(S, "logs", "f_umrisse.txt")):
        m = re.match(r'(\S+)\s+Modell außerhalb des Sprite-Umrisses\s+([\d.]+) %, Sprite vom Modell gedeckt\s+([\d.]+) %', line)
        if m:
            print("| %s | %s %% | %s %% |" % (m.group(1).split("/")[1], m.group(2), m.group(3)))


{"overdraw": overdraw, "umriss": umriss}[sys.argv[1]]()
