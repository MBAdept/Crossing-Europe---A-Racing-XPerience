import json, sys
jobs = []
def J(**kw):
    jobs.append(kw)

# ---------------------------------------------------------------- A/B from the sprite cameras
K = 3
# traffic sedan: ortho, elevation 9, pivot = rear end on the ground
for lod in ("lod0", "lod1", "lod2"):
    for yaw, tag in ((0.0, "c"), (24.0, "p24"), (-24.0, "m24")):
        J(name="ab_sedan_%s_%s" % (lod, tag), set="traffic/sedan_red", lod=lod, mode="ortho", size=[284 * K, 108 * K],
          width_m=5.4615, anchor=[0.5, 0.9663], elevation=9.0, yaw=yaw, pivot=[0, 0, 2.35])
for state, la, lb in (("tail", [1, 0, 0, 0], [1, 0, 0, 0]), ("brake", [1, 1, 0, 0], [1, 0, 0, 0]), ("off", [0, 0, 0, 0], [0, 0, 0, 0]),
                      ("indl", [1, 0, 1, 0], [1, 0, 0, 0]), ("indr", [1, 0, 0, 1], [1, 0, 0, 0]), ("rev", [1, 0, 0, 0], [1, 1, 0, 0])):
    for lod in ("lod0", "lod1", "lod2"):
        J(name="ab_sedan_%s_night_%s" % (lod, state), set="traffic/sedan_red", lod=lod, mode="ortho", size=[284 * K, 108 * K], night=True,
          width_m=5.4615, anchor=[0.5, 0.9663], elevation=9.0, yaw=0.0, pivot=[0, 0, 2.35], lamp_a=la, lamp_b=lb)
# props
J(name="ab_tree_lod0", set="props/tree_oak", lod="lod0", mode="ortho", size=[352 * K, 352 * K], width_m=13.7299, anchor=[0.5, 0.9785], elevation=6.0)
J(name="ab_tree_lod1", set="props/tree_oak", lod="lod1", mode="ortho", size=[352 * K, 352 * K], width_m=13.7299, anchor=[0.5, 0.9785], elevation=6.0)
J(name="ab_tree_impostor", set="props/tree_oak", impostor=True, mode="ortho", size=[352 * K, 352 * K], width_m=13.7299, anchor=[0.5, 0.9785], elevation=6.0)
for night in (False, True):
    n = "_night" if night else ""
    J(name="ab_farmhouse" + n, set="props/farmhouse", lod="lod0", mode="ortho", size=[512 * K, 300 * K], width_m=19.3518, anchor=[0.6787, 0.9489],
      elevation=6.0, yaw=24.0, night=night)
    J(name="ab_farmhouse_yawneg" + n, set="props/farmhouse", lod="lod0", mode="ortho", size=[512 * K, 300 * K], width_m=19.3518, anchor=[0.6787, 0.9489],
      elevation=6.0, yaw=-24.0, night=night)
    J(name="ab_streetlight" + n, set="props/streetlight", lod="lod0", mode="ortho", size=[192 * K, 300 * K], width_m=6.8426, anchor=[0.7879, 0.9682],
      elevation=6.0, night=night)
    J(name="ab_michel" + n, set="landmarks/michel", lod="lod0", mode="ortho", size=[380 * 2, 644 * 2], width_m=81.1783, anchor=[0.6347, 0.9891],
      elevation=3.0, yaw=22.0, night=night)
    J(name="ab_michel_yawneg" + n, set="landmarks/michel", lod="lod0", mode="ortho", size=[380 * 2, 644 * 2], width_m=81.1783, anchor=[0.6347, 0.9891],
      elevation=3.0, yaw=-22.0, night=night)
# player car from the game camera (1280x720 at supersample 1.65 like the sprite)
SS = 1.65
for lod in ("lod0", "show"):
    J(name="ab_limo_game_" + lod, set="player/limousine", lod=lod, mode="game", size=[int(1280 * SS), int(720 * SS)], cam_dist=9.0, cam_h=3.4)
    J(name="ab_limo_game_%s_x2" % lod, set="player/limousine", lod=lod, mode="game", size=[int(1280 * SS * 2), int(720 * SS * 2)], cam_dist=9.0, cam_h=3.4)
for state, la, lb in (("tail", [1, 0, 0, 0], [1, 0, 0, 0]), ("brake", [1, 1, 0, 0], [1, 0, 0, 0]), ("indl", [1, 0, 1, 0], [1, 0, 0, 0]), ("rev", [1, 0, 0, 0], [1, 1, 0, 0])):
    J(name="ab_limo_game_night_" + state, set="player/limousine", lod="lod0", mode="game", size=[int(1280 * SS), int(720 * SS)], cam_dist=9.0, cam_h=3.4,
      night=True, lamp_a=la, lamp_b=lb)
J(name="ab_limo_game_yaw12", set="player/limousine", lod="lod0", mode="game", size=[int(1280 * SS), int(720 * SS)], cam_dist=9.0, cam_h=3.4, yaw=12.0)

