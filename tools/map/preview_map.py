#!/usr/bin/env python3
"""Renders a preview PNG of data/map/europe_map.json with all cities and stages (needs Pillow).

    python3 tools/map/preview_map.py <out.png> [--scale=1.5] [--race=koenigsrennen]

Stages are drawn as straight lines between the cities (as the stage screen does). With --race the shortest
route is red and the alternatives orange (routing replayed with tools/map/build_network.py); dev cities/stages
are skipped.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def main():
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	out = sys.argv[1]
	opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
	scale = float(opts.get("scale", 1.5))
	race = opts.get("race", "")
	with open(os.path.join(ROOT, "data", "map", "europe_map.json"), encoding="utf-8") as f:
		m = json.load(f)
	with open(os.path.join(ROOT, "data", "network.json"), encoding="utf-8") as f:
		net = json.load(f)
	w, h = m["size"]
	img = Image.new("RGB", (int(w * scale), int(h * scale)), (170, 200, 225))
	d = ImageDraw.Draw(img)
	stage_countries = {s["country"] for st in net["stages"] if not st.get("dev") for s in st["sections"]}
	for c in m["countries"]:
		fill = (236, 228, 204) if c["code"] in stage_countries else (214, 214, 206)
		for poly in c["polygons"]:
			pts = [(x * scale, y * scale) for x, y in poly]
			d.polygon(pts, fill=fill, outline=(120, 120, 120))
	cities = {c["id"]: c for c in net["cities"] if not c.get("dev")}
	best, alt = set(), set()
	if race:
		sys.path.insert(0, HERE)
		import build_network as bn  # same routing rules as GameData.next_options
		r = next((r for r in net["races"] if r["id"] == race), None)
		if r:
			routes, _choices = bn.race_routes(bn.build_graph(net["stages"], net.get("ferries", [])), r)
			for i, (_km, _cs, legs) in enumerate(routes):
				(best if i == 0 else alt).update(l[1] for l in legs)
	for st in net["stages"]:
		if st.get("dev"):
			continue
		a, b = cities[st["from"]]["map_pos"], cities[st["to"]]["map_pos"]
		col = (200, 40, 40) if st["id"] in best else (235, 140, 20) if st["id"] in alt else (60, 90, 170)
		width = max(2, int((3 if st["id"] in best or st["id"] in alt else 2) * scale))
		d.line([(a[0] * scale, a[1] * scale), (b[0] * scale, b[1] * scale)], fill=col, width=width)
	for f in net.get("ferries", []):
		a, b = cities[f["from"]]["map_pos"], cities[f["to"]]["map_pos"]
		n = 24
		for i in range(0, n, 2):
			p = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
			q = (a[0] + (b[0] - a[0]) * (i + 1) / n, a[1] + (b[1] - a[1]) * (i + 1) / n)
			d.line([(p[0] * scale, p[1] * scale), (q[0] * scale, q[1] * scale)], fill=(20, 110, 150), width=2)
	try:
		font = ImageFont.truetype("DejaVuSans.ttf", int(10 * scale))
	except OSError:
		font = ImageFont.load_default()
	for c in cities.values():
		x, y = c["map_pos"][0] * scale, c["map_pos"][1] * scale
		r = 3 * scale
		d.ellipse([x - r, y - r, x + r, y + r], fill=(20, 20, 20))
		d.text((x + r + 2, y - r - 2), c["name"], fill=(10, 10, 10), font=font)
	img.save(out)
	print("Vorschau gespeichert:", out)


if __name__ == "__main__":
	main()
