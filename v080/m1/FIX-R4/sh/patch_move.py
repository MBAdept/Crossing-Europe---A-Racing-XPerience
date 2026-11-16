import sys
vp, fp = sys.argv[1], sys.argv[2]
v = open(vp, encoding="utf-8").read()
f = open(fp, encoding="utf-8").read()
start = v.index("\n\n## FIX-R4 (QA-R4 B1): the road's height profile from road position z_from")
end = v.index("\tbuf[o + 10] = 0.0\n", start) + len("\tbuf[o + 10] = 0.0\n")
block = v[start:end]
v = v[:start] + "\n" + v[end:]
v = v.replace("\tput_profile(_streaks, o, prof)\n", "\tFlares.put_profile(_streaks, o, prof)\n")
v = v.replace("\t\t\t\troad_profile(_path, car.z, _cam_z,", "\t\t\t\tFlares.road_profile(_path, car.z, _cam_z,")
assert v.count("Flares.") == 2
anchor = "const PLAYER_ID := -999999"
assert v.count(anchor) == 1
v = v.replace(anchor, "## FIX-R4: the flare layer's streak layout (road_profile(), put_profile() – same package, R4)\nconst Flares := preload(\"res://scripts/race3d/layers/flares.gd\")\n" + anchor)
f = f.replace("Vehicles.road_profile(", "road_profile(").replace("Vehicles.put_profile(", "put_profile(")
anchor2 = "\n\n## FIX-R4: the mesh of a streak"
assert f.count(anchor2) == 1
f = f.replace(anchor2, block.rstrip("\n").replace("flare.gdshader", "flare.gdshader", 1) + "\n" + anchor2)
open(vp, "w", encoding="utf-8").write(v)
open(fp, "w", encoding="utf-8").write(f)
print("moved")
