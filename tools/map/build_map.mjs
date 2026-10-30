#!/usr/bin/env node
// Builds data/map/europe_map.json (ARCHITECTURE.md §4.5) and writes "map_pos" of every city into
// data/network.json – both with the same projection.
//
// Data: Natural Earth 1:50m Admin-0 countries (public domain) via npm "world-atlas" (ISC licence).
// Projection: Lambert azimuthal equal-area (sphere), centred at 15°E / 52°N, fitted to all cities + margin.
//
// Usage (packages are installed OUTSIDE the repository, never commit node_modules):
//   cp tools/map/package.json /tmp/maptools/ && npm install --prefix /tmp/maptools
//   MAP_NODE_MODULES=/tmp/maptools/node_modules node tools/map/build_map.mjs [--width=1000] [--margin-km=170]
//       [--min-area=1.5]
//   python3 tools/map/build_network.py keeps the map_pos values written here.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");
const NETWORK = path.join(ROOT, "data", "network.json");
const OUT = path.join(ROOT, "data", "map", "europe_map.json");

const args = Object.fromEntries(process.argv.slice(2).filter(a => a.startsWith("--")).map(a => {
	const [k, v] = a.slice(2).split("=");
	return [k, v === undefined ? true : v];
}));
const WIDTH = Number(args.width ?? 1000);
const MARGIN_KM = Number(args["margin-km"] ?? 170);
const MIN_AREA_PX = Number(args["min-area"] ?? 1.5);   // simplification: min. triangle area in px²
const MIN_RING_AREA_PX = 4.0;                          // drop islands smaller than this (px²)
const CENTER = [15, 52];
const EARTH_RADIUS_KM = 6371.0088;

const modulesDir = process.env.MAP_NODE_MODULES || path.join(HERE, "node_modules");
const req = createRequire(path.join(modulesDir, "_resolve.js"));
const load = async name => import(pathToFileURL(req.resolve(name)).href);
const d3 = await load("d3-geo");
const { geoProject } = await load("d3-geo-projection");
const topojson = await load("topojson-client");
const simplify = await load("topojson-simplify");
const worldPath = path.join(modulesDir, "world-atlas", "countries-50m.json");
const world = JSON.parse(fs.readFileSync(worldPath, "utf8"));
const atlasVersion = JSON.parse(fs.readFileSync(path.join(modulesDir, "world-atlas", "package.json"), "utf8")).version;

// ISO 3166-1 numeric -> alpha-2 (Europe and neighbours; world-atlas only carries numeric ids)
const ISO = {
	"008": "AL", "020": "AD", "040": "AT", "056": "BE", "070": "BA", "100": "BG", "112": "BY", "191": "HR",
	"196": "CY", "203": "CZ", "208": "DK", "233": "EE", "234": "FO", "246": "FI", "248": "AX", "250": "FR",
	"276": "DE", "292": "GI", "300": "GR", "348": "HU", "352": "IS", "372": "IE", "380": "IT", "428": "LV",
	"438": "LI", "440": "LT", "442": "LU", "470": "MT", "492": "MC", "498": "MD", "499": "ME", "528": "NL",
	"807": "MK", "578": "NO", "616": "PL", "620": "PT", "642": "RO", "643": "RU", "674": "SM", "688": "RS",
	"703": "SK", "705": "SI", "724": "ES", "752": "SE", "756": "CH", "792": "TR", "804": "UA", "826": "GB",
	"336": "VA", "831": "GG", "832": "JE", "833": "IM", "012": "DZ", "504": "MA", "788": "TN", "434": "LY",
	"818": "EG", "376": "IL", "422": "LB", "760": "SY", "368": "IQ", "364": "IR", "400": "JO", "268": "GE",
	"051": "AM", "031": "AZ", "398": "KZ", "275": "PS", "682": "SA",
};
const ISO_BY_NAME = { "Kosovo": "XK", "N. Cyprus": "CY" };
// German names for labels (countries without an entry keep the English Natural Earth name)
const NAME_DE = {
	AD: "Andorra", AL: "Albanien", AT: "Österreich", BA: "Bosnien und Herzegowina", BE: "Belgien", BG: "Bulgarien",
	BY: "Belarus", CH: "Schweiz", CY: "Zypern", CZ: "Tschechien", DE: "Deutschland", DK: "Dänemark", DZ: "Algerien",
	EE: "Estland", ES: "Spanien", FI: "Finnland", FR: "Frankreich", GB: "Vereinigtes Königreich", GG: "Guernsey",
	GR: "Griechenland", HR: "Kroatien", HU: "Ungarn", IE: "Irland", IM: "Isle of Man", IT: "Italien", JE: "Jersey",
	LI: "Liechtenstein", LT: "Litauen", LU: "Luxemburg", LV: "Lettland", MA: "Marokko", MC: "Monaco", MD: "Moldau",
	ME: "Montenegro", MK: "Nordmazedonien", MT: "Malta", NL: "Niederlande", NO: "Norwegen", PL: "Polen",
	PT: "Portugal", RO: "Rumänien", RS: "Serbien", RU: "Russland", SE: "Schweden", SI: "Slowenien", SK: "Slowakei",
	SM: "San Marino", TN: "Tunesien", TR: "Türkei", UA: "Ukraine", VA: "Vatikanstadt", XK: "Kosovo",
};

