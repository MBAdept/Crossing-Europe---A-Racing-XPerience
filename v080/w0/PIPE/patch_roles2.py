from patchlib import patch

patch("tools/blender/ce3d/roles.py", [
    ('''            for idx in _clusters(cen, merge_m):
                a = float(area[idx].sum())
                if a < min_area:
                    continue''', '''            groups = []
            for idx in _clusters(cen, merge_m):
                x = cen[idx][:, 0]
                if split_x > 0.0 and x.min() < -split_x and x.max() > split_x:
                    # a lamp across the whole car (light bar): one anchor per side, and the middle if it is big
                    groups += [idx[x < -split_x], idx[x > split_x]]
                    mid = idx[np.abs(x) <= split_x]
                    if mid.size and float(area[mid].sum()) >= 0.5 * float(area[idx].sum()):
                        groups.append(mid)
                else:
                    groups.append(idx)
            for idx in groups:
                a = float(area[idx].sum())
                if a < min_area:
                    continue'''),
    ('''    def lights(self, min_area=2e-4, merge_m=0.35, origin=None):
        """Manifest "lights": one anchor per lamp cluster [{role, pos (model space), size, color}].
        Triangles of one role are clustered by distance (merge_m); pos = area-weighted centre,
        size = diameter of the circle with the cluster's area."""''',
     '''    def lights(self, min_area=2e-4, merge_m=0.35, origin=None, split_x=0.3):
        """Manifest "lights": one anchor per lamp cluster [{role, pos (model space), size, color}].
        Triangles of one role are clustered by distance (merge_m); pos = area-weighted centre,
        size = diameter of the circle with the cluster's area. A cluster that reaches over both sides of
        the vehicle (|x| > split_x) is split into a left and a right anchor; split_x = 0 keeps it whole."""'''),
])
