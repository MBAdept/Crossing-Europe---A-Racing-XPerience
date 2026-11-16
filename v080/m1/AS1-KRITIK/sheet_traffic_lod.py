import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image
B = "t"
ims = []
tris = {}
for car in ("sedan", "hatch", "wagon"):
    m = K.model("traffic/" + car)
    for l in m["lods"]:
        tris[(car, l["name"])] = l["tris"]
for car in ("sedan", "hatch", "wagon"):
    for view in ("rear34", "side"):
        for lod in ("lod0", "lod1", "lod2"):
            n = f"{car}_{lod}_{view}" if lod != "lod0" else f"{car}_lod0_{view}"
            ims.append(K.caption(K.tile(n, B).resize((640, 400), Image.LANCZOS), f"{car} {lod} {view} · {tris[(car, lod)]} Dreiecke", 13))
        for lod in ("lod0", "lod1", "lod2"):
            ims.append(K.caption(K.tile(f"{car}_wire{lod}_{view}", B).resize((640, 400), Image.LANCZOS), f"{car} {lod} Drahtgitter", 13))
sheet = K.grid(ims, 6)
sheet = K.title(sheet, "Verkehrsautos: Stufen lod0 | lod1 | lod2 vergrößert und als Drahtgitter (Ton + Kanten)",
                sub="lod1 wird ab 40 m, lod2 ab 120 m gezeigt („Details: Mittel“); hier aus der Nähe, um die Form zu beurteilen")
print(K.save_jpg(sheet, K.DELIVER + "/09_verkehr_stufen_nah.jpg", q=86))
