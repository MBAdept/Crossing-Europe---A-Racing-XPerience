"""Source definitions of the road network (cities, stages, ferries, races).

tools/map/build_network.py turns this into data/network.json (the committed JSON is the source of truth for
the game; this file is the authoring convenience). Distances are realistic road distances (rounded), sections
follow the real motorways. Positions (km) are always measured from the stage's "from" city.

Section helpers:  A(...) = autobahn / motorway / expressway,  L(...) = landstrasse (2-lane road)
  A(length_km, scenery, country, limit=DEF, c=curviness, h=hills, t=traffic, name="…")
  limit: FREE (= null, no limit; German autobahn only) | DEF (= country default, key omitted) | int km/h
Stage helper:
  stage(id, from, to, km, roads, sections, radars=[(km, limit[, "fwd"|"rev"])], tunnels=[(km, length, name)],
        fuel="few"|"normal"|"many"|[km, …])
  km = expected length (checked against the section sum). Radars without direction are valid in both
  directions and must lie between km 50 and length-55 (no radar in the last 50 km of either direction).
  Fuel stations are placed automatically every 60–90 km ("few" ~ 88 km, "normal" ~ 75 km, "many" ~ 62 km).
"""

FREE = None
DEF = "default"


def A(km, scenery, country, limit=DEF, c=1, h=1, t=1.0, name=""):
	return {"length_km": km, "road": "autobahn", "curviness": c, "hills": h, "scenery": scenery,
			"country": country, "speed_limit": limit, "traffic": t, "name": name}


def L(km, scenery, country, limit=DEF, c=2, h=1, t=1.0, name=""):
	return {"length_km": km, "road": "landstrasse", "curviness": c, "hills": h, "scenery": scenery,
			"country": country, "speed_limit": limit, "traffic": t, "name": name}


def stage(sid, frm, to, km, roads, sections, radars=(), tunnels=(), fuel="normal", doc=""):
	return {"id": sid, "from": frm, "to": to, "km": km, "roads": roads, "sections": list(sections),
			"radars": list(radars), "tunnels": list(tunnels), "fuel": fuel, "doc": doc}


# id, name (German), country, lat, lon, local name (signs/info; "" = same)
CITIES = [
	("kiel", "Kiel", "DE", 54.323, 10.123, ""),
	("hamburg", "Hamburg", "DE", 53.551, 9.994, ""),
	("hannover", "Hannover", "DE", 52.376, 9.732, ""),
	("kassel", "Kassel", "DE", 51.313, 9.479, ""),
	("wuerzburg", "Würzburg", "DE", 49.792, 9.940, ""),
	("nuernberg", "Nürnberg", "DE", 49.452, 11.077, ""),
	("bremen", "Bremen", "DE", 53.079, 8.802, ""),
	("dortmund", "Dortmund", "DE", 51.514, 7.468, ""),
	("frankfurt", "Frankfurt", "DE", 50.110, 8.682, ""),
	("muenchen", "München", "DE", 48.137, 11.576, ""),
	("dresden", "Dresden", "DE", 51.050, 13.738, ""),
	("leipzig", "Leipzig", "DE", 51.340, 12.375, ""),
	("erfurt", "Erfurt", "DE", 50.978, 11.029, ""),
	("magdeburg", "Magdeburg", "DE", 52.131, 11.640, ""),
	("berlin", "Berlin", "DE", 52.520, 13.405, ""),
	("rostock", "Rostock", "DE", 54.092, 12.099, ""),
	("groningen", "Groningen", "NL", 53.219, 6.567, ""),
	("amsterdam", "Amsterdam", "NL", 52.370, 4.895, ""),
	("luettich", "Lüttich", "BE", 50.633, 5.567, "Liège"),
	("valenciennes", "Valenciennes", "FR", 50.357, 3.524, ""),
	("paris", "Paris", "FR", 48.857, 2.352, ""),
	("tours", "Tours", "FR", 47.394, 0.685, ""),
	("bordeaux", "Bordeaux", "FR", 44.838, -0.579, ""),
	("san_sebastian", "San Sebastián", "ES", 43.318, -1.981, "Donostia"),
	("burgos", "Burgos", "ES", 42.344, -3.697, ""),
	("madrid", "Madrid", "ES", 40.417, -3.704, ""),
	("saragossa", "Saragossa", "ES", 41.649, -0.889, "Zaragoza"),
	("barcelona", "Barcelona", "ES", 41.385, 2.173, ""),
	("pau", "Pau", "FR", 43.295, -0.371, ""),
	("toulouse", "Toulouse", "FR", 43.605, 1.444, ""),
	("montpellier", "Montpellier", "FR", 43.611, 3.877, ""),
	("lyon", "Lyon", "FR", 45.764, 4.836, ""),
	("bern", "Bern", "CH", 46.948, 7.447, ""),
	("mailand", "Mailand", "IT", 45.464, 9.190, "Milano"),
	("venedig", "Venedig", "IT", 45.481, 12.236, "Venezia"),
	("ljubljana", "Ljubljana", "SI", 46.056, 14.506, ""),
	("zagreb", "Zagreb", "HR", 45.815, 15.982, ""),
	("slavonski_brod", "Slavonski Brod", "HR", 45.160, 18.016, ""),
	("belgrad", "Belgrad", "RS", 44.787, 20.457, "Beograd"),
	("nis", "Niš", "RS", 43.320, 21.896, ""),
	("sofia", "Sofia", "BG", 42.698, 23.322, "София"),
	("szeged", "Szeged", "HU", 46.253, 20.148, ""),
	("budapest", "Budapest", "HU", 47.498, 19.040, ""),
	("wien", "Wien", "AT", 48.208, 16.373, ""),
	("prag", "Prag", "CZ", 50.076, 14.438, "Praha"),
	("posen", "Posen", "PL", 52.406, 16.925, "Poznań"),
	("warschau", "Warschau", "PL", 52.230, 21.011, "Warszawa"),
	("bialystok", "Białystok", "PL", 53.133, 23.169, ""),
	("kaunas", "Kaunas", "LT", 54.899, 23.904, ""),
	("riga", "Riga", "LV", 56.950, 24.105, "Rīga"),
]

# Developer cities/stage (hidden in menus) – kept exactly as other modules rely on them.
DEV_CITIES = [
	{"id": "dev_start", "name": "Teststadt", "country": "DE", "latlon": [52.0, 7.0], "dev": True},
	{"id": "dev_ziel", "name": "Testdorp", "country": "NL", "latlon": [52.2, 5.5], "dev": True},
]

