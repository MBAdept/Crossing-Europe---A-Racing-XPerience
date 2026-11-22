p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-6/tools/blender/ce3d/catalog3d.py"
s = open(p).read()
rep = [
('''        roughness=0.88, view="roadside", ao=AO_CITY, lod1=True, single_cutout=True, lod1_opaque=True,
        rail_module={"fs_rail": 1.0},''',
 '''        roughness=0.88, view="roadside", ao=AO_CITY, lod1=True, single_cutout=True,
        rail_module={"fs_rail": 1.0},'''),
('''        # AS5aR2 (KRITIK-5a2 K3): leaf cards on the plane tree's blobs in the cut-out atlas, the crown a core inside
        leaf_cards={"fs_plane_c": dict(n=230, half=0.5, core=0.9, down=-0.75,
                                       atlas=dict(base=("#5d7f2e", "#86a84a"), gain=0.88))},''',
 '''        # AS5aR2 (KRITIK-5a2 K3): leaf cards on the plane tree's blobs in the cut-out atlas, the crown a core inside;
        # lod1 keeps the cut-out class and gets fewer, larger cards (no jump of the crown at the switch)
        leaf_cards={"fs_plane_c": dict(n=230, half=0.5, core=0.9, down=-0.75, n1=80, half1=0.75,
                                       atlas=dict(base=("#5d7f2e", "#86a84a"), gain=0.88))},'''),
('''        # AS5aR2 (KRITIK-5a2 K3): leaf cards on the garden tree - the cut-out class for lod0 (single_cutout), lod1
        # opaque with the crown's core
        single_cutout=True, lod1_opaque=True,
        leaf_cards={"fm_tree_c": dict(n=170, half=0.5, core=0.9, down=-0.75,''',
 '''        # AS5aR2 (KRITIK-5a2 K3): leaf cards on the garden tree - the cut-out class (single_cutout) in both levels,
        # lod1 with fewer, larger cards
        single_cutout=True,
        leaf_cards={"fm_tree_c": dict(n=170, half=0.5, core=0.9, down=-0.75, n1=60, half1=0.75,'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)
open(p, "w").write(s)
print("ok")