# ---------------------------------------------------------------- the levels at their swap distances (game camera, 1280x720)
for dist, lods in ((20, ("lod0",)), (40, ("lod0", "lod1")), (80, ("lod1",)), (120, ("lod1", "lod2")), (250, ("lod2",))):
    for lod in lods:
        J(name="dist_sedan_%03d_%s" % (dist, lod), set="traffic/sedan_silver", lod=lod, mode="game", size=[1280, 720], cam_dist=float(dist), cam_h=3.4, cam_x=-3.75)
        J(name="dist_sedan_%03d_%s_night" % (dist, lod), set="traffic/sedan_silver", lod=lod, mode="game", size=[1280, 720], cam_dist=float(dist), cam_h=3.4, cam_x=-3.75,
          night=True, lamp_a=[1, 1, 0, 1], lamp_b=[1, 0, 0, 0])
for dist, what in ((30, "lod0"), (60, "lod0"), (60, "lod1"), (200, "lod1"), (200, "impostor"), (400, "impostor")):
    kw = dict(impostor=True) if what == "impostor" else dict(lod=what)
    J(name="dist_tree_%03d_%s" % (dist, what), set="props/tree_oak", mode="game", size=[1280, 720], cam_dist=float(dist), cam_h=3.4, cam_x=-14.0, **kw)

# ---------------------------------------------------------------- close-ups (free camera)
def F(name, set_id, lod, pos, target, fov=30.0, size=(960, 640), **kw):
    J(name=name, set=set_id, lod=lod, mode="free", size=list(size), cam_pos=list(pos), cam_target=list(target), fov=fov, **kw)
for lod in ("lod0", "lod1", "lod2"):
    F("free_sedan_%s_rear34" % lod, "traffic/sedan_silver", lod, (3.4, 1.5, 6.0), (0, 0.7, 0.3))
    F("free_sedan_%s_front34" % lod, "traffic/sedan_silver", lod, (-3.4, 1.5, -6.0), (0, 0.7, -0.3))
    F("free_sedan_%s_side" % lod, "traffic/sedan_silver", lod, (7.5, 1.1, 0.0), (0, 0.7, 0.0), fov=26.0)
F("free_sedan_lod0_rear_close", "traffic/sedan_silver", "lod0", (1.3, 1.05, 4.4), (0.35, 0.8, 2.3), fov=28.0)
F("free_sedan_lod0_rearcorner_close", "traffic/sedan_silver", "lod0", (2.6, 1.0, 3.6), (0.85, 0.8, 2.1), fov=18.0)
F("free_sedan_lod0_front_close", "traffic/sedan_silver", "lod0", (-1.3, 0.95, -4.4), (-0.35, 0.7, -2.3), fov=28.0)
F("free_sedan_lod0_wheel", "traffic/sedan_silver", "lod0", (2.6, 0.55, -2.2), (0.9, 0.32, -1.415), fov=18.0)
F("free_sedan_lod0_top", "traffic/sedan_silver", "lod0", (0.01, 9.0, 0.6), (0, 0.5, 0.0), fov=34.0)
F("free_sedan_lod0_black", "traffic/sedan_black", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3))
F("free_sedan_lod0_fade50", "traffic/sedan_red", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), fade=0.5)
F("free_sedan_lod0_tunnel", "traffic/sedan_red", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), sun_mask=0.0)
F("free_sedan_lod0_night_rear", "traffic/sedan_silver", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), night=True, lamp_a=[1, 1, 1, 1], lamp_b=[1, 1, 0, 0])
F("free_sedan_lod0_night_front", "traffic/sedan_silver", "lod0", (-3.4, 1.5, -6.0), (0, 0.7, -0.3), night=True, lamp_a=[1, 0, 1, 1], lamp_b=[1, 0, 0, 0])
F("free_sedan_caster", "traffic/sedan_silver", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), caster=True)
for lod in ("lod0", "show"):
    F("free_limo_%s_rear34" % lod, "player/limousine", lod, (3.4, 1.5, 6.0), (0, 0.7, 0.3))
    F("free_limo_%s_front34" % lod, "player/limousine", lod, (-3.4, 1.5, -6.0), (0, 0.7, -0.3))
    F("free_limo_%s_side" % lod, "player/limousine", lod, (7.5, 1.1, 0.0), (0, 0.7, 0.0), fov=26.0)
    F("free_limo_%s_rear_close" % lod, "player/limousine", lod, (1.3, 1.1, 4.6), (0.35, 0.85, 2.4), fov=28.0)
    F("free_limo_%s_rearcorner_close" % lod, "player/limousine", lod, (2.7, 1.05, 3.7), (0.85, 0.85, 2.2), fov=18.0)
    F("free_limo_%s_front_close" % lod, "player/limousine", lod, (-1.3, 0.95, -4.5), (-0.35, 0.7, -2.3), fov=28.0)
    F("free_limo_%s_wheel" % lod, "player/limousine", lod, (2.7, 0.6, -2.3), (0.93, 0.335, -1.445), fov=18.0)