DEV_STAGE = {
	"id": "dev_testetappe",
	"dev": True,
	"from": "dev_start",
	"to": "dev_ziel",
	"length_km": 130,
	"_doc": "Entwickler-Etappe mit allen Elementen auf kurzer Strecke (nicht im Menü, nur vorwärts geprüft).",
	"sections": [
		{"length_km": 35, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": None},
		{"length_km": 30, "road": "landstrasse", "curviness": 3, "hills": 2, "scenery": "forest_hills", "country": "DE"},
		{"length_km": 65, "road": "autobahn", "curviness": 2, "hills": 1, "scenery": "polder", "country": "NL", "traffic": 1.3},
	],
	"fuel_stations_km": [20, 80],
	"radars": [{"km": 12, "limit": 120}],
	"tunnels": [{"km": 50, "length_km": 4, "name": "Testtunnel"}],
	"borders": [{"km": 65, "to": "NL"}],
}

STAGES = [
	# ------------------------------------------------------------------ Kiel – Nürnberg ---------------
	stage("kiel_hamburg", "kiel", "hamburg", 95, "A215 · A7", [
		A(12, "north_plain", "DE", 120, c=1, h=1, t=1.0, name="A215 Kiel – Bordesholm"),
		A(13, "north_plain", "DE", FREE, c=0, h=0, t=0.9, name="A7 Bordesholm – Neumünster"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.0, name="A7 Neumünster"),
		A(20, "north_plain", "DE", FREE, c=0, h=0, t=1.0, name="A7 Holstein"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.2, name="A7 Quickborn"),
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.4, name="A7 Hamburg-Schnelsen"),
	], radars=[(28, 120, "fwd"), (62, 120, "rev")], fuel="normal",
		doc="Tutorial: einfache Autobahn, eine Tankstelle, ein Radar je Richtung."),
	stage("hamburg_hannover", "hamburg", "hannover", 150, "A7", [
		A(15, "north_plain", "DE", 80, c=1, h=0, t=1.5, name="A7 Elbtunnel – Hamburg-Süd"),
		A(25, "heath", "DE", 120, c=1, h=1, t=1.2, name="A7 Harburger Berge"),
		A(45, "heath", "DE", FREE, c=0, h=1, t=1.0, name="A7 Lüneburger Heide"),
		A(15, "heath", "DE", 120, c=1, h=1, t=1.0, name="A7 Dreieck Walsrode"),
		A(30, "heath", "DE", FREE, c=0, h=0, t=1.0, name="A7 Allertal"),
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.3, name="A7 Hannover"),
	], radars=[(18, 120, "fwd"), (88, 120), (135, 100, "rev")], tunnels=[(4, 3.3, "Elbtunnel")], fuel="few",
		doc="Ostroute: Elbtunnel, Lüneburger Heide."),
	stage("hannover_kassel", "hannover", "kassel", 165, "A7", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A7 Hannover – Laatzen"),
		A(35, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A7 Hildesheimer Börde"),
		A(30, "forest_hills", "DE", 120, c=2, h=2, t=1.0, name="A7 Leinebergland"),
		A(30, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A7 Göttingen"),
		A(30, "forest_hills", "DE", 100, c=2, h=3, t=1.1, name="A7 Kasseler Berge"),
		A(20, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A7 Kassel-Nord"),
	], radars=[(70, 120), (125, 100, "rev")], fuel="few",
		doc="Ostroute: Leinebergland und die steilen Kasseler Berge."),
	stage("kassel_wuerzburg", "kassel", "wuerzburg", 210, "A7", [
		A(20, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A7 Kassel"),
		A(35, "forest_hills", "DE", 100, c=2, h=3, t=1.0, name="A7 Söhre – Melsungen"),
		A(35, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A7 Kirchheimer Dreieck"),
		A(25, "forest_hills", "DE", 120, c=2, h=2, t=1.0, name="A7 Fulda"),
		A(40, "forest_hills", "DE", 100, c=2, h=3, t=1.0, name="A7 Rhön (Kalte Buche)"),
		A(35, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A7 Hammelburg"),
		A(20, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A7 Würzburg"),
	], radars=[(50, 100), (100, 120), (140, 100)], fuel="few",
		doc="Ostroute: Mittelgebirge und Rhön, viele Tempolimits und Radarfallen."),
	stage("hamburg_bremen", "hamburg", "bremen", 120, "A1", [
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.5, name="A1 Hamburg-Harburg"),
		A(40, "heath", "DE", FREE, c=0, h=0, t=1.2, name="A1 Hollenstedt – Sittensen"),
		A(40, "north_plain", "DE", FREE, c=0, h=0, t=1.1, name="A1 Bockel – Oyten"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A1 Bremer Kreuz"),
	], fuel="many", doc="Westroute: flach und frei, kein Radar."),
	stage("bremen_dortmund", "bremen", "dortmund", 235, "A1", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A1 Bremen – Delmenhorst"),
		A(60, "north_plain", "DE", FREE, c=0, h=0, t=1.0, name="A1 Oldenburger Münsterland"),
		A(30, "forest_hills", "DE", 120, c=1, h=2, t=1.2, name="A1 Osnabrück – Teutoburger Wald"),
		A(45, "north_plain", "DE", FREE, c=0, h=1, t=1.1, name="A1 Münsterland"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A1 Münster"),
		A(45, "industrial", "DE", FREE, c=1, h=0, t=1.5, name="A1 Ascheberg – Kamener Kreuz"),
		A(20, "industrial", "DE", 100, c=1, h=0, t=1.6, name="A1 Dortmund"),
	], radars=[(95, 120)], fuel="many", doc="Westroute: viel freie Autobahn, dichter Verkehr im Ruhrgebiet."),
	stage("dortmund_frankfurt", "dortmund", "frankfurt", 225, "A45 · A5", [
		A(20, "industrial", "DE", 100, c=1, h=1, t=1.6, name="A45 Dortmund – Westhofener Kreuz"),
		A(45, "forest_hills", "DE", FREE, c=2, h=2, t=1.3, name="A45 Sauerland"),
		A(15, "forest_hills", "DE", 80, c=2, h=2, t=1.3, name="A45 Baustelle Talbrücken"),
		A(50, "forest_hills", "DE", FREE, c=2, h=2, t=1.2, name="A45 Siegerland"),
		A(30, "forest_hills", "DE", 120, c=1, h=2, t=1.2, name="A45 Wetzlar – Gießener Südkreuz"),
		A(40, "rhine_main", "DE", FREE, c=1, h=1, t=1.4, name="A45/A5 Wetterau"),
		A(25, "rhine_main", "DE", 100, c=1, h=0, t=1.6, name="A5 Frankfurt"),
	], radars=[(140, 120)], fuel="many", doc="Westroute: Sauerlandlinie, LKW-Verkehr, Rhein-Main."),
	stage("frankfurt_wuerzburg", "frankfurt", "wuerzburg", 120, "A3", [
		A(20, "rhine_main", "DE", 100, c=1, h=0, t=1.6, name="A3 Frankfurter Kreuz – Offenbach"),
		A(25, "rhine_main", "DE", FREE, c=1, h=1, t=1.4, name="A3 Hanau – Aschaffenburg"),
		A(45, "forest_hills", "DE", FREE, c=2, h=2, t=1.1, name="A3 Spessart"),
		A(30, "forest_hills", "DE", 120, c=1, h=1, t=1.2, name="A3 Marktheidenfeld – Würzburg"),
	], fuel="many", doc="Westroute: Spessart, kein Radar."),
	stage("wuerzburg_nuernberg", "wuerzburg", "nuernberg", 110, "A3", [
		A(15, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A3 Würzburg-Biebelried"),
		A(40, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A3 Steigerwald"),
		A(20, "forest_hills", "DE", 120, c=1, h=1, t=1.1, name="A3 Höchstadt"),
		A(35, "forest_hills", "DE", 120, c=1, h=1, t=1.4, name="A3 Erlangen – Nürnberg"),
	], radars=[(55, 120)], fuel="normal", doc="Gemeinsame Schlussetappe beider Routen."),
	# ------------------------------------------------------------------ München – Bremen -------------
	stage("muenchen_nuernberg", "muenchen", "nuernberg", 170, "A9", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.5, name="A9 München – Allershausen"),
		A(45, "north_plain", "DE", FREE, c=0, h=1, t=1.2, name="A9 Hallertau"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A9 Ingolstadt"),
		A(60, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A9 Altmühltal – Fränkische Alb"),
		A(30, "forest_hills", "DE", 120, c=1, h=1, t=1.4, name="A9 Feucht – Nürnberg"),
	], radars=[(66, 120)], fuel="normal"),
	stage("hannover_bremen", "hannover", "bremen", 125, "A7 · A27", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A7 Hannover-Nord"),
		A(35, "heath", "DE", FREE, c=0, h=0, t=1.0, name="A7 Mellendorf – Walsrode"),
		A(15, "heath", "DE", 120, c=1, h=0, t=1.0, name="A7/A27 Dreieck Walsrode"),
		A(35, "north_plain", "DE", FREE, c=0, h=0, t=1.0, name="A27 Verden"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A27 Bremer Kreuz – Bremen"),
	], radars=[(58, 120)], fuel="normal"),
	# ------------------------------------------------------------------ Dresden – Dortmund -----------
	stage("dresden_leipzig", "dresden", "leipzig", 115, "A4 · A14", [
		A(15, "forest_hills", "DE", 120, c=1, h=1, t=1.4, name="A4 Dresden"),
		A(30, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A4 Wilsdruff – Nossen"),
		A(15, "north_plain", "DE", 120, c=1, h=1, t=1.0, name="A14 Döbeln"),
		A(35, "north_plain", "DE", FREE, c=0, h=1, t=1.1, name="A14 Muldental – Grimma"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A14 Leipzig"),
	], radars=[(50, 120)], fuel="normal"),
	stage("leipzig_erfurt", "leipzig", "erfurt", 150, "A9 · A4", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A9 Leipzig – Kreuz Rippachtal"),
		A(45, "north_plain", "DE", FREE, c=0, h=1, t=1.1, name="A9 Weißenfels – Saaletal"),
		A(20, "forest_hills", "DE", 120, c=1, h=2, t=1.2, name="Hermsdorfer Kreuz"),
		A(25, "forest_hills", "DE", 100, c=2, h=2, t=1.0, name="A4 Jena – Leutratal"),
		A(20, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A4 Magdala – Weimar"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A4 Erfurt"),
	], radars=[(68, 120)], tunnels=[(95, 3.1, "Jagdbergtunnel")], fuel="normal",
		doc="Südroute: Saaletal, Jagdbergtunnel."),
	stage("erfurt_kassel", "erfurt", "kassel", 155, "A4 · B7 · A44", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A4 Erfurt"),
		A(35, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A4 Gotha – Eisenach"),
		A(15, "forest_hills", "DE", 100, c=2, h=2, t=1.0, name="A4 Hörselberge"),
		A(20, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A4 Herleshausen – Wommen"),
		L(25, "forest_hills", "DE", DEF, c=3, h=2, t=0.9, name="B7 Lückenschluss A44 (Werra-Meißner)"),
		A(20, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A44 Hessisch Lichtenau"),
		A(20, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A44 Kassel-Ost"),
	], radars=[(58, 100), (100, 100)], fuel="normal",
		doc="Südroute: Hörselberge und die Landstraßenlücke der A44."),
	stage("kassel_dortmund", "kassel", "dortmund", 160, "A44", [
		A(15, "forest_hills", "DE", 120, c=1, h=1, t=1.3, name="A44 Kassel-West"),
		A(40, "forest_hills", "DE", FREE, c=1, h=2, t=1.0, name="A44 Warburger Börde"),
		A(20, "forest_hills", "DE", 120, c=1, h=2, t=1.0, name="A44 Paderborner Hochfläche"),
		A(40, "north_plain", "DE", FREE, c=0, h=1, t=1.0, name="A44 Hellweg – Soest"),
		A(25, "industrial", "DE", FREE, c=1, h=0, t=1.4, name="A44 Werl – Unna"),
		A(20, "industrial", "DE", 100, c=1, h=0, t=1.6, name="A44/B1 Dortmund"),
	], radars=[(58, 120)], fuel="normal"),
	stage("leipzig_magdeburg", "leipzig", "magdeburg", 125, "A14", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A14 Leipzig – Schkeuditz"),
		A(30, "north_plain", "DE", FREE, c=0, h=0, t=1.2, name="A14 Halle"),
		A(18, "north_plain", "DE", 120, c=1, h=1, t=1.1, name="A14 Saalebrücke Könnern"),
		A(37, "north_plain", "DE", FREE, c=0, h=1, t=1.0, name="A14 Magdeburger Börde"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A14 Magdeburg"),
	], radars=[(52, 120)], fuel="many", doc="Nordroute: flach, wenig Radar."),
	stage("magdeburg_hannover", "magdeburg", "hannover", 145, "A2", [
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A2 Magdeburg"),
		A(35, "north_plain", "DE", FREE, c=0, h=1, t=1.3, name="A2 Börde – Helmstedt"),
		A(25, "north_plain", "DE", 120, c=1, h=1, t=1.4, name="A2 Braunschweig"),
		A(50, "north_plain", "DE", FREE, c=0, h=0, t=1.3, name="A2 Peine – Lehrte"),
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.5, name="A2 Hannover-Ost"),
	], radars=[(55, 120)], fuel="many", doc="Nordroute: A2 mit viel LKW-Verkehr."),
	stage("hannover_dortmund", "hannover", "dortmund", 210, "A2", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.5, name="A2 Hannover-West"),
		A(35, "north_plain", "DE", FREE, c=0, h=1, t=1.3, name="A2 Bad Nenndorf – Bückeburg"),
		A(25, "forest_hills", "DE", 120, c=1, h=2, t=1.4, name="A2 Porta Westfalica"),
		A(25, "forest_hills", "DE", FREE, c=1, h=2, t=1.3, name="A2 Bielefeld – Teutoburger Wald"),
		A(50, "north_plain", "DE", FREE, c=0, h=0, t=1.3, name="A2 Gütersloh – Beckum"),
		A(35, "industrial", "DE", 120, c=1, h=0, t=1.5, name="A2 Hamm – Kamener Kreuz"),
		A(20, "industrial", "DE", 100, c=1, h=0, t=1.6, name="A2/A1 Dortmund"),
	], radars=[(60, 120)], fuel="many", doc="Nordroute: A2 mit viel LKW-Verkehr."),
	# ------------------------------------------------------------------ Königsrennen ----------------
	stage("bremen_groningen", "bremen", "groningen", 180, "A28 · A31 · A7 (NL)", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A28 Bremen – Delmenhorst"),
		A(25, "north_plain", "DE", FREE, c=0, h=0, t=1.0, name="A28 Hude"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.2, name="A28 Oldenburg"),
		A(55, "north_plain", "DE", FREE, c=0, h=0, t=0.9, name="A28 Ammerland – Leer"),
		A(25, "coast", "DE", 100, c=1, h=0, t=0.9, name="A31 Emstunnel – Bunde"),
		A(40, "polder", "NL", DEF, c=0, h=0, t=1.0, name="A7 Oost-Groningen"),
	], radars=[(50, 120), (150, 100, "rev")], tunnels=[(125, 0.95, "Emstunnel")], fuel="normal"),
	stage("groningen_amsterdam", "groningen", "amsterdam", 185, "A7 · A6 · A10", [
		A(20, "polder", "NL", DEF, c=0, h=0, t=1.2, name="A7 Groningen"),
		A(40, "polder", "NL", DEF, c=0, h=0, t=1.0, name="A7 Drachten – Heerenveen"),
		A(30, "polder", "NL", DEF, c=0, h=0, t=0.9, name="A6 Lemmer – Emmeloord"),
		A(15, "coast", "NL", DEF, c=1, h=0, t=0.9, name="A6 Ketelbrug"),
		A(40, "polder", "NL", DEF, c=0, h=0, t=1.2, name="A6 Flevoland – Almere"),
		A(15, "coast", "NL", DEF, c=1, h=0, t=1.4, name="A6 Hollandse Brug"),
		A(25, "polder", "NL", DEF, c=1, h=0, t=1.6, name="A1/A10 Amsterdam"),
	], radars=[(70, 100), (115, 100)], fuel="normal", doc="Polder und Deiche über die Flevopolder."),
	stage("amsterdam_luettich", "amsterdam", "luettich", 235, "A2 · E25", [
		A(20, "polder", "NL", DEF, c=1, h=0, t=1.6, name="A2 Amsterdam"),
		A(25, "polder", "NL", DEF, c=1, h=0, t=1.5, name="A2 Utrecht"),
		A(50, "polder", "NL", DEF, c=0, h=0, t=1.2, name="A2 Bommelerwaard – 's-Hertogenbosch"),
		A(30, "heath", "NL", DEF, c=1, h=0, t=1.3, name="A2 Eindhoven"),
		A(50, "heath", "NL", DEF, c=0, h=0, t=1.0, name="A2 Weert – Roermond"),
		A(35, "ardennes", "NL", DEF, c=1, h=1, t=1.3, name="A2 Maastricht"),
		A(25, "ardennes", "BE", DEF, c=1, h=2, t=1.3, name="E25 Visé – Lüttich"),
	], radars=[(60, 100), (140, 100)], tunnels=[(198, 2.3, "Koning-Willem-Alexander-Tunnel")], fuel="normal"),
	stage("luettich_valenciennes", "luettich", "valenciennes", 190, "E42 · E19 · A2", [
		A(20, "ardennes", "BE", DEF, c=1, h=1, t=1.4, name="E42 Lüttich"),
		A(45, "farmland_fr", "BE", DEF, c=0, h=1, t=1.0, name="E42 Hespengau – Namur"),
		A(40, "industrial", "BE", DEF, c=1, h=1, t=1.3, name="E42 Sambretal – Charleroi"),
		A(45, "farmland_fr", "BE", DEF, c=0, h=1, t=1.1, name="E42 Binche – Mons"),
		A(20, "industrial", "BE", DEF, c=1, h=0, t=1.2, name="E19 Borinage"),
		A(20, "farmland_fr", "FR", DEF, c=1, h=0, t=1.3, name="A2 Valenciennes"),
	], radars=[(60, 120), (110, 120)], fuel="normal"),
	stage("valenciennes_paris", "valenciennes", "paris", 205, "A2 · A1", [
		A(20, "farmland_fr", "FR", DEF, c=1, h=0, t=1.2, name="A2 Valenciennes – Cambrai"),
		A(45, "farmland_fr", "FR", DEF, c=0, h=1, t=1.0, name="A2 Cambrésis"),
		A(70, "farmland_fr", "FR", DEF, c=0, h=1, t=1.0, name="A1 Picardie"),
		A(30, "forest_hills", "FR", DEF, c=1, h=1, t=1.1, name="A1 Forêt d'Halatte – Senlis"),
		A(20, "farmland_fr", "FR", 110, c=1, h=0, t=1.5, name="A1 Roissy"),
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.7, name="A1 Saint-Denis – Paris"),
	], radars=[(70, 130), (120, 130), (168, 110, "rev")], tunnels=[(195, 1.3, "Tunnel du Landy")], fuel="normal"),
	stage("paris_tours", "paris", "tours", 240, "A10", [
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.6, name="A6/A10 Paris – Massy"),
		A(30, "farmland_fr", "FR", DEF, c=0, h=0, t=1.2, name="A10 Dourdan"),
		A(60, "farmland_fr", "FR", DEF, c=0, h=0, t=1.0, name="A10 Beauce"),
		A(20, "loire", "FR", DEF, c=1, h=0, t=1.1, name="A10 Orléans"),
		A(90, "loire", "FR", DEF, c=1, h=1, t=1.0, name="A10 Loiretal – Blois – Amboise"),
		A(20, "loire", "FR", DEF, c=1, h=0, t=1.2, name="A10 Tours"),
	], radars=[(70, 130), (150, 130)], fuel="normal"),
	stage("tours_bordeaux", "tours", "bordeaux", 345, "A10", [
		A(20, "loire", "FR", DEF, c=1, h=0, t=1.2, name="A10 Tours"),
		A(75, "farmland_fr", "FR", DEF, c=0, h=1, t=1.0, name="A10 Châtellerault – Poitiers"),
		A(85, "farmland_fr", "FR", DEF, c=1, h=1, t=0.9, name="A10 Niort – Poitou"),
		A(75, "farmland_fr", "FR", DEF, c=1, h=1, t=0.9, name="A10 Saintes – Cognac"),
		A(70, "farmland_fr", "FR", DEF, c=1, h=0, t=1.1, name="A10 Gironde"),
		A(20, "farmland_fr", "FR", 110, c=1, h=0, t=1.5, name="Rocade Bordeaux"),
	], radars=[(80, 130), (170, 130), (250, 130)], fuel="normal"),
	stage("bordeaux_san_sebastian", "bordeaux", "san_sebastian", 240, "A63 · AP-8", [
		A(20, "farmland_fr", "FR", 110, c=1, h=0, t=1.5, name="Rocade Bordeaux"),
		A(120, "forest_hills", "FR", DEF, c=0, h=0, t=1.0, name="A63 Landes (Kiefernwald)"),
		A(45, "farmland_fr", "FR", DEF, c=1, h=1, t=1.1, name="A63 Labenne – Bayonne"),
		A(33, "pyrenees", "FR", DEF, c=2, h=2, t=1.2, name="A63 Baskische Küste"),
		A(22, "pyrenees", "ES", DEF, c=2, h=2, t=1.3, name="AP-8 Irun – San Sebastián"),
	], radars=[(60, 130), (120, 130)], fuel="normal"),
	stage("san_sebastian_burgos", "san_sebastian", "burgos", 225, "A-15 · A-1 · AP-1", [
		A(20, "pyrenees", "ES", DEF, c=2, h=2, t=1.3, name="A-15 San Sebastián – Andoain"),
		A(45, "pyrenees", "ES", 100, c=3, h=3, t=1.1, name="A-1 Tolosa – Etxegarate-Pass"),
		A(35, "pyrenees", "ES", DEF, c=2, h=2, t=1.0, name="A-1 Altsasu – Llanada Alavesa"),
		A(15, "meseta", "ES", DEF, c=1, h=1, t=1.2, name="A-1 Vitoria-Gasteiz"),
		A(35, "meseta", "ES", DEF, c=1, h=1, t=1.0, name="AP-1 Miranda de Ebro"),
		A(20, "meseta", "ES", 100, c=2, h=2, t=1.0, name="A-1 Desfiladero de Pancorbo"),
		A(55, "meseta", "ES", DEF, c=0, h=1, t=1.0, name="A-1 Briviesca – Burgos"),
	], radars=[(50, 100), (155, 100)], fuel="normal"),
	stage("burgos_madrid", "burgos", "madrid", 240, "A-1", [
		A(20, "meseta", "ES", DEF, c=1, h=1, t=1.2, name="A-1 Burgos"),
		A(80, "meseta", "ES", DEF, c=0, h=1, t=0.9, name="A-1 Lerma – Aranda de Duero"),
		A(40, "meseta", "ES", DEF, c=1, h=2, t=0.9, name="A-1 Boceguillas"),
		A(25, "meseta", "ES", 100, c=2, h=3, t=0.9, name="A-1 Puerto de Somosierra (1444 m)"),
		A(50, "meseta", "ES", DEF, c=1, h=2, t=1.1, name="A-1 Buitrago – San Agustín"),
		A(25, "meseta", "ES", 100, c=1, h=0, t=1.6, name="A-1 Madrid (Alcobendas)"),
	], radars=[(60, 120), (150, 100)], fuel="normal"),
	stage("madrid_saragossa", "madrid", "saragossa", 315, "A-2", [
		A(25, "meseta", "ES", 100, c=1, h=0, t=1.6, name="A-2 Madrid – Alcalá de Henares"),
		A(40, "meseta", "ES", DEF, c=0, h=1, t=1.3, name="A-2 Guadalajara"),
		A(70, "meseta", "ES", DEF, c=1, h=2, t=0.9, name="A-2 Alcarria – Alcolea del Pinar"),
		A(50, "meseta", "ES", DEF, c=1, h=2, t=0.8, name="A-2 Medinaceli – Jalón"),
		A(40, "meseta", "ES", DEF, c=2, h=2, t=0.9, name="A-2 Calatayud"),
		A(70, "meseta", "ES", DEF, c=1, h=1, t=1.0, name="A-2 Ebrotal"),
		A(20, "meseta", "ES", 100, c=1, h=0, t=1.4, name="A-2 Saragossa"),
	], radars=[(70, 120), (160, 120), (240, 120)], fuel="normal"),
	stage("saragossa_barcelona", "saragossa", "barcelona", 300, "AP-2 · AP-7", [
		A(20, "meseta", "ES", 100, c=1, h=0, t=1.3, name="Saragossa"),
		A(90, "meseta", "ES", DEF, c=0, h=1, t=0.8, name="AP-2 Monegros"),
		A(40, "meseta", "ES", DEF, c=1, h=1, t=1.0, name="AP-2 Fraga – Lleida"),
		A(60, "mediterranean", "ES", DEF, c=2, h=2, t=1.0, name="AP-2 Garrigues – Coll de Lilla"),
		A(60, "mediterranean", "ES", DEF, c=1, h=1, t=1.3, name="AP-7 Penedès"),
		A(30, "industrial", "ES", 100, c=1, h=0, t=1.6, name="A-2 Martorell – Barcelona"),
	], radars=[(60, 120), (130, 120), (220, 120)], fuel="normal", doc="Küstenroute (Wahl bei Saragossa)."),
	stage("barcelona_montpellier", "barcelona", "montpellier", 350, "AP-7 · A9", [
		A(20, "industrial", "ES", 100, c=1, h=0, t=1.6, name="AP-7 Barcelona"),
		A(50, "mediterranean", "ES", DEF, c=1, h=1, t=1.3, name="AP-7 Vallès – Granollers"),
		A(55, "mediterranean", "ES", DEF, c=1, h=1, t=1.0, name="AP-7 Girona"),
		A(25, "mediterranean", "ES", DEF, c=1, h=1, t=1.0, name="AP-7 Empordà – Figueres"),
		A(15, "pyrenees", "ES", DEF, c=2, h=2, t=1.0, name="AP-7 La Jonquera"),
		A(15, "pyrenees", "FR", DEF, c=2, h=2, t=1.0, name="A9 Le Perthus – Le Boulou"),
		A(30, "mediterranean", "FR", DEF, c=1, h=0, t=1.2, name="A9 Perpignan"),
		A(60, "coast", "FR", DEF, c=1, h=0, t=1.0, name="A9 Étangs – Leucate – Narbonne"),
		A(60, "mediterranean", "FR", DEF, c=1, h=1, t=1.1, name="A9 Béziers"),
		A(20, "mediterranean", "FR", 110, c=1, h=0, t=1.4, name="A9 Montpellier"),
	], radars=[(60, 120), (130, 120), (190, 130), (260, 130)], fuel="normal", doc="Küstenroute (Wahl bei Saragossa)."),
	stage("saragossa_pau", "saragossa", "pau", 260, "A-23 · N-330 · N134", [
		A(20, "meseta", "ES", 100, c=1, h=0, t=1.3, name="Saragossa"),
		A(55, "meseta", "ES", DEF, c=1, h=1, t=0.9, name="A-23 Zuera – Huesca"),
		A(30, "pyrenees", "ES", DEF, c=2, h=3, t=0.8, name="A-23 Monrepós"),
		A(40, "pyrenees", "ES", DEF, c=2, h=2, t=0.8, name="A-23 Sabiñánigo – Jaca"),
		L(32, "pyrenees", "ES", DEF, c=3, h=3, t=0.7, name="N-330 Canfranc"),
		L(8.6, "pyrenees", "ES", 70, c=1, h=1, t=0.6, name="Somport-Tunnel"),
		L(40, "pyrenees", "FR", DEF, c=3, h=3, t=0.6, name="N134 Vallée d'Aspe"),
		L(34.4, "farmland_fr", "FR", DEF, c=2, h=1, t=0.9, name="N134 Oloron – Pau"),
	], radars=[(60, 120)], tunnels=[(177, 8.6, "Somport-Tunnel")], fuel="many",
		doc="Pyrenäenroute (Wahl bei Saragossa): Bergstraßen und Somport-Tunnel, wenig Verkehr und Radar."),
	stage("pau_toulouse", "pau", "toulouse", 195, "A64", [
		A(20, "farmland_fr", "FR", DEF, c=1, h=1, t=1.2, name="A64 Pau"),
		A(60, "pyrenees", "FR", DEF, c=1, h=2, t=0.9, name="A64 Tarbes – Lannemezan"),
		A(50, "farmland_fr", "FR", DEF, c=1, h=1, t=0.9, name="A64 Saint-Gaudens – Garonne"),
		A(45, "farmland_fr", "FR", DEF, c=0, h=1, t=1.1, name="A64 Muret"),
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.5, name="Toulouse"),
	], radars=[(70, 130)], fuel="many", doc="Pyrenäenroute (Wahl bei Saragossa)."),
	stage("toulouse_montpellier", "toulouse", "montpellier", 245, "A61 · A9", [
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.5, name="Toulouse"),
		A(70, "farmland_fr", "FR", DEF, c=1, h=1, t=1.0, name="A61 Lauragais – Carcassonne"),
		A(60, "mediterranean", "FR", DEF, c=1, h=1, t=1.0, name="A61 Corbières – Narbonne"),
		A(75, "mediterranean", "FR", DEF, c=1, h=1, t=1.1, name="A9 Béziers"),
		A(20, "mediterranean", "FR", 110, c=1, h=0, t=1.4, name="A9 Montpellier"),
	], radars=[(60, 130), (160, 130)], fuel="many", doc="Pyrenäenroute (Wahl bei Saragossa)."),
	stage("montpellier_lyon", "montpellier", "lyon", 305, "A9 · A7", [
		A(20, "mediterranean", "FR", 110, c=1, h=0, t=1.4, name="A9 Montpellier"),
		A(50, "mediterranean", "FR", DEF, c=1, h=1, t=1.2, name="A9 Nîmes – Remoulins"),
		A(30, "mediterranean", "FR", DEF, c=1, h=1, t=1.3, name="A7 Orange"),
		A(70, "farmland_fr", "FR", DEF, c=1, h=1, t=1.3, name="A7 Rhônetal – Montélimar"),
		A(50, "farmland_fr", "FR", DEF, c=1, h=1, t=1.3, name="A7 Valence"),
		A(65, "farmland_fr", "FR", DEF, c=1, h=1, t=1.4, name="A7 Tain-l'Hermitage – Vienne"),
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.6, name="A7 Lyon (Chemietal)"),
	], radars=[(60, 130), (140, 130), (230, 130)], fuel="normal"),
	stage("lyon_bern", "lyon", "bern", 310, "A42 · A40 · A1 · A12", [
		A(20, "industrial", "FR", 110, c=1, h=0, t=1.5, name="Lyon"),
		A(40, "farmland_fr", "FR", DEF, c=1, h=1, t=1.1, name="A42 Plaine de l'Ain"),
		A(40, "forest_hills", "FR", DEF, c=2, h=3, t=1.0, name="A40 Jura (Autoroute des Titans)"),
		A(40, "alps", "FR", DEF, c=2, h=2, t=1.1, name="A40 Bellegarde – Genf"),
		A(20, "alps", "CH", DEF, c=1, h=1, t=1.5, name="A1 Genf"),
		A(50, "alps", "CH", DEF, c=1, h=1, t=1.3, name="A1 Genfersee – Lausanne"),
		A(30, "alps", "CH", DEF, c=2, h=2, t=1.1, name="A9/A12 Lavaux – Châtel-St-Denis"),
		A(50, "forest_hills", "CH", DEF, c=1, h=2, t=1.0, name="A12 Freiburg im Üechtland"),
		A(20, "forest_hills", "CH", 100, c=1, h=1, t=1.4, name="A12 Bern"),
	], radars=[(65, 130), (170, 120), (250, 120)], tunnels=[(80, 3.3, "Tunnel de Chamoise")], fuel="normal"),
	stage("bern_mailand", "bern", "mailand", 365, "A1 · A2 · A9 (I)", [
		A(20, "forest_hills", "CH", 100, c=1, h=1, t=1.4, name="A1 Bern"),
		A(85, "forest_hills", "CH", DEF, c=1, h=1, t=1.2, name="A1/A2 Mittelland – Luzern"),
		A(25, "alps", "CH", DEF, c=2, h=2, t=1.2, name="A2 Luzern – Stans"),
		A(9.3, "alps", "CH", 100, c=1, h=0, t=1.0, name="Seelisbergtunnel"),
		A(45.7, "alps", "CH", DEF, c=2, h=3, t=1.0, name="A2 Urnersee – Reusstal – Göschenen"),
		L(17, "alps", "CH", 80, c=1, h=1, t=0.9, name="Gotthard-Strassentunnel"),
		A(40, "alps", "CH", DEF, c=2, h=3, t=1.0, name="A2 Leventina – Biasca"),
		A(50, "alps", "CH", DEF, c=2, h=2, t=1.2, name="A2 Bellinzona – Monte Ceneri – Lugano"),
		A(25, "lombardy", "CH", DEF, c=1, h=1, t=1.3, name="A2 Mendrisiotto – Chiasso"),
		A(48, "lombardy", "IT", DEF, c=1, h=0, t=1.4, name="A9 Como – Mailand"),
	], radars=[(60, 120), (215, 120), (260, 120), (325, 130, "rev")],
		tunnels=[(106, 1.5, "Sonnenbergtunnel"), (130, 9.3, "Seelisbergtunnel"), (185, 16.9, "Gotthard-Strassentunnel")],
		fuel="normal", doc="Alpenetappe: Seelisberg- und Gotthardtunnel."),
	stage("mailand_venedig", "mailand", "venedig", 275, "A4", [
		A(20, "industrial", "IT", 110, c=1, h=0, t=1.6, name="Tangenziale Mailand"),
		A(30, "lombardy", "IT", DEF, c=0, h=0, t=1.4, name="A4 Bergamo"),
		A(40, "lombardy", "IT", DEF, c=0, h=0, t=1.3, name="A4 Brescia"),
		A(30, "lombardy", "IT", DEF, c=1, h=1, t=1.2, name="A4 Gardasee – Desenzano"),
		A(35, "lombardy", "IT", DEF, c=0, h=0, t=1.3, name="A4 Verona"),
		A(50, "lombardy", "IT", DEF, c=0, h=0, t=1.2, name="A4 Vicenza"),
		A(50, "lombardy", "IT", DEF, c=0, h=0, t=1.3, name="A4 Padua"),
		A(20, "coast", "IT", 110, c=1, h=0, t=1.4, name="Mestre – Lagune"),
	], radars=[(60, 130), (130, 130), (190, 130)], fuel="normal"),
	stage("venedig_ljubljana", "venedig", "ljubljana", 245, "A4 · RA13 · A3/A1 (SI)", [
		A(20, "coast", "IT", 110, c=1, h=0, t=1.4, name="Mestre"),
		A(75, "lombardy", "IT", DEF, c=0, h=0, t=1.1, name="A4 Friaul – Palmanova"),
		A(35, "karst", "IT", DEF, c=1, h=1, t=1.1, name="A4 Monfalcone – Karst"),
		A(15, "karst", "IT", 110, c=2, h=2, t=1.2, name="RA13 Triest – Fernetti"),
		A(50, "karst", "SI", DEF, c=2, h=2, t=1.0, name="A3/A1 Sežana – Postojna"),
		A(50, "forest_hills", "SI", DEF, c=1, h=2, t=1.1, name="A1 Logatec – Ljubljana"),
	], radars=[(60, 130), (160, 130)], fuel="normal"),
	stage("ljubljana_zagreb", "ljubljana", "zagreb", 140, "A2 (SI) · A3 (HR)", [
		A(20, "forest_hills", "SI", 100, c=1, h=1, t=1.4, name="Ljubljana-Ring"),
		A(50, "forest_hills", "SI", DEF, c=2, h=2, t=1.0, name="A2 Unterkrain"),
		A(40, "forest_hills", "SI", DEF, c=1, h=1, t=1.0, name="A2 Novo Mesto – Obrežje"),
		A(30, "pannonian_plain", "HR", DEF, c=1, h=0, t=1.3, name="A3 Bregana – Zagreb"),
	], radars=[(55, 130)], fuel="normal"),
	stage("zagreb_slavonski_brod", "zagreb", "slavonski_brod", 195, "A3", [
		A(20, "pannonian_plain", "HR", 110, c=1, h=0, t=1.4, name="Zagreb-Ring"),
		A(70, "pannonian_plain", "HR", DEF, c=0, h=0, t=0.9, name="A3 Lonjsko polje – Kutina"),
		A(50, "pannonian_plain", "HR", DEF, c=0, h=1, t=0.8, name="A3 Novska – Okučani"),
		A(55, "pannonian_plain", "HR", DEF, c=0, h=0, t=0.9, name="A3 Nova Gradiška – Slavonski Brod"),
	], radars=[(60, 130), (120, 130)], fuel="normal"),
	stage("slavonski_brod_belgrad", "slavonski_brod", "belgrad", 205, "A3", [
		A(20, "pannonian_plain", "HR", DEF, c=0, h=0, t=1.0, name="A3 Slavonski Brod"),
		A(75, "pannonian_plain", "HR", DEF, c=0, h=0, t=0.9, name="A3 Slawonien – Županja"),
		A(70, "pannonian_plain", "RS", DEF, c=0, h=0, t=0.9, name="A3 Syrmien – Šid"),
		A(20, "pannonian_plain", "RS", 120, c=1, h=0, t=1.3, name="A3 Surčin"),
		A(20, "pannonian_plain", "RS", 100, c=1, h=0, t=1.5, name="Belgrad"),
	], radars=[(60, 130), (110, 130)], fuel="normal"),
	stage("belgrad_nis", "belgrad", "nis", 240, "A1", [
		A(20, "pannonian_plain", "RS", 100, c=1, h=0, t=1.5, name="Belgrad"),
		A(60, "pannonian_plain", "RS", DEF, c=0, h=1, t=1.0, name="A1 Große Morava"),
		A(70, "balkan_hills", "RS", DEF, c=1, h=1, t=0.9, name="A1 Jagodina – Ćuprija"),
		A(70, "balkan_hills", "RS", DEF, c=1, h=2, t=0.9, name="A1 Paraćin – Aleksinac"),
		A(20, "balkan_hills", "RS", 100, c=1, h=1, t=1.3, name="Niš"),
	], radars=[(60, 130), (130, 130)], fuel="normal"),
	stage("nis_sofia", "nis", "sofia", 155, "A4 · I-8 · A6", [
		A(20, "balkan_hills", "RS", 100, c=1, h=1, t=1.3, name="Niš"),
		A(30, "balkan_hills", "RS", DEF, c=3, h=3, t=0.8, name="A4 Sićevo-Schlucht"),
		A(50, "balkan_hills", "RS", DEF, c=2, h=2, t=0.8, name="A4 Pirot – Dimitrovgrad"),
		L(30, "balkan_hills", "BG", DEF, c=2, h=2, t=0.9, name="I-8 Kalotina – Dragoman"),
		A(25, "balkan_hills", "BG", DEF, c=1, h=1, t=1.3, name="A6 Dragoman – Sofia"),
	], radars=[(55, 130)], fuel="normal"),
	stage("belgrad_szeged", "belgrad", "szeged", 230, "A1 · M5", [
		A(20, "pannonian_plain", "RS", 100, c=1, h=0, t=1.5, name="Belgrad"),
		A(70, "pannonian_plain", "RS", DEF, c=0, h=0, t=1.0, name="A1 Syrmien – Novi Sad"),
		A(100, "pannonian_plain", "RS", DEF, c=0, h=0, t=0.9, name="A1 Batschka – Subotica"),
		A(25, "pannonian_plain", "RS", DEF, c=0, h=0, t=1.0, name="A1 Subotica – Horgoš"),
		A(15, "pannonian_plain", "HU", DEF, c=0, h=0, t=1.2, name="M5 Röszke – Szeged"),
	], radars=[(60, 130), (130, 130)], fuel="normal"),
	stage("szeged_budapest", "szeged", "budapest", 170, "M5", [
		A(20, "pannonian_plain", "HU", DEF, c=0, h=0, t=1.1, name="M5 Szeged"),
		A(65, "pannonian_plain", "HU", DEF, c=0, h=0, t=0.9, name="M5 Puszta – Kiskunfélegyháza"),
		A(50, "pannonian_plain", "HU", DEF, c=0, h=0, t=1.1, name="M5 Kecskemét"),
		A(35, "pannonian_plain", "HU", 110, c=1, h=0, t=1.5, name="M5/M0 Budapest"),
	], radars=[(60, 130), (100, 130)], fuel="normal"),
	stage("budapest_wien", "budapest", "wien", 245, "M1 · A4", [
		A(20, "pannonian_plain", "HU", 110, c=1, h=0, t=1.5, name="M1 Budapest"),
		A(55, "forest_hills", "HU", DEF, c=1, h=2, t=1.1, name="M1 Gerecse – Tatabánya"),
		A(50, "pannonian_plain", "HU", DEF, c=0, h=0, t=1.0, name="M1 Győr"),
		A(45, "pannonian_plain", "HU", DEF, c=0, h=0, t=1.0, name="M1 Mosonmagyaróvár – Hegyeshalom"),
		A(55, "pannonian_plain", "AT", DEF, c=0, h=0, t=1.2, name="A4 Nickelsdorf – Parndorf"),
		A(20, "pannonian_plain", "AT", 100, c=1, h=0, t=1.5, name="A4 Schwechat – Wien"),
	], radars=[(60, 130), (140, 130), (180, 130)], fuel="normal"),
	stage("wien_prag", "wien", "prag", 335, "A5 · I/52 · D52 · D1", [
		A(20, "pannonian_plain", "AT", 100, c=1, h=0, t=1.4, name="A22/A5 Wien"),
		A(45, "pannonian_plain", "AT", DEF, c=1, h=1, t=1.0, name="A5 Weinviertel"),
		L(30, "pannonian_plain", "CZ", DEF, c=2, h=1, t=1.1, name="I/52 Mikulov – Pohořelice"),
		A(30, "bohemian", "CZ", DEF, c=1, h=1, t=1.2, name="D52 Brünn"),
		A(15, "bohemian", "CZ", 100, c=1, h=1, t=1.4, name="D1 Brünn"),
		A(70, "bohemian", "CZ", DEF, c=1, h=2, t=1.2, name="D1 Böhmisch-Mährische Höhe – Jihlava"),
		A(25, "bohemian", "CZ", 80, c=1, h=2, t=1.2, name="D1 Baustelle Humpolec"),
		A(80, "bohemian", "CZ", DEF, c=1, h=1, t=1.2, name="D1 Benešov"),
		A(20, "bohemian", "CZ", 100, c=1, h=0, t=1.5, name="D1 Prag"),
	], radars=[(30, 130, "fwd"), (150, 130), (215, 80), (260, 130)], fuel="normal"),
	stage("prag_dresden", "prag", "dresden", 150, "D8 · A17", [
		A(20, "bohemian", "CZ", 100, c=1, h=0, t=1.4, name="D8 Prag"),
		A(40, "bohemian", "CZ", DEF, c=1, h=1, t=1.1, name="D8 Elbebene – Roudnice"),
		A(30, "bohemian", "CZ", DEF, c=2, h=3, t=1.0, name="D8 Böhmisches Mittelgebirge"),
		A(12, "forest_hills", "CZ", DEF, c=2, h=3, t=1.0, name="D8 Erzgebirge – Krásný Les"),
		A(28, "forest_hills", "DE", 120, c=2, h=2, t=1.0, name="A17 Osterzgebirge"),
		A(20, "forest_hills", "DE", 100, c=1, h=1, t=1.3, name="A17 Dresden"),
	], radars=[(60, 130), (110, 120, "rev")], tunnels=[(78, 0.6, "Tunel Radejčín"), (136, 1.1, "Tunnel Dölzschen")],
		fuel="normal"),
	stage("leipzig_berlin", "leipzig", "berlin", 190, "A9 · A10 · A115", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.4, name="A14/A9 Leipzig"),
		A(45, "north_plain", "DE", FREE, c=0, h=0, t=1.1, name="A9 Bitterfeld – Dessau"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.0, name="A9 Elbebrücke Vockerode"),
		A(60, "heath", "DE", FREE, c=0, h=1, t=1.0, name="A9 Fläming"),
		A(30, "north_plain", "DE", 120, c=1, h=0, t=1.3, name="A9/A10 Dreieck Potsdam"),
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.6, name="A115 AVUS Berlin"),
	], radars=[(66, 120), (145, 120, "rev")], fuel="normal"),
	stage("berlin_posen", "berlin", "posen", 270, "A12 · A2 (PL)", [
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.5, name="A113/A10 Berlin"),
		A(45, "heath", "DE", FREE, c=0, h=0, t=1.2, name="A12 Brandenburger Kiefernwald"),
		A(30, "heath", "DE", 120, c=1, h=1, t=1.3, name="A12 Frankfurt (Oder)"),
		A(80, "east_plain", "PL", DEF, c=0, h=0, t=1.0, name="A2 Lebuser Land"),
		A(75, "east_plain", "PL", DEF, c=0, h=0, t=1.0, name="A2 Nowy Tomyśl – Buk"),
		A(20, "east_plain", "PL", 120, c=1, h=0, t=1.4, name="S11 Posen"),
	], radars=[(70, 120), (150, 140), (190, 140)], fuel="normal"),
	stage("posen_warschau", "posen", "warschau", 305, "A2", [
		A(20, "east_plain", "PL", 120, c=1, h=0, t=1.4, name="Posen"),
		A(85, "east_plain", "PL", DEF, c=0, h=0, t=1.0, name="A2 Września – Konin"),
		A(90, "east_plain", "PL", DEF, c=0, h=0, t=1.0, name="A2 Koło – Stryków"),
		A(90, "east_plain", "PL", DEF, c=0, h=0, t=1.1, name="A2 Łowicz – Pruszków"),
		A(20, "east_plain", "PL", 100, c=1, h=0, t=1.6, name="Warschau"),
	], radars=[(70, 140), (150, 140), (230, 140)], fuel="normal"),
	stage("warschau_bialystok", "warschau", "bialystok", 200, "S8", [
		A(20, "east_plain", "PL", 100, c=1, h=0, t=1.5, name="S8 Warschau – Marki"),
		A(60, "east_plain", "PL", 120, c=0, h=0, t=1.0, name="S8 Wyszków"),
		A(60, "east_plain", "PL", 120, c=0, h=1, t=0.9, name="S8 Ostrów Mazowiecka – Zambrów"),
		A(40, "east_plain", "PL", 120, c=1, h=1, t=0.9, name="S8 Podlachien"),
		A(20, "east_plain", "PL", 100, c=1, h=0, t=1.3, name="Białystok"),
	], radars=[(60, 120), (110, 120)], fuel="normal"),
	stage("bialystok_kaunas", "bialystok", "kaunas", 230, "S8 · S61 · A5 (LT)", [
		A(20, "east_plain", "PL", 100, c=1, h=0, t=1.2, name="Białystok"),
		A(65, "east_plain", "PL", 120, c=1, h=1, t=0.9, name="S8 Knyszyner Heide – Augustów"),
		A(30, "baltic_forest", "PL", 120, c=1, h=1, t=0.9, name="S61 Augustower Urwald"),
		A(25, "baltic_forest", "PL", 120, c=1, h=1, t=0.9, name="S61 Suwałki – Budzisko"),
		L(35, "baltic_forest", "LT", DEF, c=1, h=1, t=0.9, name="A5 Kalvarija – Marijampolė"),
		A(55, "baltic_forest", "LT", DEF, c=1, h=1, t=1.0, name="A5 Marijampolė – Kaunas"),
	], radars=[(60, 120), (150, 90)], fuel="normal", doc="Via Baltica."),
	stage("kaunas_riga", "kaunas", "riga", 255, "A8 · A10 (LT) · A7 (LV)", [
		A(20, "baltic_forest", "LT", 110, c=1, h=1, t=1.3, name="Kaunas"),
		A(90, "baltic_forest", "LT", 110, c=0, h=0, t=0.9, name="A8 Via Baltica – Panevėžys"),
		L(65, "baltic_forest", "LT", DEF, c=1, h=0, t=0.8, name="A10 Pasvalys – Saločiai"),
		L(60, "baltic_forest", "LV", DEF, c=1, h=0, t=0.9, name="A7 Bauska – Iecava"),
		A(20, "baltic_forest", "LV", DEF, c=1, h=0, t=1.4, name="A7 Ķekava – Riga"),
	], radars=[(60, 110), (120, 90), (190, 90)], fuel="normal", doc="Via Baltica, im Baltikum meist Landstraße."),
	stage("rostock_kiel", "rostock", "kiel", 210, "A20 · A21", [
		A(20, "north_plain", "DE", 120, c=1, h=0, t=1.2, name="A20 Rostock"),
		A(45, "north_plain", "DE", FREE, c=1, h=1, t=0.8, name="A20 Mecklenburg"),
		A(15, "coast", "DE", 120, c=1, h=1, t=0.9, name="A20 Wismar"),
		A(45, "north_plain", "DE", FREE, c=1, h=1, t=0.8, name="A20 Grevesmühlen – Lübeck"),
		A(15, "north_plain", "DE", 120, c=1, h=0, t=1.2, name="A20/A1 Lübeck"),
		A(25, "forest_hills", "DE", FREE, c=1, h=1, t=1.0, name="A20 Bad Segeberg"),
		A(25, "north_plain", "DE", FREE, c=1, h=1, t=1.0, name="A21 Bornhöved"),
		A(20, "north_plain", "DE", 100, c=1, h=0, t=1.3, name="A21 Kiel"),
	], radars=[(66, 120), (128, 120)], fuel="normal", doc="Schlussetappe des Königsrennens."),
]