// ---- projection fitted to the cities -------------------------------------------------------------
const netText = fs.readFileSync(NETWORK, "utf8");
const network = JSON.parse(netText);
const cities = network.cities.filter(c => Array.isArray(c.latlon));
const unit = d3.geoAzimuthalEqualArea().rotate([-CENTER[0], -CENTER[1]]).scale(1).translate([0, 0]);
let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
for (const c of cities) {
	const [x, y] = unit([c.latlon[1], c.latlon[0]]);
	x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
}
const mu = MARGIN_KM / EARTH_RADIUS_KM;
const scale = WIDTH / (x1 - x0 + 2 * mu);
const HEIGHT = Math.round((y1 - y0 + 2 * mu) * scale);
const translate = [-(x0 - mu) * scale, -(y0 - mu) * scale];
const projection = d3.geoAzimuthalEqualArea().rotate([-CENTER[0], -CENTER[1]]).scale(scale).translate(translate)
	.clipExtent([[0, 0], [WIDTH, HEIGHT]]).precision(0.2);

// Same formula as GameData.project_latlon() (scripts/data/road_network.gd) – self-check against d3.
function laea(lat, lon) {
	const rad = Math.PI / 180, l0 = CENTER[0] * rad, p1 = CENTER[1] * rad, l = lon * rad, p = lat * rad;
	const k = Math.sqrt(2 / (1 + Math.sin(p1) * Math.sin(p) + Math.cos(p1) * Math.cos(p) * Math.cos(l - l0)));
	const xr = k * Math.cos(p) * Math.sin(l - l0);
	const yr = k * (Math.cos(p1) * Math.sin(p) - Math.sin(p1) * Math.cos(p) * Math.cos(l - l0));
	return [translate[0] + scale * xr, translate[1] - scale * yr];
}
const round1 = v => Math.round(v * 10) / 10;
const positions = {};
for (const c of cities) {
	const a = projection([c.latlon[1], c.latlon[0]]);
	const b = laea(c.latlon[0], c.latlon[1]);
	if (Math.hypot(a[0] - b[0], a[1] - b[1]) > 0.01) throw new Error(`projection mismatch for ${c.id}`);
	positions[c.id] = [round1(a[0]), round1(a[1])];
}

// ---- countries ------------------------------------------------------------------------------------
let topo = simplify.presimplify(world, simplify.sphericalTriangleArea);
topo = simplify.simplify(topo, MIN_AREA_PX / (scale * scale));   // equal-area: px² = sr * scale²
const features = topojson.feature(topo, topo.objects.countries).features;

function ringArea(r) {
	let a = 0;
	for (let i = 0, n = r.length; i < n; i++) {
		const [xa, ya] = r[i], [xb, yb] = r[(i + 1) % n];
		a += xa * yb - xb * ya;
	}
	return a / 2;
}
// Area centroid of a ring (label anchor), clamped into the map.
function centroid(r) {
	let a = 0, cx = 0, cy = 0;
	for (let i = 0, n = r.length; i < n; i++) {
		const [xa, ya] = r[i], [xb, yb] = r[(i + 1) % n];
		const f = xa * yb - xb * ya;
		a += f; cx += (xa + xb) * f; cy += (ya + yb) * f;
	}
	if (Math.abs(a) < 1e-9) return r[0];
	return [round1(Math.min(Math.max(cx / (3 * a), 0), WIDTH)), round1(Math.min(Math.max(cy / (3 * a), 0), HEIGHT))];
}
function cleanRing(ring) {
	const out = [];
	for (const [x, y] of ring) {
		const p = [round1(x), round1(y)];
		const last = out[out.length - 1];
		if (!last || last[0] !== p[0] || last[1] !== p[1]) out.push(p);
	}
	if (out.length > 1) {
		const [f, l] = [out[0], out[out.length - 1]];
		if (f[0] === l[0] && f[1] === l[1]) out.pop();
	}
	if (out.length < 3 || Math.abs(ringArea(out)) < MIN_RING_AREA_PX) return null;
	if (ringArea(out) < 0) out.reverse();   // consistent winding: clockwise on screen (y down)
	return out;
}