F("free_limo_lod0_top", "player/limousine", "lod0", (0.01, 9.0, 0.6), (0, 0.5, 0.0), fov=34.0)
F("free_limo_lod0_under", "player/limousine", "lod0", (2.5, 0.25, 5.0), (0, 0.3, 0.0), fov=30.0)
F("free_limo_lod0_inside", "player/limousine", "lod0", (2.2, 1.25, -0.4), (0, 1.0, 0.0), fov=40.0)
F("free_limo_caster", "player/limousine", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), caster=True)
F("free_limo_caster_side", "player/limousine", "lod0", (7.5, 1.1, 0.0), (0, 0.7, 0.0), fov=26.0, caster=True)
F("free_limo_lod0_night_rear", "player/limousine", "lod0", (3.4, 1.5, 6.0), (0, 0.7, 0.3), night=True, lamp_a=[1, 1, 1, 1], lamp_b=[1, 1, 0, 0])
F("free_limo_lod0_night_front", "player/limousine", "lod0", (-3.4, 1.5, -6.0), (0, 0.7, -0.3), night=True, lamp_a=[1, 0, 1, 1], lamp_b=[1, 0, 0, 0])
# props from the road: the model stands with its origin on the roadside (x = 0); the road is at -x
F("free_farm_road_30", "props/farmhouse", "lod0", (-12.0, 3.4, 30.0), (0, 3.0, -6.0), fov=40.0)
F("free_farm_road_12", "props/farmhouse", "lod0", (-9.0, 1.6, 9.0), (0, 2.6, -5.0), fov=50.0)
F("free_farm_wall_close", "props/farmhouse", "lod0", (-11.0, 1.7, -6.0), (-5.5, 1.7, -8.0), fov=40.0)
F("free_farm_gable_close", "props/farmhouse", "lod0", (0.0, 1.7, 9.0), (0.0, 3.0, 0.0), fov=45.0)
F("free_farm_back", "props/farmhouse", "lod0", (16.0, 5.0, -34.0), (0, 3.0, -9.0), fov=40.0)
F("free_farm_far_side", "props/farmhouse", "lod0", (24.0, 4.0, -8.0), (0, 3.0, -8.0), fov=40.0)
F("free_farm_top", "props/farmhouse", "lod0", (0.01, 45.0, -8.0), (0, 0.0, -8.5), fov=30.0)
F("free_farm_night", "props/farmhouse", "lod0", (-12.0, 3.4, 30.0), (0, 3.0, -6.0), fov=40.0, night=True)
F("free_michel_150", "landmarks/michel", "lod0", (-60.0, 3.4, 150.0), (-5, 50.0, -20.0), fov=50.0)
F("free_michel_60", "landmarks/michel", "lod0", (-50.0, 3.4, 60.0), (-10, 30.0, -20.0), fov=60.0)
F("free_michel_tower_close", "landmarks/michel", "lod0", (-60.0, 20.0, 40.0), (-34, 60.0, -22.0), fov=50.0)
F("free_michel_back", "landmarks/michel", "lod0", (60.0, 30.0, -160.0), (-5, 50.0, -20.0), fov=50.0)
F("free_michel_far_side", "landmarks/michel", "lod0", (150.0, 30.0, -20.0), (-5, 50.0, -20.0), fov=50.0)
F("free_michel_night", "landmarks/michel", "lod0", (-60.0, 3.4, 150.0), (-5, 50.0, -20.0), fov=50.0, night=True)
F("free_tree_lod0_15", "props/tree_oak", "lod0", (-6.0, 2.0, 15.0), (0, 7.0, 0.0), fov=60.0)
F("free_tree_lod0_under", "props/tree_oak", "lod0", (-3.0, 1.5, 4.0), (0, 8.0, 0.0), fov=70.0)
F("free_tree_lod0_40", "props/tree_oak", "lod0", (-10.0, 3.4, 40.0), (0, 6.5, 0.0), fov=30.0)
F("free_tree_lod1_40", "props/tree_oak", "lod1", (-10.0, 3.4, 40.0), (0, 6.5, 0.0), fov=30.0)
F("free_tree_lod0_backlight", "props/tree_oak", "lod0", (-10.0, 3.4, 40.0), (0, 6.5, 0.0), fov=30.0, sun=[0.3, 0.5, -1.0])
F("free_tree_caster", "props/tree_oak", "lod0", (-10.0, 3.4, 40.0), (0, 6.5, 0.0), fov=30.0, caster=True)
F("free_tree_night", "props/tree_oak", "lod0", (-10.0, 3.4, 40.0), (0, 6.5, 0.0), fov=30.0, night=True)
F("free_light_12", "props/streetlight", "lod0", (-6.0, 1.6, 12.0), (-1.0, 5.5, 0.0), fov=55.0)
F("free_light_head", "props/streetlight", "lod0", (-4.5, 7.0, 4.0), (-1.9, 9.2, 0.0), fov=30.0)
F("free_light_night", "props/streetlight", "lod0", (-8.0, 1.6, 16.0), (-1.0, 5.0, 0.0), fov=55.0, night=True)
json.dump(jobs, open(sys.argv[1], "w"), indent=0)
print(len(jobs), "jobs")
