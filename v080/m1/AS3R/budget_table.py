"""AS3R scratch: budget table (contract 4.6.9) of the AS3 models from the manifest and the files (markdown)."""
import json
import os

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-4"
MD = os.path.join(WT, "assets/models")
man = json.load(open(os.path.join(MD, "manifest.json")))
ids = sorted(m for m in man["models"] if m.split("/")[1].startswith(("tree_", "bush_", "cover_", "heather", "rock_", "cliff")))
BUD = {"tree": "2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1", "plant": "400 / 120, 1", "rock": "1 500 / auto, 1",
       "cliff": "6 000 / auto, 1"}
print("| Modell | Art | Dreiecke lod0 / lod1 | Kuppeln bzw. Karten lod0 / lod1 | Aufrufe lod0 / lod1 / Fernbild | Schatten | Netze B | Texturen B (Quelle) | Budget |")
print("|---|---|---|---|---|---|---|---|---|")
tot_mesh = tot_tex = 0
for mid in ids:
    m = man["models"][mid]
    lods = {l["name"]: l for l in m["lods"]}
    tris = " / ".join(str(lods[n]["tris"]) for n in ("lod0", "lod1") if n in lods)
    calls = " / ".join(str(sum(len(p["classes"]) for p in lods[n]["parts"])) for n in ("lod0", "lod1") if n in lods)
    if m.get("impostor"):
        calls += " / 1"
    cards = m.get("cards", {})
    cs = " / ".join(str(cards.get(n, "–")) for n in ("lod0", "lod1")) if cards else "–"
    folder = os.path.join(MD, mid)
    mesh_b = sum(os.path.getsize(os.path.join(folder, f)) for f in os.listdir(folder) if f.endswith(".res"))
    tex_b = sum(os.path.getsize(os.path.join(folder, f)) for f in os.listdir(folder) if f.endswith((".png", ".webp")))
    tot_mesh += mesh_b
    tot_tex += tex_b
    cat = "cliff" if "cliff" in mid else m["kind"]
    sh = str(m["shadow"]["tris"]) if m.get("shadow") else "–"
    print("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (mid.split("/")[1], m["kind"], tris, cs, calls, sh,
                                                       format(mesh_b, ",").replace(",", " "),
                                                       format(tex_b, ",").replace(",", " "), BUD.get(cat, "")))
print()
print("Summe der %d Modelle: Netze %.2f MB, Texturquellen %.2f MB" % (len(ids), tot_mesh / 1e6, tot_tex / 1e6))