const countries = [];
let points = 0;
for (const f of features) {
	const projected = geoProject(f, projection);
	const g = projected && projected.geometry;
	if (!g) continue;
	const polys = g.type === "Polygon" ? [g.coordinates] : g.type === "MultiPolygon" ? g.coordinates : [];
	const rings = [];
	for (const poly of polys) {
		const r = poly.length ? cleanRing(poly[0]) : null;   // outer rings only (holes are tiny enclaves)
		if (r) rings.push(r);
	}
	if (!rings.length) continue;
	const code = ISO[f.id] || ISO_BY_NAME[f.properties.name] || "";
	if (!code) console.warn(`kein ISO-Code für ${f.id} ${f.properties.name}`);
	rings.sort((a, b) => Math.abs(ringArea(b)) - Math.abs(ringArea(a)));
	points += rings.reduce((n, r) => n + r.length, 0);
	countries.push({ code, name: NAME_DE[code] || f.properties.name, name_en: f.properties.name, label: centroid(rings[0]), polygons: rings });
}
countries.sort((a, b) => a.code.localeCompare(b.code));

// ---- write ----------------------------------------------------------------------------------------
const header = {
	_doc: "Europakarte für Etappenbildschirm und Routenwahl. Koordinaten in Pixeln (x nach rechts, y nach unten) im " +
		"selben Raum wie cities[].map_pos in data/network.json. Nur Außenringe, im Uhrzeigersinn (Bildschirm), an " +
		"den Kartenrand geschnitten; label = Schwerpunkt des größten Polygons (für Ländernamen). Erzeugt mit " +
		"tools/map/build_map.mjs.",
	version: 1,
	size: [WIDTH, HEIGHT],
	projection: "Lambertsche flächentreue Azimutalprojektion (Kugel), Zentrum 15° O / 52° N",
	projection_params: {
		type: "azimuthal_equal_area", center_lonlat: CENTER, scale: Math.round(scale * 1000) / 1000,
		translate: translate.map(v => Math.round(v * 1000) / 1000), earth_radius_km: EARTH_RADIUS_KM,
		km_per_px: Math.round(EARTH_RADIUS_KM / scale * 10000) / 10000,
		formula: "k = sqrt(2 / (1 + sin(p1) sin(p) + cos(p1) cos(p) cos(l - l0))); x = tx + scale * k cos(p) sin(l - l0); " +
			"y = ty - scale * k (cos(p1) sin(p) - sin(p1) cos(p) cos(l - l0))  (l/p = Länge/Breite, l0/p1 = Zentrum)",
	},
	source: `Natural Earth 1:50m Admin 0 – Countries (gemeinfrei, naturalearthdata.com) über npm world-atlas ${atlasVersion} (ISC-Lizenz, Mike Bostock)`,
};
const lines = ["{"];
for (const [k, v] of Object.entries(header)) lines.push(`\t${JSON.stringify(k)}: ${JSON.stringify(v)},`);
lines.push('\t"countries": [');
lines.push(countries.map(c => "\t\t" + JSON.stringify(c)).join(",\n"));
lines.push("\t]");
lines.push("}");
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, lines.join("\n") + "\n");
const size = fs.statSync(OUT).size;
console.log(`${path.relative(ROOT, OUT)}: ${WIDTH}x${HEIGHT} px, ${countries.length} Länder, ${points} Punkte, ` +
	`${(size / 1024).toFixed(0)} KiB, Maßstab ${(EARTH_RADIUS_KM / scale).toFixed(3)} km/px`);
if (size > 1.5 * 1024 * 1024) throw new Error("Karte größer als 1,5 MB – --min-area erhöhen");

// ---- map_pos in network.json (in place, one city per line) -----------------------------------------
let text = netText;
let updated = 0;
for (const [id, pos] of Object.entries(positions)) {
	const re = new RegExp(`(\\{ "id": ${JSON.stringify(id).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")},[^\\n]*?"map_pos": )\\[[^\\]]*\\]`);
	if (!re.test(text)) throw new Error(`map_pos für ${id} nicht gefunden (Format von network.json geändert?)`);
	text = text.replace(re, `$1[${pos[0]}, ${pos[1]}]`);
	updated++;
}
JSON.parse(text);
fs.writeFileSync(NETWORK, text);
console.log(`data/network.json: map_pos für ${updated} Städte geschrieben`);