FERRIES = [
	{"id": "riga_rostock", "from": "riga", "to": "rostock", "name": "Fähre Riga – Rostock",
	 "fixed_time_s": 240, "world_hours": 24},
]

RACES = [
	{
		"id": "kiel_nuernberg", "name": "Kiel – Nürnberg", "start": "kiel", "finish": "nuernberg", "waypoints": [],
		"avoid_stages": ["hannover_bremen", "hannover_dortmund", "kassel_dortmund"],
		"description": "Das erste Rennen. Kiel – Hamburg ist die Tutorial-Etappe. Ab Hamburg geht es entweder "
			"über Hannover und Kassel (kürzer, Kasseler Berge und Rhön, mehr Tempolimits und Radarfallen, weniger "
			"Tankstellen) oder über Frankfurt (länger, mehr Verkehr, dafür mehr freie Autobahn, weniger Radar, mehr "
			"Tankstellen). Beide Wege treffen sich in Würzburg.",
	},
	{
		"id": "dresden_dortmund", "name": "Dresden – Dortmund", "start": "dresden", "finish": "dortmund", "waypoints": [],
		"description": "Von der Elbe ins Ruhrgebiet. Ab Leipzig über Erfurt und Kassel (Thüringer Hügel, "
			"Jagdbergtunnel, Landstraßenlücke der A44, mehr Radar) oder über Magdeburg und Hannover (flach, "
			"viel LKW-Verkehr, mehr Tankstellen).",
	},
	{
		"id": "muenchen_bremen", "name": "München – Bremen", "start": "muenchen", "finish": "bremen", "waypoints": [],
		"description": "Von Süden nach Norden. Über Nürnberg nach Würzburg, dann über Kassel und Hannover (kürzer, "
			"hügelig, mehr Radar) oder über Frankfurt und Dortmund (länger, mehr Verkehr, mehr freie Autobahn).",
	},
	{
		"id": "koenigsrennen", "name": "Königsrennen", "start": "kiel", "finish": "kiel",
		"waypoints": ["hamburg", "bremen", "amsterdam", "luettich", "paris", "madrid", "bern", "mailand", "sofia",
			"budapest", "wien", "prag", "leipzig", "berlin", "warschau", "riga", "rostock"],
		"description": "Die große Europa-Tour mit 17 Pflichtstationen: Kiel – Hamburg – Bremen – Amsterdam – Lüttich – "
			"Paris – Madrid – Bern – Mailand – Sofia – Budapest – Wien – Prag – Leipzig – Berlin – Warschau – Riga, "
			"Fähre nach Rostock und zurück nach Kiel. Bei Saragossa Wahl zwischen der Küste über Barcelona und den "
			"Pyrenäen über den Somport-Tunnel.",
	},
]
